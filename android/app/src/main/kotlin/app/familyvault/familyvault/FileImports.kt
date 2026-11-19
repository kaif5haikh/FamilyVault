package app.familyvault.familyvault

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.concurrent.Executors

/** Reads the provider that Android has granted to this activity. */
internal class FileImports(private val activity: ComponentActivity) {
    private var pendingPick: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val readers = mutableMapOf<Int, InputStream>()
    private var nextReader = 0

    private val picker = activity.registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val reply = pendingPick ?: return@registerForActivityResult
        pendingPick = null
        if (uri == null) reply.success(null) else runIo(reply) { metadata(uri) }
    }

    fun configure(messenger: BinaryMessenger) {
        MethodChannel(messenger, "app.familyvault/file-imports").setMethodCallHandler { call, reply ->
            when (call.method) {
                "pick" -> {
                    val types = call.arguments<List<String>>()
                    if (pendingPick != null || types.isNullOrEmpty()) {
                        reply.error("picker_unavailable", "The file picker is unavailable.", null)
                        return@setMethodCallHandler
                    }
                    pendingPick = reply
                    try {
                        picker.launch(types.toTypedArray())
                    } catch (_: Exception) {
                        pendingPick = null
                        reply.error("picker_unavailable", "The file picker is unavailable.", null)
                    }
                }
                "open" -> runIo(reply) {
                    val uri = Uri.parse(checkNotNull(call.arguments<String>()))
                    require(uri.scheme == ContentResolver.SCHEME_CONTENT)
                    val source = checkNotNull(activity.contentResolver.openInputStream(uri))
                    val id = ++nextReader
                    readers[id] = source
                    id
                }
                "read" -> runIo(reply) { read(checkNotNull(call.arguments<Int>())) }
                "close" -> runIo(reply) {
                    readers.remove(call.arguments<Int>())?.close()
                    null
                }
                else -> reply.notImplemented()
            }
        }
    }

    fun close() {
        pendingPick?.success(null)
        pendingPick = null
        worker.execute {
            for (reader in readers.values) runCatching { reader.close() }
            readers.clear()
        }
        worker.shutdown()
    }

    private fun metadata(uri: Uri): Map<String, Any?> {
        require(uri.scheme == ContentResolver.SCHEME_CONTENT)
        var name = "Selected file"
        var length: Long? = null
        activity.contentResolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameColumn >= 0) name = cursor.getString(nameColumn) ?: name
                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) {
                    length = cursor.getLong(sizeColumn).takeIf { it >= 0 }
                }
            }
        }
        return mapOf("uri" to uri.toString(), "name" to name, "length" to length)
    }

    private fun read(id: Int): ByteArray? {
        val source = checkNotNull(readers[id])
        try {
            val buffer = ByteArray(64 * 1024)
            val count = source.read(buffer)
            if (count >= 0) return if (count == buffer.size) buffer else buffer.copyOf(count)
        } catch (error: Exception) {
            runCatching { readers.remove(id)?.close() }
            throw error
        }
        readers.remove(id)?.close()
        return null
    }

    private fun runIo(reply: MethodChannel.Result, action: () -> Any?) {
        worker.execute {
            try {
                reply.success(action())
            } catch (_: Exception) {
                reply.error("file_unavailable", "The selected file could not be read.", null)
            }
        }
    }
}
