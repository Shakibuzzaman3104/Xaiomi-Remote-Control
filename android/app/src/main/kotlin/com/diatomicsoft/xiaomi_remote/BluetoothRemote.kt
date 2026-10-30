/**
 * @author Shakib
 * @since 30/10/26
 */
package com.diatomicsoft.xiaomi_remote

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BluetoothRemote(private val activity: Activity, private val channel: MethodChannel) : MethodChannel.MethodCallHandler {
    private val handler = Handler(Looper.getMainLooper())
    private val prefs = activity.getSharedPreferences("xr_bt", 0)
    private val adapter = (activity.getSystemService(Activity.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private var hid: BluetoothHidDevice? = null
    private var profileRequested = false
    private var registered = false
    private var registering = false
    private var connected: BluetoothDevice? = null
    private var permissionResult: MethodChannel.Result? = null
    private var pairingResult: MethodChannel.Result? = null
    private var pending: ((Boolean) -> Unit)? = null
    private var pendingRegistration = false
    private var timeout: Runnable? = null
    private var disposed = false

    // Keyboard, consumer control, and system-control reports.
    private val descriptor = intArrayOf(
        0x05,0x01,0x09,0x06,0xA1,0x01,0x85,0x01,
        0x05,0x07,0x19,0xE0,0x29,0xE7,0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x08,0x81,0x02,
        0x95,0x01,0x75,0x08,0x81,0x01,
        0x95,0x06,0x75,0x08,0x15,0x00,0x25,0x65,0x05,0x07,0x19,0x00,0x29,0x65,0x81,0x00,0xC0,
        0x05,0x0C,0x09,0x01,0xA1,0x01,0x85,0x02,
        0x15,0x00,0x26,0xFF,0x03,0x19,0x00,0x2A,0xFF,0x03,0x75,0x10,0x95,0x01,0x81,0x00,0xC0,
        0x05,0x01,0x09,0x80,0xA1,0x01,0x85,0x03,
        0x15,0x00,0x25,0x01,0x19,0x81,0x29,0x83,0x75,0x01,0x95,0x03,0x81,0x02,
        0x75,0x05,0x95,0x01,0x81,0x01,0xC0
    ).map { it.toByte() }.toByteArray()

    private val listener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            if (disposed) {
                try { adapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, proxy) } catch (_: SecurityException) { }
                return
            }
            hid = proxy as BluetoothHidDevice
            emitState()
            try { if (pending != null && !registered && !registering) register() }
            catch (_: SecurityException) { finishPending(false) }
        }
        override fun onServiceDisconnected(profile: Int) {
            hid = null
            registered = false
            registering = false
            connected = null
            emitState()
            finishPending(false)
        }
    }
    private val callback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, isRegistered: Boolean) {
            registered = isRegistered
            registering = false
            emitState()
            if (pending != null && pendingRegistration) finishPending(isRegistered)
        }
        override fun onConnectionStateChanged(device: BluetoothDevice, state: Int) {
            try {
                if (state == BluetoothProfile.STATE_CONNECTED) {
                    connected = device
                    if (device.bondState == BluetoothDevice.BOND_BONDED && prefs.getString("address", null) == null) {
                        prefs.edit().putString("address", device.address).putString("name", device.name ?: "TV").apply()
                    }
                    emitState()
                    if (pending != null && !pendingRegistration && prefs.getString("address", null) == device.address) finishPending(true)
                } else if (state == BluetoothProfile.STATE_DISCONNECTED) {
                    if (connected?.address == device.address) connected = null
                    emitState()
                }
            } catch (_: SecurityException) { finishPending(false) }
        }
    }
    private fun hasPermission(): Boolean = Build.VERSION.SDK_INT < 31 ||
        (ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
         ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED)
    private fun requestProfile(): Boolean {
        if (Build.VERSION.SDK_INT < 28 || adapter == null) return false
        if (profileRequested) return true
        profileRequested = adapter.getProfileProxy(activity, listener, BluetoothProfile.HID_DEVICE)
        return profileRequested
    }
    private fun state(): Map<String, Any?> = mapOf(
        "supported" to (Build.VERSION.SDK_INT >= 28 && adapter != null && profileRequested),
        "permissionGranted" to hasPermission(), "registered" to registered,
        "hostName" to prefs.getString("name", null), "hostAddress" to prefs.getString("address", null),
        "connected" to (connected != null && connected?.address == prefs.getString("address", null))
    )
    private fun emitState() {
        if (!disposed) {
            try { channel.invokeMethod("onState", state()) } catch (_: SecurityException) { }
        }
    }
    private fun finishPending(success: Boolean) {
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        val action = pending
        pending = null
        action?.invoke(success)
    }
    private fun waitFor(action: (Boolean) -> Unit) {
        pending = action
        val task = Runnable { finishPending(false) }
        timeout = task
        handler.postDelayed(task, 8000)
    }
    private fun register() {
        val proxy = hid ?: return
        val settings = BluetoothHidDeviceAppSdpSettings("Xiaomi Remote", "Phone remote", "Diatomic Soft", BluetoothHidDevice.SUBCLASS1_COMBO, descriptor)
        registering = true
        if (!proxy.registerApp(settings, null, null, activity.mainExecutor, callback)) {
            registering = false
            finishPending(false)
        }
    }
    private fun ensureRegistered(result: MethodChannel.Result, action: () -> Unit) {
        if (!hasPermission()) { result.error("permission", null, null); return }
        if (!requestProfile()) { result.error("unsupported", null, null); return }
        if (pending != null) { result.error("timeout", null, null); return }
        if (registered) { action(); return }
        pendingRegistration = true
        waitFor { ok ->
            if (!ok) result.error("timeout", null, null)
            else try { action() }
            catch (_: SecurityException) { result.error("permission", null, null) }
            catch (_: IllegalArgumentException) { result.error("not_paired", null, null) }
        }
        if (hid != null && !registering) register()
    }
    private fun sendReport(id: Int, data: ByteArray): Boolean {
        val device = connected ?: return false
        val proxy = hid ?: return false
        return proxy.sendReport(device, id, data)
    }
    private fun press(id: Int, data: ByteArray): Boolean {
        val sent = sendReport(id, data)
        val released = sendReport(id, ByteArray(data.size))
        return sent && released
    }
    private fun consumer(usage: Int) = press(2, byteArrayOf((usage and 0xff).toByte(), (usage shr 8).toByte()))
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(requestProfile())
                "getState" -> { requestProfile(); result.success(state()) }
                "requestPermission" -> {
                    if (hasPermission()) result.success(true)
                    else if (permissionResult != null) result.error("permission", null, null)
                    else {
                        permissionResult = result
                        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_ADVERTISE), 4101)
                    }
                }
                "startPairing" -> ensureRegistered(result) {
                    if (pairingResult != null) result.error("timeout", null, null)
                    else {
                        pairingResult = result
                        try {
                            activity.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 120), 4102)
                        } catch (e: Exception) {
                            pairingResult = null
                            result.error(if (e is SecurityException) "permission" else "unsupported", null, null)
                        }
                    }
                }
                "wake" -> ensureRegistered(result) {
                    val address = prefs.getString("address", null)
                    if (address == null) result.error("not_paired", null, null)
                    else {
                        val wake = {
                            try {
                                val sent = press(3, byteArrayOf(4))
                                handler.postDelayed({
                                    try { result.success(consumer(0x223) && sent) }
                                    catch (_: SecurityException) { result.error("permission", null, null) }
                                }, 300)
                            } catch (_: SecurityException) { result.error("permission", null, null) }
                        }
                        if (connected?.address == address) wake()
                        else {
                            val device = adapter!!.getRemoteDevice(address)
                            pendingRegistration = false
                            waitFor { ok -> if (ok) wake() else result.error("timeout", null, null) }
                            try {
                                if (hid?.connect(device) != true) finishPending(false)
                            } catch (_: SecurityException) {
                                timeout?.let { handler.removeCallbacks(it) }
                                pending = null
                                result.error("permission", null, null)
                            }
                        }
                    }
                }
                "sendKey" -> {
                    if (!hasPermission()) result.error("permission", null, null)
                    else if (connected?.address != prefs.getString("address", null) || connected == null) result.error("not_paired", null, null)
                    else {
                        val key = call.argument<String>("name")
                        val keyboard = mapOf("up" to 0x52, "down" to 0x51, "left" to 0x50, "right" to 0x4f, "ok" to 0x28)
                        val consumerKeys = mapOf("back" to 0x224, "home" to 0x223, "volumeUp" to 0xe9, "volumeDown" to 0xea, "mute" to 0xe2, "playPause" to 0xcd, "power" to 0x30)
                        val code = keyboard[key]
                        result.success(if (code != null) press(1, byteArrayOf(0, 0, code.toByte(), 0, 0, 0, 0, 0)) else consumerKeys[key]?.let { consumer(it) } ?: false)
                    }
                }
                "forget" -> {
                    prefs.edit().clear().apply()
                    finishPending(false)
                    hid?.unregisterApp()
                    registered = false
                    connected = null
                    emitState()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (_: SecurityException) {
            timeout?.let { handler.removeCallbacks(it) }
            pending = null
            permissionResult = null
            result.error("permission", null, null)
        } catch (_: IllegalArgumentException) {
            timeout?.let { handler.removeCallbacks(it) }
            pending = null
            result.error("not_paired", null, null)
        }
    }
    fun onRequestPermissionsResult(requestCode: Int) {
        if (requestCode != 4101) return
        val result = permissionResult ?: return
        permissionResult = null
        result.success(hasPermission())
        emitState()
    }
    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != 4102) return
        val result = pairingResult ?: return
        pairingResult = null
        result.success(resultCode > 0)
    }
    fun dispose() {
        disposed = true
        finishPending(false)
        permissionResult?.error("unsupported", null, null)
        pairingResult?.error("unsupported", null, null)
        try {
            hid?.unregisterApp()
            hid?.let { adapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, it) }
        } catch (_: SecurityException) { }
        channel.setMethodCallHandler(null)
    }
}
