package dev.dropwatch.dropwatch

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val pickImage = 3021

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.dropwatch/mobile")
            .setMethodCallHandler { call, reply ->
                when (call.method) {
                    "directory" -> reply.success(filesDir.absolutePath)
                    "hubRead", "hubWrite", "hubPortal" -> try {
                        when (call.method) {
                            "hubRead" -> reply.success(HubKey(this).read())
                            "hubWrite" -> { HubKey(this).save(requireNotNull(call.argument<String>("value"))); reply.success(null) }
                            "hubPortal" -> {
                                val path = when (call.argument<String>("page")) {
                                    "keys" -> "/mypage/developers"
                                    "link" -> "/mypage"
                                    else -> "/developers/docs"
                                }
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://valoranttracker.com" + path)))
                                reply.success(null)
                            }
                        }
                    } catch (e: Exception) { reply.error("hub", "Operasi perangkat gagal.", null) }
                    "pick" -> {
                        if (pending != null) {
                            reply.error("busy", "Pemilih gambar masih terbuka.", null)
                        } else {
                            pending = reply
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE).setType("image/*")
                            try {
                                startActivityForResult(intent, pickImage)
                            } catch (e: Exception) {
                                pending = null
                                reply.error("picker", "Pemilih gambar tidak tersedia.", null)
                            }
                        }
                    }
                    else -> reply.notImplemented()
                }
            }
    }

    @Deprecated("FlutterActivity forwards the Android activity result here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickImage) return
        val reply = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            reply.success(null)
            return
        }
        io.execute {
            val file = File.createTempFile("dropwatch-", ".img", cacheDir)
            try {
                require(uri.scheme == "content")
                val input = requireNotNull(contentResolver.openInputStream(uri))
                input.use { source ->
                    file.outputStream().use { sink ->
                        val buffer = ByteArray(32768)
                        var total = 0L
                        while (true) {
                            val n = source.read(buffer)
                            if (n < 0) break
                            total += n
                            require(total <= 24L * 1024 * 1024)
                            sink.write(buffer, 0, n)
                        }
                    }
                }
                val size = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(file.path, size)
                require(size.outWidth > 0 && size.outHeight > 0 &&
                    size.outWidth.toLong() * size.outHeight <= 20_000_000L)
                val image = InputImage.fromFilePath(this, Uri.fromFile(file))
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                recognizer.process(image)
                    .addOnSuccessListener { result ->
                        reply.success(mapOf("path" to file.path, "text" to result.text))
                    }
                    .addOnFailureListener {
                        reply.success(mapOf("path" to file.path, "text" to ""))
                    }
                    .addOnCompleteListener { recognizer.close() }
            } catch (e: Exception) {
                file.delete()
                runOnUiThread { reply.error("image", "Gunakan gambar JPG atau PNG hingga 24 MB dan 20 megapiksel.", null) }
            }
        }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }
}

