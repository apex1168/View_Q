package org.viewq.view_q

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.io.ByteArrayOutputStream

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class LibraryStoreTest {
    private fun LibraryStore.finish(id: String, text: String?, failed: Boolean) {
        val generation = readableDatabase.rawQuery("SELECT generation FROM shots WHERE id=?", arrayOf(id)).use {
            if (it.moveToFirst()) it.getLong(0) else -1L
        }
        finish(id, text, failed, generation)
    }
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private fun source(): File {
        val file = File.createTempFile("source", ".png",context.cacheDir)
        val bitmap = Bitmap.createBitmap(40,40,Bitmap.Config.ARGB_8888)
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
        bitmap.recycle()
        return file
    }
    @Test fun copySurvivesOriginalDeletionAndReopen() {
        val original = source()
        val id = LibraryStore(context).use { it.save(Uri.fromFile(original)) }
        original.delete()
        LibraryStore(context).use {
            val row = it.list("").single { row -> row["id"] == id }
            assertTrue(File(row["path"] as String).exists())
            assertEquals("pending",row["status"])
        }
    }
    @Test fun searchHandlesCasePunctuationAndNoText() {
        LibraryStore(context).use {
            val id = it.save(Uri.fromFile(source()))
            it.finish(id,"Train ticket: London, platform 7.",false)
            assertEquals(id,it.list("TRAIN, ticket!").single()["id"])
            assertTrue(it.list("unrelated").isEmpty())
            assertEquals(id,it.list("ket, Lon!").single()["id"])
            assertEquals(id,it.list("7").single()["id"])
            assertTrue(it.list("\" OR missing *").isEmpty())
            assertTrue(it.list("!!!").isEmpty())
            val empty = it.save(Uri.fromFile(source()))
            it.finish(empty,"",false)
            assertTrue(it.list("").any { row -> row["id"] == empty })
        }
    }
    @Test fun lateOcrCannotRestoreDeletedImage() {
        LibraryStore(context).use {
            val id = it.save(Uri.fromFile(source()))
            val image = it.pending()!!.second
            it.delete(id)
            it.finish(id,"secret",false)
            assertFalse(image.exists())
            assertTrue(it.list("secret").isEmpty())
            assertTrue(it.list("").none { row -> row["id"] == id })
        }
    }
    @Test fun failureRetainsImageAndRetryRequeuesIt() {
        LibraryStore(context).use {
            val id = it.save(Uri.fromFile(source()))
            it.finish(id,null,true)
            assertEquals("failed",it.list("").single()["status"])
            it.retry(id)
            assertEquals(id,it.pending()!!.first)
        }
    }
    @Test fun rereadingReplacesIndexAndPreservesLastTextOnFailure() {
        LibraryStore(context).use {
            val id = it.save(Uri.fromFile(source()))
            it.finish(id, "Old invoice OCR", false)
            it.retry(id)
            it.finish(id, "Boarding pass\nDeparture 22 Nov 2026\nPNR: A7FX3", false)
            assertTrue(it.list("invoice").isEmpty())
            val row = it.list("boarding").single()
            assertEquals("Travel", row["category"])
            assertTrue((row["facts"] as String).contains("A7FX3"))
            it.retry(id)
            it.finish(id, null, true)
            assertEquals(id, it.list("departure").single()["id"])
        }
    }
    @Test fun approximateSearchCanRecoverATranscriptionError() {
        LibraryStore(context).use {
            val id = it.save(Uri.fromFile(source()))
            it.finish(id, "Booking recelpt reference 61073", false)
            val recovered = it.list("receipt 61073").single()
            assertEquals(id, recovered["id"])
            assertEquals(listOf("recelpt"), recovered["approximate"])
            assertTrue(it.list("receipt 61074").isEmpty())
            assertEquals(emptyList<String>(), it.list("booking").single()["approximate"])
        }
    }
    @Test fun correctedTextIsSearchableAndWinsOverInFlightOcr() {
        LibraryStore(context).use { store ->
            val id = store.save(Uri.fromFile(source()))
            store.finish(id, "Old invoice amount", false)
            store.retry(id)
            store.correctText(id, "Boarding pass\nDeparture 22 Nov 2026\nPNR: X7B91")
            store.finish(id, "Stale OCR result", false)
            assertTrue(store.list("stale").isEmpty())
            assertTrue(store.list("invoice").isEmpty())
            val corrected = store.list("X7B91").single()
            assertEquals(id, corrected["id"])
            assertEquals("Travel", corrected["category"])
            assertEquals(corrected["text"], store.list("", id).single()["text"])
            store.delete(id)
            assertTrue(store.list("X7B91").isEmpty())
        }
    }
    @Test fun backupRestoresMissingImagesAndTextWithoutOverwritingExistingEdits() {
        LibraryStore(context).use { store ->
            val restoredId = store.save(Uri.fromFile(source()))
            val existingId = store.save(Uri.fromFile(source()))
            store.correctText(restoredId, "Boarding pass PNR: RU5321")
            store.correctText(existingId, "Old transcript")
            val backup = ByteArrayOutputStream()
            assertEquals(2, LibraryBackup.write(backup, store, setOf(restoredId)))
            val bytes = backup.toByteArray()
            store.delete(restoredId)
            store.correctText(existingId, "My corrected text")
            val restored = LibraryBackup.restore(bytes.inputStream(), store, context.cacheDir)
            assertEquals(1, restored.added)
            assertEquals(setOf(restoredId), restored.favorites)
            val row = store.list("RU5321").single()
            assertEquals(restoredId, row["id"])
            assertTrue(File(row["path"] as String).isFile)
            assertEquals("My corrected text", store.list("", existingId).single()["text"])
            assertEquals(0, LibraryBackup.restore(bytes.inputStream(), store, context.cacheDir).added)
        }
    }

    @Test fun incompleteBackupDoesNotChangeLibrary() {
        LibraryStore(context).use { store ->
            val id = store.save(Uri.fromFile(source()))
            val backup = ByteArrayOutputStream()
            LibraryBackup.write(backup, store, emptySet())
            store.delete(id)
            val bytes = backup.toByteArray()
            val broken = bytes.copyOf(bytes.size / 3)
            assertTrue(runCatching { LibraryBackup.restore(broken.inputStream(), store, context.cacheDir) }.isFailure)
            assertTrue(store.list("").isEmpty())
        }
    }

    @Test fun galleryTransfersOnlyPreviewAndDetailReturnsFullTranscript() {
        LibraryStore(context).use { store ->
            val id = store.save(Uri.fromFile(source()))
            val transcript = "Track shipment AWD991 at https://example.org/package\n" + "Shipping details ".repeat(250)
            store.correctText(id, transcript)
            val preview = store.list("AWD991", previews = true).single()
            assertEquals(id, preview["id"])
            assertEquals("", preview["text"])
            assertEquals("", preview["facts"])
            assertEquals(true, preview["hasText"])
            assertEquals(true, preview["hasLink"])
            assertTrue((preview["snippet"] as String).contains("AWD991"))
            assertEquals(transcript, store.list("", id).single()["text"])
        }
    }

    @Test fun staleJobCannotWinAfterCorrectionAndAnotherRetry() {
        LibraryStore(context).use { store ->
            val id = store.save(Uri.fromFile(source()))
            store.correctText(id, "Confirmed booking R72649")
            store.retry(id)
            val oldJob = store.pending()!!
            assertEquals(id, store.list("R72649").single()["id"])
            store.correctText(id, "Corrected departure R72649")
            store.retry(id)
            val currentJob = store.pending()!!
            assertFalse(store.owns(oldJob))
            assertTrue(store.owns(currentJob))
            store.finish(id, "Stale result", false, oldJob.generation)
            assertTrue(store.list("stale").isEmpty())
            assertEquals(id, store.list("departure").single()["id"])
            store.finish(id, "New departure R72649", false, currentJob.generation)
            assertEquals("done", store.list("", id).single()["status"])
        }
    }

    @Test fun pagedCollectionDoesNotLoseMatchesOutsideFirstPage() {
        LibraryStore(context).use { store ->
            repeat(7) { index ->
                val id = store.save(Uri.fromFile(source()))
                store.correctText(id, if (index % 2 == 0) "Boarding pass PNR: X$index" else "Shopping notes $index")
            }
            val first = store.list("", previews = true, browse = LibraryStore.BrowseOptions(limit = 2, category = "Travel"))
            assertEquals(3, first.size) // One extra record tells the caller there is another page.
            assertTrue(first.all { it["category"] == "Travel" })
            val second = store.list("", previews = true, browse = LibraryStore.BrowseOptions(offset = 2, limit = 2, category = "Travel"))
            val ids = (first.take(2) + second.take(2)).map { it["id"] }
            assertEquals(4, ids.toSet().size)
        }
    }

    @Test fun manualCategorySurvivesRereadingAndBackup() {
        LibraryStore(context).use { store ->
            val id = store.save(Uri.fromFile(source()))
            store.correctText(id, "General document")
            store.setCategory(id, "Travel")
            store.retry(id)
            val job = store.pending()!!
            store.finish(id, "Trip packing checklist", false, job.generation)
            assertEquals("Travel", store.list("", id).single()["category"])
            val archive = ByteArrayOutputStream()
            LibraryBackup.write(archive, store, emptySet())
            store.delete(id)
            LibraryBackup.restore(archive.toByteArray().inputStream(), store, context.cacheDir)
            assertEquals("Travel", store.list("", id).single()["category"])
            store.setCategory(id, "")
            assertEquals("Note", store.list("", id).single()["category"])
        }
    }
}
