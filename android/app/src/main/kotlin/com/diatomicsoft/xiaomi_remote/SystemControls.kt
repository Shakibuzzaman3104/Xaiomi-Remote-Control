/**
 * @author Shakib
 * @since 30/10/26
 */
package com.diatomicsoft.xiaomi_remote

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.service.quicksettings.TileService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class SystemControls(activity: Activity, flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler {
    companion object {
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null
        var connected = false
        const val PERMISSION_REQUEST = 4103

        fun press(name: String): Boolean {
            val current = channel ?: return false
            current.invokeMethod("press", name)
            return true
        }
    }

    private var permissionResult: MethodChannel.Result? = null
    private val activityRef = WeakReference(activity)
    private val context = activity.applicationContext

    init {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xr/system_controls")
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                val activity = activityRef.get()
                if (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (activity == null) {
                    result.error("activity_destroyed", null, null)
                } else if (permissionResult != null) {
                    result.error("permission_pending", null, null)
                } else {
                    permissionResult = result
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                }
            }
            "setConnected" -> {
                val next = call.arguments == true
                if (connected != next) {
                    connected = next
                    if (Build.VERSION.SDK_INT >= 24) TileService.requestListeningState(context, ComponentName(context, RemoteTileService::class.java))
                }
                result.success(null)
            }
            "updateNotification" -> {
                val intent = Intent(context, SystemControlsService::class.java)
                    .putExtra("tvName", call.argument<String>("tvName") ?: "TV")
                    .putExtra("title", call.argument<String>("title"))
                    .putExtra("playing", call.argument<Boolean>("playing") ?: false)
                try {
                    when {
                        SystemControlsService.running -> SystemControlsService.refresh(context, intent)
                        Build.VERSION.SDK_INT >= 26 -> context.startForegroundService(intent)
                        else -> context.startService(intent)
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("service", e.message, null)
                }
            }
            "stopNotification" -> {
                context.stopService(Intent(context, SystemControlsService::class.java))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int) {
        if (requestCode != PERMISSION_REQUEST) return
        val pending = permissionResult ?: return
        permissionResult = null
        pending.success(Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
    }

    fun dispose() {
        permissionResult?.error("activity_destroyed", null, null)
        permissionResult = null
    }
}
