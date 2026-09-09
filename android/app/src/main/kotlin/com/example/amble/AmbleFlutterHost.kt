package com.example.amble

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One app-process engine and Hive cache, shared by assistant calls and UI. */
object AmbleFlutterHost {
    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    var foreground = false

    fun engine(context: Context): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper())
        engine?.let { return it }
        val created = FlutterEngine(context.applicationContext)
        engine = created
        channel = MethodChannel(created.dartExecutor.binaryMessenger, "com.amble/app_intents")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> { ready = true; result.success(null) }
                "isForeground" -> result.success(foreground)
                else -> result.notImplemented()
            }
        }
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    /** Timeouts never retry a write whose reply may have been lost. */
    fun request(context: Context, method: String, arguments: Map<String, Any>,
                callback: (Result<Any>) -> Unit) {
        handler.post {
            try {
                engine(context)
            } catch (error: Exception) {
                callback(Result.failure(error))
                return@post
            }
            val deadline = SystemClock.elapsedRealtime() + 15_000
            val waitForReady = object : Runnable {
                override fun run() {
                    if (ready) {
                        dispatch(method, arguments, callback)
                    } else if (SystemClock.elapsedRealtime() >= deadline) {
                        callback(Result.failure(IllegalStateException(
                            "Amble is not ready. Open the app and try again.")))
                    } else {
                        handler.postDelayed(this, 50)
                    }
                }
            }
            waitForReady.run()
        }
    }

    private fun dispatch(method: String, arguments: Map<String, Any>,
                         callback: (Result<Any>) -> Unit) {
        var finished = false
        fun finish(result: Result<Any>) {
            if (finished) return
            finished = true
            callback(result)
        }
        val timeout = Runnable {
            finish(Result.failure(IllegalStateException(
                "Amble could not confirm completion. Check the app before trying again.")))
        }
        handler.postDelayed(timeout, 25_000)
        channel!!.invokeMethod(method, arguments, object : MethodChannel.Result {
            override fun success(result: Any?) {
                handler.removeCallbacks(timeout)
                if (result == null) notImplemented() else finish(Result.success(result))
            }
            override fun error(code: String, message: String?, details: Any?) {
                handler.removeCallbacks(timeout)
                finish(Result.failure(IllegalArgumentException(message ?: "Amble action failed.")))
            }
            override fun notImplemented() {
                handler.removeCallbacks(timeout)
                finish(Result.failure(IllegalStateException("This Amble action is unavailable.")))
            }
        })
    }
}
