package com.example.amble

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterActivity() {
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
