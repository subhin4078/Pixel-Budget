package dev.pixelbudget.pixel_budget

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class CsvDocuments(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        private const val REQUEST_OPEN = 4100
        private const val REQUEST_SAVE = 4101
        private const val MAX_IMPORT_BYTES = 25L * 1024 * 1024
        private const val BUFFER_SIZE = 16 * 1024
    }

    private val executor = Executors.newSingleThreadExecutor()
    private var pendingResult: MethodChannel.Result? = null
    private var exportFile: File? = null

    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val exporting = when (call.method) {
            "openToFile" -> false
            "saveFromFile" -> true
            else -> {
                result.notImplemented()
                return
            }
        }
        if (pendingResult != null) {
            result.error("csv_busy", "A document operation is already in progress", null)
            return
        }
        val fileName = if (exporting) call.argument<String>("name") else null
        val sourcePath = if (exporting) call.argument<String>("path") else null
        val sourceFile = if (exporting) {
            if (fileName.isNullOrBlank() || sourcePath.isNullOrBlank()) {
                result.error("csv_invalid_args", "Missing export file name or path", null)
                return
            }
            val file = File(sourcePath)
            if (!file.isFile) {
                result.error("csv_invalid_args", "Export source file not found", null)
                return
            }
            file
        } else {
            null
        }
        val intent = Intent(
            if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT,
        ).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (exporting) "text/csv" else "*/*"
            if (exporting) {
                putExtra(Intent.EXTRA_TITLE, fileName)
            } else {
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf(
                        "text/*",
                        "application/csv",
                        "application/vnd.ms-excel",
                        "application/octet-stream",
                    ),
                )
            }
        }
        pendingResult = result
        exportFile = sourceFile
        try {
            activity.startActivityForResult(intent, if (exporting) REQUEST_SAVE else REQUEST_OPEN)
        } catch (error: Exception) {
            pendingResult = null
            exportFile = null
            result.error("csv_picker_failed", error.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_OPEN && requestCode != REQUEST_SAVE) return
        val result = pendingResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingResult = null
            exportFile = null
            result.success(null)
            return
        }
        val source = exportFile
        executor.execute {
            var tempFile: File? = null
            try {
                val value: Any = if (requestCode == REQUEST_SAVE) {
                    val file = source ?: throw IOException("Missing export source file")
                    val output = activity.contentResolver.openOutputStream(uri, "w")
                        ?: throw IOException("Cannot open the export document")
                    output.use { out ->
                        file.inputStream().use { input ->
                            input.copyTo(out, BUFFER_SIZE)
                        }
                    }
                    true
                } else {
                    val input = activity.contentResolver.openInputStream(uri)
                        ?: throw IOException("Cannot open the import document")
                    val target = File.createTempFile("csv-import-", ".csv", activity.cacheDir)
                    tempFile = target
                    input.use { stream ->
                        target.outputStream().use { out ->
                            val buffer = ByteArray(BUFFER_SIZE)
                            var total = 0L
                            while (true) {
                                val read = stream.read(buffer)
                                if (read < 0) break
                                total += read
                                if (total > MAX_IMPORT_BYTES) {
                                    throw IOException("CSV file exceeds the 25 MB size limit")
                                }
                                out.write(buffer, 0, read)
                            }
                        }
                    }
                    target.absolutePath
                }
                activity.runOnUiThread {
                    if (pendingResult === result) {
                        pendingResult = null
                        exportFile = null
                        if (!activity.isDestroyed) {
                            result.success(value)
                        } else {
                            tempFile?.delete()
                        }
                    } else {
                        tempFile?.delete()
                    }
                }
            } catch (error: Exception) {
                tempFile?.delete()
                activity.runOnUiThread {
                    if (pendingResult === result) {
                        pendingResult = null
                        exportFile = null
                        if (!activity.isDestroyed) {
                            result.error("csv_io_failed", error.message, null)
                        }
                    }
                }
            }
        }
    }

    fun close() {
        val pending = pendingResult
        pendingResult = null
        exportFile = null
        if (pending != null && !activity.isDestroyed) {
            pending.error("csv_cancelled", "Document operation cancelled", null)
        }
        executor.shutdown()
    }
}
