package com.novasystemsmx.novadx

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "novadx/gallery"
    private var sharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSendIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSendIntent(intent)
    }

    private fun handleSendIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { sharedText = it }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "saveVideo" -> {
                            val srcPath = call.argument<String>("path")
                            val fileName = call.argument<String>("fileName")
                            if (srcPath == null || fileName == null) {
                                result.error("ARGS", "path y fileName son requeridos", null)
                            } else {
                                result.success(saveVideoToGallery(File(srcPath), fileName))
                            }
                        }
                        "enqueueDownload" -> {
                            val url = call.argument<String>("url")
                            val fileName = call.argument<String>("fileName")
                            if (url == null || fileName == null) {
                                result.error("ARGS", "url y fileName son requeridos", null)
                            } else {
                                result.success(enqueueDownload(url, fileName))
                            }
                        }
                        "queryProgress" -> {
                            val id = (call.argument<Number>("id"))?.toLong()
                            if (id == null) {
                                result.error("ARGS", "id es requerido", null)
                            } else {
                                result.success(queryProgress(id))
                            }
                        }
                        "cancelDownload" -> {
                            val id = (call.argument<Number>("id"))?.toLong()
                            if (id == null) {
                                result.error("ARGS", "id es requerido", null)
                            } else {
                                val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
                                result.success(dm.remove(id))
                            }
                        }
                        "openDownload" -> {
                            val id = (call.argument<Number>("id"))?.toLong()
                            if (id == null) {
                                result.error("ARGS", "id es requerido", null)
                            } else {
                                openDownload(id)
                                result.success(true)
                            }
                        }
                        "shareDownload" -> {
                            val id = (call.argument<Number>("id"))?.toLong()
                            if (id == null) {
                                result.error("ARGS", "id es requerido", null)
                            } else {
                                shareDownload(id)
                                result.success(true)
                            }
                        }
                        "getSharedText" -> {
                            result.success(sharedText.also { sharedText = null })
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    // Descarga en segundo plano con DownloadManager del sistema.
    // Sigue aunque salgas de la app y Android muestra la notificacion
    // con el nombre del video. Si el archivo ya existe se reemplaza:
    // se borra el anterior y se descarga de nuevo con el mismo nombre.
    private fun enqueueDownload(url: String, fileName: String): Long {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val existing = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
            "NovaDX/$fileName",
        )
        if (existing.exists()) {
            existing.delete()
            MediaScannerConnection.scanFile(this, arrayOf(existing.absolutePath), null, null)
        }
        val targetName = fileName
        val request =
            DownloadManager.Request(Uri.parse(url)).apply {
                setTitle(targetName)
                setDescription("Descargando con NovaDX")
                setMimeType("video/mp4")
                setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                )
                setAllowedOverMetered(true)
                setAllowedOverRoaming(true)
                setDestinationInExternalPublicDir(
                    Environment.DIRECTORY_MOVIES,
                    "NovaDX/$targetName",
                )
            }
        return dm.enqueue(request)
    }

    private fun queryProgress(id: Long): Map<String, Any> {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        dm.query(DownloadManager.Query().setFilterById(id))?.use { c ->
            if (c.moveToFirst()) {
                val received =
                    c.getLong(
                        c.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                        ),
                    )
                val total =
                    c.getLong(
                        c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                    )
                val status =
                    c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                val uri =
                    c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                return mapOf(
                    "received" to received,
                    "total" to total,
                    "status" to status,
                    "fileName" to fileNameFromUri(uri),
                )
            }
        }
        return mapOf("received" to 0L, "total" to -1L, "status" to 16, "fileName" to "")
    }

    private fun localUri(id: Long): Uri {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        dm.query(DownloadManager.Query().setFilterById(id))?.use { c ->
            if (c.moveToFirst()) {
                val raw = c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                if (!raw.isNullOrEmpty()) return Uri.parse(raw)
            }
        }
        throw Exception("El archivo ya no esta disponible.")
    }

    private fun openDownload(id: Long) {
        val uri = localUri(id)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "video/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(view)
    }

    private fun shareDownload(id: Long) {
        val uri = localUri(id)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(Intent.createChooser(send, "Compartir video").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun fileNameFromUri(uri: String?): String {
        if (uri.isNullOrEmpty()) return ""
        return try {
            val path = Uri.parse(uri).path ?: return ""
            File(path).name
        } catch (_: Exception) {
            ""
        }
    }

    private fun saveVideoToGallery(src: File, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/NovaDX")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri =
                resolver.insert(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: throw Exception("No se pudo crear la entrada en MediaStore")
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out) }
            } ?: throw Exception("No se pudo escribir el video en galeria")
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            src.delete()
            return uri.toString()
        } else {
            val movies =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            val dir = File(movies, "NovaDX")
            if (!dir.exists()) dir.mkdirs()
            var dest = File(dir, fileName)
            if (dest.exists()) dest = unique(dest)
            FileInputStream(src).use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            }
            src.delete()
            MediaScannerConnection.scanFile(
                this,
                arrayOf(dest.absolutePath),
                arrayOf("video/mp4"),
                null,
            )
            return dest.absolutePath
        }
    }

    private fun unique(file: File): File {
        var i = 1
        var candidate: File
        do {
            candidate = File(file.parent, "${file.nameWithoutExtension}_$i.${file.extension}")
            i++
        } while (candidate.exists())
        return candidate
    }
}
