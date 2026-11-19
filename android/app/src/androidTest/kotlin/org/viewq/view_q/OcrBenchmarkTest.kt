package org.viewq.view_q

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.Assert.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Generated, non-private fixtures exercise native OCR on the connected phone.
 * These measurements are a smoke benchmark, not a claim about real captures. */
@Suppress("DEPRECATION")
class OcrBenchmarkTest {
    @Test
    fun testOfflineOcrAndSearchFixtures() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val target = instrumentation.targetContext
        val sandbox = File(target.cacheDir, "viewq-benchmark").apply { mkdirs() }
        val context = object : android.content.ContextWrapper(target) {
            override fun getNoBackupFilesDir() = File(sandbox, "private").apply { mkdirs() }
            override fun getCacheDir() = File(sandbox, "cache").apply { mkdirs() }
            override fun getFilesDir() = sandbox
        }
        val model = File(context.noBackupFilesDir, "ocr-accurate-v1/tessdata/eng.traineddata")
        model.parentFile!!.mkdirs()
        target.assets.open("flutter_assets/assets/tessdata/eng.traineddata").use { input ->
            model.outputStream().use { input.copyTo(it) }
        }
        val fixtures = listOf(
            Fixture("receipt", false, 1400, listOf("Coffee receipt", "TOTAL INR 240.00", "Order number K72649")),
            Fixture("dark-message", true, 1400, listOf("Meeting confirmed", "Appointment Friday 11 AM", "Reference C92418")),
            Fixture("long-capture", false, 4800, listOf("Travel itinerary", "Flight departure 09 AM", "Booking reference X53827")),
            Fixture("small-text", false, 1500, listOf(
                "Order summary",
                "Delivery address confirmed",
                "Payment received successfully",
                "Your parcel is being prepared",
                "Estimated arrival Monday morning",
                "Keep this message for your records",
                "Contact support for order updates",
                "Order reference S28463"
            ), 20f)
        )
        val results = JSONArray()
        LibraryStore(context).use { store ->
            store.list("").forEach { store.delete(it["id"] as String) }
            for (fixture in fixtures) {
                val bitmap = Bitmap.createBitmap(720, fixture.height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawColor(if (fixture.dark) Color.rgb(16, 21, 20) else Color.WHITE)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (fixture.dark) Color.WHITE else Color.BLACK
                    textSize = fixture.fontSize
                    typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
                }
                fixture.lines.forEachIndexed { index, line ->
                    val y = 140f + index * ((fixture.height - 400f) / maxOf(1, fixture.lines.size - 1))
                    canvas.drawText(line, 32f, y, paint)
                }
                val source = File(context.cacheDir, "benchmark-" + fixture.name + ".png")
                source.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                bitmap.recycle()
                val id = store.save(Uri.fromFile(source))
                val started = SystemClock.elapsedRealtime()
                OcrQueue.drain(context) { false }
                val elapsed = SystemClock.elapsedRealtime() - started
                val row = store.list("", id).single()
                val recognized = row["text"] as String
                val words = fixture.lines.joinToString(" ").lowercase().split(Regex("[^a-z0-9]+")).filter { it.isNotEmpty() }
                val actual = recognized.lowercase().split(Regex("[^a-z0-9]+")).toSet()
                val recall = words.count { it in actual }.toDouble() / words.size
                val searchStart = SystemClock.elapsedRealtimeNanos()
                val anchor = fixture.lines.last().substringAfterLast(' ')
                val found = store.list(anchor).any { it["id"] == id }
                val searchMs = (SystemClock.elapsedRealtimeNanos() - searchStart) / 1_000_000.0
                results.put(JSONObject().put("fixture", fixture.name).put("ocrMs", elapsed)
                    .put("wordRecall", recall).put("anchorFound", found).put("searchMs", searchMs)
                    .put("text", recognized))
                val report = results.toString(2)
                File(context.filesDir, "ocr-benchmark.json").writeText(report)
                android.util.Log.i("ViewQBenchmark", report)
                source.delete()
                assertEquals("Fixture OCR failed: " + fixture.name, "done", row["status"])
                assertTrue("Fixture recall below 75%: " + fixture.name + "\n" + recognized, recall >= .75)
                assertTrue("Reference not searchable: " + fixture.name + "\n" + recognized, found)
            }
        }
    }

    private data class Fixture(val name: String, val dark: Boolean, val height: Int, val lines: List<String>, val fontSize: Float = 30f)
}
