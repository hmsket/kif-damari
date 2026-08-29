package com.example.kifdamari

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kifdamari/saf"
    private val REQUEST_CODE_OPEN = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or 
                                 Intent.FLAG_GRANT_WRITE_URI_PERMISSION or 
                                 Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    startActivityForResult(intent, REQUEST_CODE_OPEN)
                }
                "readFile" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_URI", "URI is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriString)
                        val inputStream: InputStream? = contentResolver.openInputStream(uri)
                        val bytes = inputStream?.readBytes()
                        inputStream?.close()
                        result.success(bytes)
                    } catch (e: Exception) {
                        result.error("READ_ERROR", e.localizedMessage, null)
                    }
                }
                "writeFile" -> {
                    val uriString = call.argument<String>("uri")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (uriString == null || bytes == null) {
                        result.error("INVALID_ARGS", "URI or bytes is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriString)
                        
                        // 💡 FileDescriptor を使った確実な書き込み＆同期
                        val pfd = contentResolver.openFileDescriptor(uri, "w")
                        if (pfd != null) {
                            val fos = FileOutputStream(pfd.fileDescriptor)
                            fos.write(bytes)
                            fos.flush()
                            pfd.fileDescriptor.sync()
                            fos.close()
                            pfd.close()
                            
                            result.success(true)
                        } else {
                            result.error("WRITE_ERROR", "ParcelFileDescriptor is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("WRITE_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_OPEN) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.data
                if (uri != null) {
                    val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    try {
                        contentResolver.takePersistableUriPermission(uri, takeFlags)
                    } catch (e: Exception) {
                        // フォールバック
                    }
                    pendingResult?.success(uri.toString())
                } else {
                    pendingResult?.error("NO_URI", "URI not found", null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}
