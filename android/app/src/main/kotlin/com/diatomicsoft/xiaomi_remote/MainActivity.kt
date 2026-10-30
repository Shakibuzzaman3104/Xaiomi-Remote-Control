package com.diatomicsoft.xiaomi_remote

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var remote: BluetoothRemote? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xr/bluetooth_remote")
        remote = BluetoothRemote(this, channel).also { channel.setMethodCallHandler(it) }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        remote?.onRequestPermissionsResult(requestCode)
    }
    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        remote?.onActivityResult(requestCode, resultCode)
    }
    override fun onDestroy() {
        remote?.dispose()
        super.onDestroy()
    }
}
