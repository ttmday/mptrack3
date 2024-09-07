package github.com.ttmday.mptrack3
import com.ryanheise.audioservice.AudioServiceActivity;

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.MethodChannel
class MainActivity: AudioServiceActivity(){
    private val methodChannel: String = "media_changes"

    private lateinit var mediaObserver: ContentObserver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel).setMethodCallHandler { call, result ->
             if (call.method =="listen") {
                 startListeningForMediaChanges()
                result.success(null)
            } else {

                result.error("UNAVAILABLE", "No Found Method ${call.method}", null)
            }
        }

    }

    private fun startListeningForMediaChanges() {
        val handler = Handler(Looper.getMainLooper())

        mediaObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                uri?.let {
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val dataIndex = it.getColumnIndex(MediaStore.MediaColumns.DATA)
                            val filePath = it.getString(dataIndex)
                            notifyFlutter(filePath)
                        }
                    }
                }
            }
        }

        contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            true,
            mediaObserver
        )
    }

    private fun notifyFlutter(filePath: String) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { MethodChannel(it, methodChannel).invokeMethod("onMediaChanged", filePath) }
    }

    override fun onDestroy() {
        super.onDestroy()
        contentResolver.unregisterContentObserver(mediaObserver)
    }
}
