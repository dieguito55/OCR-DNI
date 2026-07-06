package com.xiomi.xiomi

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class NativeOcr(private val context: Context) {
    companion object {
        init {
            System.loadLibrary("xiomi_ocr")
        }
    }

    private external fun nativeInit(
        detModelPath: String,
        clsModelPath: String,
        recModelPath: String,
        configPath: String,
        labelPath: String,
        cpuThreadNum: Int,
        cpuPowerMode: String
    ): Long

    private external fun nativeProcessImage(
        ctx: Long,
        imagePath: String,
        visualizedPath: String
    ): String

    private external fun nativePrepareImageVariants(
        ctx: Long,
        imagePath: String,
        outputDir: String
    ): String

    private external fun nativeRelease(ctx: Long): Boolean

    private var ctx: Long = 0

    @Synchronized
    fun processDniImage(imagePath: String): Map<String, Any?> {
        ensureInitialized()
        val visualizedPath = File(context.filesDir, "ocr_visualized_${System.currentTimeMillis()}.jpg").absolutePath
        val raw = nativeProcessImage(ctx, imagePath, visualizedPath)
        val json = JSONObject(raw)
        val nativeText = json.optString("text")
        val mlKitRuns = recognizeBestTextLayers(imagePath)
        val mlKitText = mlKitRuns.firstOrNull()?.text.orEmpty()
        val selectedMlKitTexts = mlKitRuns
            .filterIndexed { index, layer ->
                index < 3 ||
                    layer.name.contains("field", ignoreCase = true) ||
                    layer.name.contains("name", ignoreCase = true) ||
                    layer.name.contains("mrz", ignoreCase = true)
            }
            .map { it.text }
        val fullText = (selectedMlKitTexts + nativeText)
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString("\n")
        Log.i("XiomiOcr", "image=$imagePath")
        Log.i("XiomiOcr", "boxes=${json.optInt("boxes")} elapsedMs=${json.optDouble("elapsedMs")}")
        Log.i("XiomiOcr", "text=$fullText")
        Log.i("XiomiOcr", "raw=$raw")
        val bestVisualizedPath = json.optString("visualizedPath", visualizedPath)
        return mapOf(
            "text" to fullText,
            "mlkitText" to mlKitText,
            "mlkitLayersJson" to JSONArray(
                mlKitRuns.map {
                    JSONObject()
                        .put("name", it.name)
                        .put("path", it.path)
                        .put("score", it.score)
                        .put("length", it.text.length)
                        .put("text", it.text)
                }
            ).toString(),
            "nativeText" to nativeText,
            "raw" to raw,
            "boxes" to json.optInt("boxes"),
            "boxPointsJson" to (json.optJSONArray("boxPoints")?.toString() ?: "[]"),
            "elapsedMs" to json.optDouble("elapsedMs"),
            "visualizedPath" to bestVisualizedPath.ifBlank { visualizedPath },
            "bestVariant" to json.optString("bestVariant"),
            "engine" to "mlkit_latin_bundled+paddle_lite_ppocrv2_slim"
        )
    }

    @Synchronized
    fun release() {
        if (ctx != 0L) {
            nativeRelease(ctx)
            ctx = 0
        }
    }

    private fun ensureInitialized() {
        if (ctx != 0L) return

        val root = File(context.filesDir, "ocr_models")
        val det = copyAsset("assets/ocr_models/models/ch_PP-OCRv2_det_slim_opt.nb", root)
        val cls = copyAsset("assets/ocr_models/models/ch_ppocr_mobile_v2.0_cls_slim_opt.nb", root)
        val rec = copyAsset("assets/ocr_models/models/ch_PP-OCRv2_rec_slim_opt.nb", root)
        val config = copyAsset("assets/ocr_models/config.txt", root)
        val label = copyAsset("assets/ocr_models/labels/ppocr_keys_v1.txt", root)

        ctx = nativeInit(
            det.absolutePath,
            cls.absolutePath,
            rec.absolutePath,
            config.absolutePath,
            label.absolutePath,
            2,
            "LITE_POWER_HIGH"
        )
        if (ctx == 0L) {
            error("No se pudo inicializar PaddleOCR offline")
        }
    }

    private fun copyAsset(assetPath: String, root: File): File {
        val flutterAssetPath = "flutter_assets/$assetPath"
        val encodedFlutterAssetPath = "flutter_assets/${assetPath.replace(" ", "%20")}"
        val target = File(root, assetPath.substringAfterLast('/'))
        if (target.exists() && target.length() > 0) return target

        root.mkdirs()
        val inputStream = runCatching { context.assets.open(flutterAssetPath) }
            .getOrElse { context.assets.open(encodedFlutterAssetPath) }
        inputStream.use { input ->
            target.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return target
    }

    private fun recognizeTextWithMlKit(imagePath: String): String {
        val image = InputImage.fromFilePath(context, Uri.fromFile(File(imagePath)))
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val latch = CountDownLatch(1)
        var text = ""
        var failure: Throwable? = null
        recognizer.process(image)
            .addOnSuccessListener { result ->
                text = result.text
                latch.countDown()
            }
            .addOnFailureListener { error ->
                failure = error
                latch.countDown()
            }
        latch.await(20, TimeUnit.SECONDS)
        recognizer.close()
        failure?.let { Log.w("XiomiOcr", "ML Kit no pudo leer texto", it) }
        return text
    }

    private fun recognizeBestTextLayers(imagePath: String): List<TextLayerResult> {
        val variantsRoot = File(context.cacheDir, "ocr_mlkit_variants/${System.currentTimeMillis()}")
        variantsRoot.mkdirs()
        val exported = runCatching {
            JSONObject(nativePrepareImageVariants(ctx, imagePath, variantsRoot.absolutePath))
        }.getOrElse {
            Log.w("XiomiOcr", "No se pudieron preparar capas OCR", it)
            JSONObject().put("variants", JSONArray())
        }

        val layers = mutableListOf<Pair<String, String>>()
        layers.add("original" to imagePath)
        val variants = exported.optJSONArray("variants") ?: JSONArray()
        for (index in 0 until variants.length()) {
            val item = variants.optJSONObject(index) ?: continue
            if (!item.optBoolean("ok", false)) continue
            val path = item.optString("path")
            if (path.isBlank()) continue
            layers.add(item.optString("name", "layer_$index") to path)
        }

        val runs = layers.map { (name, path) ->
            val text = recognizeTextWithMlKit(path)
            TextLayerResult(
                name = name,
                path = path,
                text = text,
                score = scoreDniTextLayer(text, name)
            )
        }.sortedWith(
            compareByDescending<TextLayerResult> { it.score }
                .thenByDescending { it.text.length }
        )

        Log.i(
            "XiomiOcr",
            "mlkitLayers=${runs.joinToString { "${it.name}:${it.score}" }}"
        )
        return runs
    }

    private fun scoreDniTextLayer(text: String, name: String): Int {
        val upper = text.uppercase()
        var score = 0
        if (upper.contains("<<")) score += 45
        if (Regex("[A-ZÑ]{3,}<<[A-ZÑ<]{3,}").containsMatchIn(upper)) score += 55
        if (Regex("(?:I|1)<PER[0-9]{8}").containsMatchIn(upper)) score += 45
        if (Regex("[0-9]{6}[0-9A-Z]?[MF]").containsMatchIn(upper)) score += 35
        if (Regex("\\b[0-9]{8}\\b").containsMatchIn(upper)) score += 20
        if (upper.contains("PRIMER") || upper.contains("APELLIDO")) score += 10
        if (upper.contains("NOMBRES") || upper.contains("NOMBRE")) score += 10
        if (upper.contains("NACIMIENTO") || upper.contains("UBIGEO")) score += 10
        if (name.contains("mrz", ignoreCase = true)) score += 20
        if (name.contains("crop", ignoreCase = true)) score += 8
        if (name.contains("deskew", ignoreCase = true)) score += 6
        if (upper.length in 40..500) score += 8
        if (Regex("[一-龥]").containsMatchIn(upper)) score -= 30
        return score
    }

    private data class TextLayerResult(
        val name: String,
        val path: String,
        val text: String,
        val score: Int
    )
}
