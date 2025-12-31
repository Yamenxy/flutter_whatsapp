package com.example.whatsapp_chat_ui

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
	private val CHANNEL = "whatsapp_chat_ui/recorder"
	private var mediaRecorder: MediaRecorder? = null
	private var mediaPlayer: MediaPlayer? = null
	private lateinit var methodChannel: MethodChannel
	private var outputFilePath: String? = null
	private var pendingResult: MethodChannel.Result? = null
	private var pendingStart = false
	private val REQUEST_RECORD_AUDIO_PERMISSION = 2001

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
		methodChannel.setMethodCallHandler { call, result ->
			when (call.method) {
				"startAudioRecord" -> {
					if (isRecording()) {
						result.error("ALREADY_RECORDING", "Already recording", null)
						return@setMethodCallHandler
					}
					if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
						// request permission and keep result to handle after grant
						pendingResult = result
						pendingStart = true
						ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO_PERMISSION)
						return@setMethodCallHandler
					}
					val started = startRecording()
					if (started) result.success("started") else result.error("START_FAILED", "Could not start recorder", null)
				}
				"stopAudioRecord" -> {
					if (!isRecording()) {
						result.error("NOT_RECORDING", "No active recording", null)
						return@setMethodCallHandler
					}
					val path = stopRecording()
					if (path != null) {
						val f = File(path)
						val size = if (f.exists()) f.length() else 0L
						val map: Map<String, Any> = mapOf("path" to path, "size" to size)
						Log.d("Recorder", "Stopped. path=$path size=$size")
						result.success(map)
					} else {
						Log.e("Recorder", "stopRecording returned null")
						result.error("STOP_FAILED", "Could not stop recorder", null)
					}
				}
				"listRecordings" -> {
					val dir = this.getExternalFilesDir(android.os.Environment.DIRECTORY_MUSIC) ?: this.filesDir
					val list = mutableListOf<Map<String, Any>>()
					dir?.listFiles()?.forEach { f ->
						if (f.isFile && (f.name.endsWith(".m4a") || f.name.contains("record_"))) {
							list.add(mapOf("path" to f.absolutePath, "size" to f.length(), "modified" to f.lastModified()))
						}
					}
					result.success(list)
				}
				"playAudio" -> {
					val path = call.argument<String>("path")
					if (path == null) {
						result.error("MISSING_PATH", "No path provided", null)
						return@setMethodCallHandler
					}
					val ok = playAudio(path)
					if (ok) result.success("playing") else result.error("PLAY_FAILED", "Could not play audio", null)
				}
				"stopAudio" -> {
					stopAudio()
					result.success("stopped")
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun playAudio(path: String): Boolean {
		try {
			stopAudio()
			mediaPlayer = MediaPlayer().apply {
				setDataSource(path)
				prepare()
				start()
				setOnCompletionListener {
					try {
						methodChannel.invokeMethod("playbackComplete", path)
					} catch (e: Exception) {
					}
					stopAudio()
				}
			}
			return true
		} catch (e: Exception) {
			Log.e("Recorder", "playAudio failed: ${e.message}")
			try {
				mediaPlayer?.release()
			} catch (_: Exception) {}
			mediaPlayer = null
			return false
		}
	}

	private fun stopAudio() {
		try {
			mediaPlayer?.apply {
				if (isPlaying) stop()
				reset()
				release()
			}
		} catch (_: Exception) {
		}
		mediaPlayer = null
	}

	private fun isRecording(): Boolean {
		return mediaRecorder != null
	}

	private fun startRecording(): Boolean {
		return try {
			val dir = this.getExternalFilesDir(Environment.DIRECTORY_MUSIC) ?: this.filesDir
			val file = File.createTempFile("record_", ".m4a", dir)
			outputFilePath = file.absolutePath

			mediaRecorder = MediaRecorder().apply {
				setAudioSource(MediaRecorder.AudioSource.MIC)
				setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
				setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
				setOutputFile(outputFilePath)
				prepare()
				start()
			}
			true
		} catch (e: IOException) {
			Log.e("Recorder", "startRecording failed: ${e.message}")
			mediaRecorder = null
			false
		}
	}

	private fun stopRecording(): String? {
		return try {
			mediaRecorder?.apply {
				stop()
				reset()
				release()
			}
			mediaRecorder = null
			val path = outputFilePath
			outputFilePath = null
			path
		} catch (e: Exception) {
			Log.e("Recorder", "stopRecording failed: ${e.message}")
			try {
				mediaRecorder?.release()
			} catch (_: Exception) {
			}
			mediaRecorder = null
			null
		}
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == REQUEST_RECORD_AUDIO_PERMISSION) {
			val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
			if (granted && pendingStart) {
				// start recording now
				val res = pendingResult
				pendingResult = null
				pendingStart = false
				val started = startRecording()
				if (started) res?.success("started") else res?.error("START_FAILED", "Could not start after permission", null)
			} else {
				pendingResult?.error("PERMISSION_DENIED", "Microphone permission denied", null)
				pendingResult = null
				pendingStart = false
			}
		}
	}
}
