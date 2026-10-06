package com.universal.converter.universal_converter

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.universal.converter/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPublicDirectory" -> {
                    try {
                        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        val appDir = File(downloadDir, "OmniConvert")
                        if (!appDir.exists()) {
                            appDir.mkdirs()
                        }
                        result.success(appDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null
                        ) { _, _ -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "openFolder" -> {
                    val path = call.argument<String>("path")
                    try {
                        val targetDir = if (path != null) File(path) else File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "OmniConvert")
                        val dirToOpen = if (targetDir.isDirectory) targetDir else targetDir.parentFile ?: targetDir

                        val intent = Intent(Intent.ACTION_VIEW)
                        val uri = Uri.parse(dirToOpen.absolutePath)
                        intent.setDataAndType(Uri.fromFile(dirToOpen), "resource/folder")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            val chooserIntent = Intent(Intent.ACTION_VIEW)
                            chooserIntent.setDataAndType(Uri.parse("content://media/external/file"), "*/*")
                            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(Intent.createChooser(chooserIntent, "Open Folder"))
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("OPEN_FOLDER_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
