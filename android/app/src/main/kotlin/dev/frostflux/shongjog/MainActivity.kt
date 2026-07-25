package dev.frostflux.shongjog

import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL = "com.example.shongjog/sms"
    private val AUDIO_CHANNEL = "com.example.shongjog/audio_track"

    private lateinit var audioPlugin: AudioTrackPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendSms") {
                    val to = call.argument<String>("to") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    try {
                        val smsManager = SmsManager.getDefault()
                        smsManager.sendTextMessage(to, null, body, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        audioPlugin = AudioTrackPlugin(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler(audioPlugin)
    }

    override fun onDestroy() {
        audioPlugin.dispose()
        super.onDestroy()
    }
}
