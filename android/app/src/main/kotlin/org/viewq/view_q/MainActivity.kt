package org.viewq.view_q

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val io = Executors.newSingleThreadExecutor()
    private var picker: MethodChannel.Result? = null
    private var backupPicker: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger,"org.viewq/library")
        channel.setMethodCallHandler { call, result ->
            if (call.method == "exportBackup" || call.method == "restoreBackup") {
                if (backupPicker != null || picker != null) {
                    result.error("busy", "A file picker is already open.", null)
                    return@setMethodCallHandler
                }
                val export = call.method == "exportBackup"
                backupPicker = result
                try {
                    val intent = Intent(if (export) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE).setType(if (export) "application/zip" else "*/*")
                    if (export) intent.putExtra(Intent.EXTRA_TITLE, "View-Q-backup.zip")
                    startActivityForResult(intent, if (export) 101 else 102)
                } catch (_: Exception) {
                    backupPicker = null
                    result.error("backup", "Could not open the file picker.", null)
                }
                return@setMethodCallHandler
            }
            if (call.method == "openLink") {
                val uri = Uri.parse(call.argument<String>("url").orEmpty())
                try {
                    require(uri.scheme?.lowercase() in listOf("http", "https") && !uri.host.isNullOrBlank())
                    startActivity(Intent(Intent.ACTION_VIEW, uri))
                    result.success(null)
                } catch (_: Exception) { result.error("link", "Could not open link.", null) }
                return@setMethodCallHandler
            }
            if (call.method == "shareScreenshot") {
                io.execute {
                    try {
                        val image = File(call.argument<String>("path").orEmpty()).canonicalFile
                        require(image.parentFile == File(noBackupFilesDir, "images").canonicalFile && image.isFile)
                        val extension = call.argument<String>("extension").orEmpty()
                        require(extension in setOf("png", "jpg", "gif", "webp", "heic", "img"))
                        val folder = File(cacheDir, "shared-screenshots").apply { mkdirs() }
                        folder.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86_400_000 }?.forEach { it.delete() }
                        val copy = File(folder, "View-Q-${UUID.randomUUID()}.$extension")
                        image.copyTo(copy)
                        val uri = FileProvider.getUriForFile(this, "$packageName.share", copy)
                        runOnUiThread {
                            try {
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = call.argument<String>("mime") ?: "image/*"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(send, null))
                                result.success(null)
                            } catch (_: Exception) { result.error("share", "Could not share screenshot.", null) }
                        }
                    } catch (_: Exception) { runOnUiThread { result.error("share", "Could not share screenshot.", null) } }
                }
                return@setMethodCallHandler
            }
            if (call.method == "pick") {
                if (picker != null || backupPicker != null) { result.error("busy","A file picker is already open.",null); return@setMethodCallHandler }
                picker = result
                // Native Photo Picker where available, system document picker fallback on older phones.
                try {
                    val selection = if (android.os.Build.VERSION.SDK_INT < 33) {
                        Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("image/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    } else ActivityResultContracts.PickVisualMedia().createIntent(this,
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    startActivityForResult(selection,100)
                } catch (_: Exception) { picker = null; result.error("picker","Could not open the photo picker.",null) }
            } else io.execute {
                try {
                    val value: Any? = LibraryStore(applicationContext).use { store -> when(call.method) {
                        "list" -> store.list(call.argument<String>("query") ?: "")
                        "previews" -> store.list(call.argument<String>("query") ?: "", previews = true)
                        "browse" -> {
                            val limit = (call.argument<Int>("limit") ?: 60).coerceIn(1, 100)
                            val offset = (call.argument<Int>("offset") ?: 0).coerceAtLeast(0)
                            val rows = store.list(call.argument<String>("query") ?: "", previews = true,
                                browse = LibraryStore.BrowseOptions(offset, limit,
                                    call.argument<String>("category") ?: "",
                                    call.argument<Number>("from")?.toLong(),
                                    call.argument<Number>("until")?.toLong(),
                                    call.argument<List<String>>("ids")))
                            mapOf("items" to rows.take(limit), "hasMore" to (rows.size > limit), "next" to (offset + minOf(limit, rows.size)))
                        }
                        "screenshot" -> store.list("", call.argument<String>("id")!!).firstOrNull()
                        "setCategory" -> {
                            val id = call.argument<String>("id")!!
                            store.setCategory(id, call.argument<String>("category") ?: "")
                            store.list("", id).firstOrNull()
                        }
                        "correctText" -> {
                            val id = call.argument<String>("id")!!
                            store.correctText(id, call.argument<String>("text")!!)
                            store.list("", id).firstOrNull()
                        }
                        "indexStatus" -> store.indexStatus()
                        "themeMode" -> {
                            val prefs = getPreferences(MODE_PRIVATE)
                            call.argument<Boolean>("dark")?.let { prefs.edit().putBoolean("dark_theme", it).apply() }
                            prefs.getBoolean("dark_theme", true)
                        }
                        "favorites" -> getPreferences(MODE_PRIVATE).getStringSet("favorites", emptySet())!!.toList()
                        "searchHistory", "recordSearchOpen" -> {
                            val prefs = getPreferences(MODE_PRIVATE)
                            val history = prefs.getString("search_history", "").orEmpty()
                                .lineSequence().filter { it.isNotBlank() }.toList()
                            val id = call.argument<String>("id")
                            if (call.method == "recordSearchOpen" && id != null) {
                                val updated = (listOf(id) + history.filterNot { it == id }).take(50)
                                prefs.edit().putString("search_history", updated.joinToString("\n")).apply()
                                updated
                            } else history
                        }
                        "toggleFavorite" -> {
                            val prefs = getPreferences(MODE_PRIVATE)
                            val ids = prefs.getStringSet("favorites", emptySet())!!.toMutableSet()
                            val id = call.argument<String>("id")!!
                            if (!ids.add(id)) ids.remove(id)
                            check(prefs.edit().putStringSet("favorites", ids).commit())
                            ids.toList()
                        }
                        "delete" -> { store.delete(call.argument<String>("id")!!); null }
                        "retry" -> { store.retry(call.argument<String>("id")!!); OcrQueue.start(applicationContext); null }
                        "resume" -> { OcrQueue.active = true; OcrQueue.start(applicationContext); null }
                        else -> { runOnUiThread { result.notImplemented() }; return@execute }
                    } }
                    runOnUiThread { result.success(value) }
                } catch (e: Exception) { runOnUiThread { result.error("storage",e.message,null) } }
            }
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receive(intent)
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); receive(intent) }
    override fun onResume() { super.onResume(); OcrQueue.active = true; OcrQueue.start(applicationContext) }
    override fun onPause() { OcrQueue.active = false; super.onPause() }
    @Suppress("DEPRECATION")
    private fun receive(incoming: Intent) {
        if (incoming.action != Intent.ACTION_SEND && incoming.action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = if (incoming.action == Intent.ACTION_SEND_MULTIPLE)
            incoming.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        else listOfNotNull(incoming.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
        if (uris.isEmpty()) { Toast.makeText(this,"Could not save screenshot. Please share an image.",Toast.LENGTH_LONG).show(); return }
        io.execute {
            for (uri in uris) {
                try {
                    LibraryStore(applicationContext).use { it.save(uri) }
                    runOnUiThread {
                        // Native confirmation also works before Dart has attached its handler.
                        Toast.makeText(this,"Screenshot saved",Toast.LENGTH_LONG).show()
                        channel.invokeMethod("changed",null)
                    }
                } catch (_: Exception) { runOnUiThread {
                    Toast.makeText(this,"Could not save screenshot. Please try sharing it again.",Toast.LENGTH_LONG).show()
                    channel.invokeMethod("saveError",null)
                } }
            }
            OcrQueue.start(applicationContext)
        }
        // Prevent duplicate imports after ordinary activity recreation.
        intent = Intent(this,MainActivity::class.java)
    }
    @Deprecated("Android activity callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if (requestCode == 101 || requestCode == 102) {
            val reply = backupPicker ?: return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                backupPicker = null
                reply.success(null)
                return
            }
            io.execute {
                try {
                    val prefs = getPreferences(MODE_PRIVATE)
                    val favorites = prefs.getStringSet("favorites", emptySet()).orEmpty()
                    val count = LibraryStore(applicationContext).use { store ->
                        if (requestCode == 101) {
                            val output = contentResolver.openOutputStream(uri, "wt") ?: error("Could not open the backup destination.")
                            output.use { LibraryBackup.write(it, store, favorites) }
                        } else {
                            val input = contentResolver.openInputStream(uri) ?: error("Could not open the backup file.")
                            val restored = input.use { LibraryBackup.restore(it, store, cacheDir) }
                            prefs.edit().putStringSet("favorites", favorites + restored.favorites).apply()
                            restored.added
                        }
                    }
                    if (requestCode == 102) OcrQueue.start(applicationContext)
                    runOnUiThread {
                        backupPicker = null
                        reply.success(count)
                    }
                } catch (error: Exception) {
                    runOnUiThread {
                        backupPicker = null
                        reply.error("backup", error.message ?: "Could not complete the backup operation.", null)
                    }
                }
            }
            return
        }
        if (requestCode != 100) return
        val reply = picker
        picker = null
        val uri = data?.data ?: data?.clipData?.let { if (it.itemCount > 0) it.getItemAt(0).uri else null }
        if (resultCode != Activity.RESULT_OK) { reply?.success(false); return }
        if (uri == null) {
            val message = "The picker did not return an image. Please choose it again."
            if (reply != null) reply.error("picker", message, null)
            else Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            return
        }
        io.execute {
            try {
                LibraryStore(applicationContext).use { it.save(uri) }
                OcrQueue.start(applicationContext)
                runOnUiThread { reply?.success(true); if(reply == null) Toast.makeText(this,"Screenshot saved",Toast.LENGTH_LONG).show() }
            } catch(e: Exception) { runOnUiThread {
                val message = e.message ?: "Could not save screenshot."
                if (reply != null) reply.error("save",message,null)
                else Toast.makeText(this,message,Toast.LENGTH_LONG).show()
            } }
        }
    }
}
