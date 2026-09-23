package com.example.amble

import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.os.Bundle

// FlutterFragmentActivity, not FlutterActivity — required by
// purchases_ui_flutter's native paywall/Customer Center views, which are
// built on Android Fragments internally. Without this, presenting either
// throws PlatformException(PAYWALLS_MISSING_WRONG_ACTIVITY). See
// docs/DECISIONS.md's RevenueCat integration entry.
class MainActivity : FlutterFragmentActivity() {
    private lateinit var assistant: AssistantActions

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        assistant = AssistantActions(this)
        if (savedInstanceState == null) assistant.handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        assistant.handle(intent)
    }

    override fun onDestroy() {
        assistant.close()
        super.onDestroy()
    }
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        AmbleFlutterHost.engine(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        AmbleFlutterHost.foreground = true
    }

    override fun onPause() {
        AmbleFlutterHost.foreground = false
        super.onPause()
    }
}
