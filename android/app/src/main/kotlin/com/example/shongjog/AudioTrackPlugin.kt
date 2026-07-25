package com.example.shongjog

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AudioTrackPlugin(private val activity: MainActivity) : MethodChannel.MethodCallHandler {

    private var audioTrack: AudioTrack? = null
    private var bufferSize: Int = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val sampleRate = call.argument<Int>("sampleRate") ?: 8000
                val numChannels = call.argument<Int>("numChannels") ?: 1
                startTrack(sampleRate, numChannels)
                result.success(null)
            }
            "feed" -> {
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    audioTrack?.write(data, 0, data.size)
                }
                result.success(null)
            }
            "stop" -> {
                stopTrack()
                result.success(null)
            }
            "setSpeaker" -> {
                val on = call.argument<Boolean>("on") ?: false
                val am = activity.getSystemService(AudioManager::class.java)
                @Suppress("DEPRECATION")
                am.isSpeakerphoneOn = on
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startTrack(sampleRate: Int, numChannels: Int) {
        stopTrack()
        val am = activity.getSystemService(AudioManager::class.java)
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        val channelConfig = if (numChannels == 1)
            AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        bufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, encoding)
        if (bufferSize < 1024) bufferSize = 1024

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        audioTrack?.play()
    }

    private fun stopTrack() {
        try {
            audioTrack?.stop()
        } catch (_: IllegalStateException) { }
        audioTrack?.release()
        audioTrack = null
        val am = activity.getSystemService(AudioManager::class.java)
        am.mode = AudioManager.MODE_NORMAL
    }

    fun dispose() {
        stopTrack()
    }
}
