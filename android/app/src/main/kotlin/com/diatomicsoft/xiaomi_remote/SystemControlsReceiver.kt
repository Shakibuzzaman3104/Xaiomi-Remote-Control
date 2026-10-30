/**
 * @author Shakib
 * @since 30/10/26
 */
package com.diatomicsoft.xiaomi_remote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SystemControlsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val action = intent.action) {
            "volumeDown", "playPause", "volumeUp", "mute" -> SystemControls.press(action)
            "stop" -> {
                context.stopService(Intent(context, SystemControlsService::class.java))
                SystemControls.channel?.invokeMethod("stopped", null)
            }
        }
    }
}
