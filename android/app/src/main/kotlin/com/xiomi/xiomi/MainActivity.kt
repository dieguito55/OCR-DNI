package com.xiomi.xiomi

import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "xiomi/ocr"
    private val executor = Executors.newSingleThreadExecutor()
    private var ocr: NativeOcr? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideSystemNavigation()
    }

    override fun onResume() {
        super.onResume()
        hideSystemNavigation()
    }

    private fun hideSystemNavigation() {
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "processDniImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath.isNullOrBlank()) {
                        result.error("INVALID_IMAGE", "La ruta de imagen esta vacia.", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val engine = ocr ?: NativeOcr(applicationContext).also { ocr = it }
                            val response = engine.processDniImage(imagePath)
                            runOnUiThread { result.success(response) }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("OCR_FAILED", error.message ?: "Error ejecutando PaddleOCR offline", null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        ocr?.release()
        executor.shutdown()
        super.onDestroy()
    }
}
