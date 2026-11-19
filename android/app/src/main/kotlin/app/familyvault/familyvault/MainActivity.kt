package app.familyvault.familyvault

import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private val fileImports = FileImports(this)
    private data class Export(val file: File, val length: Long, val reply: MethodChannel.Result)
    private var export: Export? = null
    private var notificationPermission: MethodChannel.Result? = null
    private val requestNotifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        notificationPermission?.success(granted && DocumentReminders.allowed(this))
        notificationPermission = null
    }
    private val chooseBackup = registerForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        val pending = export ?: return@registerForActivityResult
        if (uri == null) {
            export = null
            pending.reply.success(null)
        } else {
            Thread {
                val receipt = runCatching { copyBackup(pending, uri) }.getOrNull()
                runOnUiThread {
                    export = null
                    if (receipt == null) {
                        pending.reply.error("copy_failed", "Could not verify the selected backup copy.", null)
                    } else {
                        pending.reply.success(receipt)
                    }
                }
            }.start()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileImports.configure(flutterEngine.dartExecutor.binaryMessenger)
        configureDocumentReminders(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.familyvault/backup-files").setMethodCallHandler { call, reply ->
            if (call.method != "export") {
                reply.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val length = call.argument<Number>("bytes")?.toLong()
            val source = runCatching { path?.let { File(it).canonicalFile } }.getOrNull()
            val backups = File(filesDir, "backups").canonicalFile
            if (source == null || source.parentFile != backups || length == null || length <= 0 ||
                !source.name.matches(Regex("[a-f0-9-]{36}\\.fvbackup")) || !source.isFile || source.length() != length || export != null) {
                reply.error("copy_unavailable", "The verified backup is unavailable.", null)
                return@setMethodCallHandler
            }
            export = Export(source, length, reply)
            try {
                chooseBackup.launch(source.name)
            } catch (_: Exception) {
                export = null
                reply.error("picker_unavailable", "No file destination is available.", null)
            }
        }
    }

    override fun onDestroy() {
        fileImports.close()
        super.onDestroy()
    }

    private fun configureDocumentReminders(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.familyvault/document-reminders").setMethodCallHandler { call, reply ->
            try {
                when (call.method) {
                    "allowed" -> reply.success(DocumentReminders.allowed(this))
                    "request" -> {
                        if (DocumentReminders.allowed(this)) {
                            reply.success(true)
                        } else if (Build.VERSION.SDK_INT >= 33 && notificationPermission == null) {
                            notificationPermission = reply
                            requestNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            reply.success(false)
                        }
                    }
                    "replace" -> {
                        val times = checkNotNull(call.arguments as? List<*>).map { (it as Number).toLong() }
                        DocumentReminders.replace(this, times)
                        reply.success(null)
                    }
                    else -> reply.notImplemented()
                }
            } catch (_: Exception) {
                if (notificationPermission === reply) notificationPermission = null
                reply.error("reminder_failed", "Could not update document reminders.", null)
            }
        }
    }

    private fun copyBackup(request: Export, uri: Uri): Map<String, Any> {
        require(uri.scheme == "content")
        // The system picker creates the destination. The app writes ciphertext only.
        val buffer = ByteArray(64 * 1024)
        contentResolver.openOutputStream(uri, "wt")!!.use { output ->
            request.file.inputStream().use { input ->
                check(input.copyTo(output, buffer.size) == request.length)
            }
            output.flush()
        }
        val digest = MessageDigest.getInstance("SHA-256")
        var length = 0L
        contentResolver.openInputStream(uri)!!.use { input ->
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                length += count
                check(length <= request.length)
                digest.update(buffer, 0, count)
            }
        }
        check(length == request.length)
        return mapOf("bytes" to length, "digest" to digest.digest().joinToString("") { "%02x".format(it) })
    }
}
