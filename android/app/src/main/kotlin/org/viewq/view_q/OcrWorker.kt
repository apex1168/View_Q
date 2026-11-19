package org.viewq.view_q

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import androidx.work.*
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class OcrWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try { OcrQueue.drain(applicationContext) { isStopped }; Result.success() }
        catch (_: Exception) { Result.retry() }
}

object OcrQueue {
    private val executor = Executors.newSingleThreadExecutor()
    private val lock = Any()
    @Volatile var active = false
    fun start(context: Context) {
        val app = context.applicationContext
        executor.execute { try { drain(app) { !active } } catch (_: Exception) { /* durable queue remains */ } }
        WorkManager.getInstance(app).enqueueUniqueWork("viewq-ocr", ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<OcrWorker>().build())
    }
    fun drain(context: Context, stop: () -> Boolean) = synchronized(lock) {
        LibraryStore(context).use { store ->
            store.cleanupDeleted()
            while (!stop()) {
                val job = store.pending() ?: break
                try {
                    val root = File(context.noBackupFilesDir,"ocr-accurate-v1")
                    val data = File(root,"tessdata/eng.traineddata")
                    if (!data.exists()) {
                        data.parentFile!!.mkdirs()
                        val temp = File(data.parentFile,"eng.part")
                        context.assets.open("flutter_assets/assets/tessdata/eng.traineddata").use { input ->
                            FileOutputStream(temp).use { output -> input.copyTo(output); output.fd.sync() }
                        }
                        check(temp.renameTo(data))
                    }
                    val api = TessBaseAPI()
                    val text = try {
                        check(api.init(root.path,"eng",TessBaseAPI.OEM_LSTM_ONLY))
                        api.setVariable("user_defined_dpi", "300")
                        recognizeImage(job.second, api) { stop() || !store.owns(job) }
                    } finally { api.recycle() }
                    store.finish(job.first,text,false,job.generation)
                } catch (_: InterruptedException) { if (stop()) return@synchronized }
                catch (_: Exception) { store.finish(job.first,null,true,job.generation) }
                catch (_: OutOfMemoryError) { store.finish(job.first,null,true,job.generation) }
            }
        }
    }

    private data class Reading(val text: String, val confidence: Int) {
        val score: Double get() = text.count { it.isLetterOrDigit() } *
            (confidence.coerceIn(0, 100) + 30) / 100.0
    }

    private fun recognizeTile(api: TessBaseAPI, bitmap: Bitmap): String {
        // Upscale narrow phone captures to help the recognizer separate small glyphs.
        val scale = minOf(2.0, 1800.0 / bitmap.width, kotlin.math.sqrt(3_000_000.0 / (bitmap.width.toLong() * bitmap.height)))
        val input = if (scale > 1.12) Bitmap.createScaledBitmap(bitmap,
            (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true) else bitmap
        fun read(mode: Int, image: Bitmap = input): Reading {
            api.pageSegMode = mode
            api.setImage(image)
            return Reading(api.getUTF8Text()?.trim().orEmpty(), api.meanConfidence())
        }
        return try {
            var best = read(TessBaseAPI.PageSegMode.PSM_AUTO)
            if (best.confidence < 82 || best.text.count { it.isLetterOrDigit() } < 24) {
                val sparse = read(TessBaseAPI.PageSegMode.PSM_SPARSE_TEXT)
                if (sparse.score > best.score) best = sparse
            }
            if (best.confidence < 70 || best.text.count { it.isLetterOrDigit() } < 12) {
                val enhanced = contrastForOcr(input)
                try {
                    val alternate = read(TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK, enhanced)
                    if (alternate.score > best.score) best = alternate
                } finally {
                    api.clear()
                    enhanced.recycle()
                }
            }
            best.text
        } finally {
            api.clear()
            if (input !== bitmap) input.recycle()
        }
    }

    private fun contrastForOcr(input: Bitmap): Bitmap {
        var dark = 0
        var samples = 0
        for (y in 0 until input.height step maxOf(1, input.height / 24)) {
            for (x in 0 until input.width step maxOf(1, input.width / 24)) {
                val pixel = input.getPixel(x, y)
                val gray = (((pixel shr 16) and 255) * 3 + ((pixel shr 8) and 255) * 6 + (pixel and 255)) / 10
                if (gray < 96) dark++
                samples++
            }
        }
        val invert = dark * 3 > samples * 2
        val gain = if (invert) -1.28f else 1.28f
        val offset = if (invert) 290f else -35f
        val r = .299f * gain; val g = .587f * gain; val b = .114f * gain
        val normalized = Bitmap.createBitmap(input.width, input.height, Bitmap.Config.ARGB_8888)
        val matrix = ColorMatrix(floatArrayOf(r,g,b,0f,offset, r,g,b,0f,offset, r,g,b,0f,offset, 0f,0f,0f,1f,0f))
        Canvas(normalized).drawBitmap(input, 0f, 0f, Paint().apply { colorFilter = ColorMatrixColorFilter(matrix) })
        return normalized
    }

    @Suppress("DEPRECATION")
    private fun recognizeImage(file: File, api: TessBaseAPI, stop: () -> Boolean): String {
        if (stop()) throw InterruptedException()
        val decoder = try { BitmapRegionDecoder.newInstance(file.path, false) } catch (_: Exception) { null }
        if (decoder == null) {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            require(bounds.outWidth > 0 && bounds.outHeight > 0)
            var sample = 1
            while ((bounds.outWidth.toLong() / sample) * (bounds.outHeight / sample) > 3_000_000) sample *= 2
            val bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: error("Cannot decode image")
            return try {
                if (stop()) throw InterruptedException()
                recognizeTile(api, bitmap)
            } finally { bitmap.recycle() }
        }
        try {
            var sample = 1
            while (decoder.width / sample > 1800) sample *= 2
            val tileHeight = 1800 * sample
            val overlap = 140 * sample
            val lines = mutableListOf<String>()
            var top = 0
            while (top < decoder.height) {
                if (stop()) throw InterruptedException()
                val bottom = minOf(decoder.height, top + tileHeight)
                val tile = decoder.decodeRegion(Rect(0, top, decoder.width, bottom),
                    BitmapFactory.Options().apply { inSampleSize = sample }) ?: error("Cannot read image region")
                val next = try { recognizeTile(api, tile).lines().filter { it.isNotBlank() } }
                    finally { tile.recycle() }
                // Remove only matching lines at the join. Repeated text elsewhere is valid.
                val duplicate = (minOf(8, lines.size, next.size) downTo 1).firstOrNull { size ->
                    lines.takeLast(size).zip(next.take(size)).all { (a, b) -> a.trim().equals(b.trim(), ignoreCase = true) }
                } ?: 0
                lines.addAll(next.drop(duplicate))
                if (bottom == decoder.height) break
                top = bottom - overlap
            }
            return lines.joinToString("\n")
        } finally { decoder.recycle() }
    }
}
