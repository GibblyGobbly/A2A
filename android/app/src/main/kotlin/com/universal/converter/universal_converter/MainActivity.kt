package com.universal.converter.universal_converter

import android.app.DownloadManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.MediaCodecList
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.universal.converter/storage"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    // Running AV1 encoder processes, by session id, so they can be cancelled.
    private val av1Processes = java.util.concurrent.ConcurrentHashMap<Int, Process>()

    // Files shared into the app before Flutter asked for them.
    private val pendingShared = mutableListOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receiveShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShare(intent)
    }

    /** Copies shared content:// files into the cache so Dart and FFmpeg can read them by path. */
    private fun receiveShare(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> intentStream(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> uris.addAll(intentStreams(intent))
            else -> return
        }
        if (uris.isEmpty()) return
        worker.execute {
            val dir = File(cacheDir, "shared_${System.currentTimeMillis()}").apply { mkdirs() }
            val paths = uris.mapNotNull { copyToCache(it, dir) }
            mainHandler.post {
                val target = channel
                if (target != null) {
                    target.invokeMethod("sharedFiles", paths)
                } else {
                    pendingShared.addAll(paths)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun intentStream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun intentStreams(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)) ?: emptyList()

    private fun copyToCache(uri: Uri, dir: File): String? {
        return try {
            var name: String? = null
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
            val safeName = (name ?: uri.lastPathSegment ?: "shared_file").replace(Regex("[\\\\/:*?\"<>|]"), "_")
            var target = File(dir, safeName)
            var n = 2
            while (target.exists()) {
                target = File(dir, "${n}_$safeName")
                n++
            }
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            } ?: return null
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSharedFiles" -> {
                    result.success(pendingShared.toList())
                    pendingShared.clear()
                }
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "getAppVersion" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(info.versionName ?: "")
                }
                "openUrl" -> {
                    // Opens the link in the user's browser; A2A itself has no network access.
                    val url = call.argument<String>("url")
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
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
                        MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null) { _, _ -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "openFolder" -> openFolder(call.argument<String>("path"), result)
                "hasHardwareAv1Encoder" -> result.success(hasHardwareAv1Encoder())
                "hasAv1Encoder" -> result.success(av1EncoderBinary().canExecute())
                "av1Encode" -> {
                    val id = call.argument<Int>("id")
                    val args = call.argument<List<String>>("args")
                    if (id == null || args == null) {
                        result.error("INVALID_ARGS", "id and args are required", null)
                    } else {
                        runAv1Encode(id, args, result)
                    }
                }
                "av1Cancel" -> {
                    call.argument<Int>("id")?.let { av1Processes[it]?.destroy() }
                    result.success(true)
                }
                "renderPdfPages" -> {
                    val path = call.argument<String>("path")
                    val outDir = call.argument<String>("outDir")
                    val format = call.argument<String>("format") ?: "png"
                    val dpi = call.argument<Int>("dpi") ?: 150
                    val quality = call.argument<Int>("quality") ?: 85
                    if (path == null || outDir == null) {
                        result.error("INVALID_ARGS", "path and outDir are required", null)
                    } else {
                        // PdfRenderer is CPU heavy; keep it off the platform thread.
                        worker.execute {
                            try {
                                val pages = renderPdfPages(path, outDir, format, dpi, quality)
                                mainHandler.post { result.success(pages) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("RENDER_ERROR", e.message ?: e.toString(), null) }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFolder(path: String?, result: MethodChannel.Result) {
        // A file:// Uri throws FileUriExposedException on API 24+, so open the folder through
        // the external storage documents provider, then fall back to the system Downloads screen.
        val root = Environment.getExternalStorageDirectory().absolutePath
        val relative = path?.takeIf { it.startsWith("$root/") }?.removePrefix("$root/") ?: "Download/OmniConvert"
        val folderUri = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:$relative"
        )
        val viewFolder = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(folderUri, DocumentsContract.Document.MIME_TYPE_DIR)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(viewFolder)
            result.success(true)
            return
        } catch (_: Exception) {
            // No app handles the documents-provider folder intent; use the Downloads screen below.
        }
        try {
            startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FOLDER_ERROR", e.message, null)
        }
    }

    /** Static FFmpeg + SVT-AV1 executable, installed as a native library. */
    private fun av1EncoderBinary() = File(applicationInfo.nativeLibraryDir, "libffmpeg_av1.so")

    /**
     * Runs the SVT-AV1 encoder binary. Progress (encoded media time in
     * microseconds) is pushed to Dart as "av1Progress"; the result carries the
     * exit code and the last lines of the log for error reporting.
     */
    private fun runAv1Encode(id: Int, args: List<String>, result: MethodChannel.Result) {
        val command = listOf(av1EncoderBinary().absolutePath, "-nostdin", "-nostats", "-progress", "pipe:1") + args
        val process = try {
            ProcessBuilder(command).start()
        } catch (e: Exception) {
            result.error("AV1_START_FAILED", e.message ?: e.toString(), null)
            return
        }
        av1Processes[id] = process
        val logTail = java.util.ArrayDeque<String>()
        val stderrReader = Thread {
            process.errorStream.bufferedReader().forEachLine { line ->
                synchronized(logTail) {
                    logTail.addLast(line)
                    if (logTail.size > 40) logTail.removeFirst()
                }
            }
        }.apply { start() }
        Thread {
            process.inputStream.bufferedReader().forEachLine { line ->
                if (line.startsWith("out_time_us=")) {
                    line.substringAfter('=').toLongOrNull()?.let { micros ->
                        mainHandler.post { channel?.invokeMethod("av1Progress", mapOf("id" to id, "timeUs" to micros)) }
                    }
                }
            }
            val code = process.waitFor()
            stderrReader.join(2000)
            av1Processes.remove(id)
            val log = synchronized(logTail) { logTail.joinToString("\n") }
            mainHandler.post { result.success(mapOf("code" to code, "log" to log)) }
        }.start()
    }

    private fun hasHardwareAv1Encoder(): Boolean {
        return try {
            MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
                if (!info.isEncoder) return@any false
                if (!info.supportedTypes.any { it.equals("video/av01", ignoreCase = true) }) return@any false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.isHardwareAccelerated
                } else {
                    !info.name.startsWith("OMX.google.") && !info.name.startsWith("c2.android.")
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun renderPdfPages(path: String, outDir: String, format: String, dpi: Int, quality: Int): List<String> {
        val dir = File(outDir)
        if (!dir.exists()) dir.mkdirs()
        val baseName = File(path).nameWithoutExtension.replace(Regex("[^\\w.-]"), "_")
        val isJpeg = format == "jpg" || format == "jpeg"
        val ext = if (isJpeg) "jpg" else "png"
        val outputs = mutableListOf<String>()

        ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                for (index in 0 until renderer.pageCount) {
                    renderer.openPage(index).use { page ->
                        // Page size is in points (1/72 inch). Cap the long edge to bound memory use.
                        var scale = dpi / 72f
                        val longEdge = maxOf(page.width, page.height) * scale
                        if (longEdge > 4096f) scale *= 4096f / longEdge
                        val width = maxOf(1, (page.width * scale).toInt())
                        val height = maxOf(1, (page.height * scale).toInt())
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        try {
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            val outFile = File(dir, "${baseName}_page${index + 1}.$ext")
                            FileOutputStream(outFile).use { stream ->
                                val compressFormat = if (isJpeg) Bitmap.CompressFormat.JPEG else Bitmap.CompressFormat.PNG
                                if (!bitmap.compress(compressFormat, quality, stream)) {
                                    throw IllegalStateException("Could not encode page ${index + 1}")
                                }
                            }
                            outputs.add(outFile.absolutePath)
                        } finally {
                            bitmap.recycle()
                        }
                    }
                }
            }
        }
        return outputs
    }

    override fun onDestroy() {
        av1Processes.values.forEach { it.destroy() }
        worker.shutdown()
        super.onDestroy()
    }
}
