package com.diatomicsoft.xiaomi_remote

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private var shareReady = false
        private val pendingShares = mutableListOf<Map<String, Any>>()
    }
    private var remote: BluetoothRemote? = null
    private var systemControls: SystemControls? = null
    private var shareChannel: MethodChannel? = null
    private val shareExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        receiveShare(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShare(intent)
    }
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? = SystemControls.engine
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xr/bluetooth_remote")
        remote = BluetoothRemote(this, channel).also { channel.setMethodCallHandler(it) }
        SystemControls.engine = flutterEngine
        systemControls = SystemControls(this, flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xr/share").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeInitialShare" -> {
                        shareReady = true
                        result.success(pendingShares.toList())
                        pendingShares.clear()
                    }
                    "saveToDownloads" -> saveToDownloads(call.argument<String>("path")!!, call.argument<String>("name")!!, result)
                    "openDownload" -> {
                        val uri = Uri.parse(call.argument<String>("uri")!!)
                        val view = Intent(Intent.ACTION_VIEW).setDataAndType(uri, contentResolver.getType(uri))
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        try {
                            startActivity(Intent.createChooser(view, null))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun receiveShare(intent: Intent?) {
        val uris: List<Uri> = when (intent?.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
            else -> emptyList()
        }
        if (uris.isEmpty()) return
        shareExecutor.execute {
            val copied = mutableListOf<Map<String, Any>>()
            val directory = File(cacheDir, "shared").apply { mkdirs() }
            for (uri in uris) {
                try {
                    var name = "shared-file"
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0)
                    }
                    name = name.substringAfterLast('/').substringAfterLast('\\').takeIf { it.isNotBlank() && it != "." && it != ".." } ?: "shared-file"
                    val dot = name.lastIndexOf('.')
                    val stem = if (dot > 0) name.substring(0, dot) else name
                    val extension = if (dot > 0) name.substring(dot) else ""
                    var file = File(directory, name)
                    var index = 2
                    while (file.exists()) file = File(directory, "$stem (${index++})$extension")
                    val input = contentResolver.openInputStream(uri) ?: continue
                    input.use { source -> file.outputStream().use { source.copyTo(it) } }
                    copied.add(mapOf("path" to file.absolutePath, "name" to name, "size" to file.length()))
                } catch (_: Exception) { }
            }
            if (copied.isNotEmpty()) mainHandler.post {
                if (shareReady) shareChannel?.invokeMethod("sharedFiles", copied) else pendingShares.addAll(copied)
            }
        }
    }
    /** Moves a downloaded file into Downloads/Xiaomi Remote; returns its content URI, or null before Android 10. */
    private fun saveToDownloads(path: String, name: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) return result.success(null)
        shareExecutor.execute {
            try {
                val source = File(path)
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/Xiaomi Remote")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)!!
                try {
                    contentResolver.openOutputStream(uri)!!.use { out -> source.inputStream().use { it.copyTo(out) } }
                    contentResolver.update(uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
                } catch (e: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw e
                }
                source.delete()
                mainHandler.post { result.success(uri.toString()) }
            } catch (e: Exception) {
                mainHandler.post { result.error("save", e.message, null) }
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        remote?.onRequestPermissionsResult(requestCode)
        systemControls?.onRequestPermissionsResult(requestCode)
    }
    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        remote?.onActivityResult(requestCode, resultCode)
    }
    override fun onDestroy() {
        shareChannel?.setMethodCallHandler(null)
        shareExecutor.shutdown()
        remote?.dispose()
        systemControls?.dispose()
        super.onDestroy()
    }
}
