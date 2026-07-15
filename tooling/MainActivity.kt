package PLACEHOLDER

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingText: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pocket_agent/process_text"
        )
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialText") {
                result.success(pendingText)
                pendingText = null
            } else {
                result.notImplemented()
            }
        }
        extractText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractText(intent)
        val t = pendingText
        if (t != null && channel != null) {
            channel?.invokeMethod("processText", t)
            pendingText = null
        }
    }

    private fun extractText(intent: Intent?) {
        if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
            val t = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            if (!t.isNullOrEmpty()) pendingText = t
        }
    }
}
