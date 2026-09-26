package com.example.amble

import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Observes the decor view without replacing FlutterView's own IME callback. */
class AndroidKeyboardAnimation(private val view: View, messenger: BinaryMessenger) {
    private val channel = EventChannel(messenger, "com.amble/keyboard_animation")
    private var sink: EventChannel.EventSink? = null
    private var targetInset = 0
    private var opening = false
    private var currentInset = 0
    private var activeDuration: Long? = null
    private var activeFraction = 0f

    init {
        channel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                sink = events
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val duration = activeDuration
                    if (duration != null) {
                        emit(activeFraction, duration)
                    } else {
                        targetInset = view.rootWindowInsets?.let { imeInset(it) } ?: 0
                        currentInset = targetInset
                        opening = targetInset > 0
                        emit(1f, 0)
                    }
                } else {
                    events.success(mapOf("unavailable" to true))
                }
            }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) install()
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private fun install() = view.setWindowInsetsAnimationCallback(KeyboardCallback())

    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private inner class KeyboardCallback : WindowInsetsAnimation.Callback(
        DISPATCH_MODE_CONTINUE_ON_SUBTREE
    ) {
            override fun onStart(animation: WindowInsetsAnimation,
                                 bounds: WindowInsetsAnimation.Bounds): WindowInsetsAnimation.Bounds {
                if (animation.typeMask and WindowInsets.Type.ime() != 0) {
                    opening = view.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) == true
                    targetInset = if (opening) normalizeInset(bounds.upperBound.bottom) else 0
                    activeDuration = animation.durationMillis.coerceAtLeast(0)
                    activeFraction = 0f
                    emit(0f, animation.durationMillis.coerceAtLeast(0))
                }
                return bounds
            }

            override fun onProgress(insets: WindowInsets,
                                    runningAnimations: MutableList<WindowInsetsAnimation>): WindowInsets {
                runningAnimations.firstOrNull { it.typeMask and WindowInsets.Type.ime() != 0 }
                    ?.let {
                        currentInset = imeInset(insets)
                        activeFraction = it.fraction
                        emit(it.fraction, it.durationMillis.coerceAtLeast(0))
                    }
                return insets
            }

            override fun onEnd(animation: WindowInsetsAnimation) {
                if (animation.typeMask and WindowInsets.Type.ime() != 0) {
                    currentInset = targetInset
                    activeDuration = null
                    emit(1f, animation.durationMillis.coerceAtLeast(0))
                }
            }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private fun imeInset(insets: WindowInsets): Int =
        normalizeInset(insets.getInsets(WindowInsets.Type.ime()).bottom)

    @Suppress("DEPRECATION")
    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private fun normalizeInset(inset: Int): Int {
        // Match FlutterView's pre-edge-to-edge exclusion of the navigation bar.
        val flags = view.systemUiVisibility
        val excludesNavigation = Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM &&
            flags and (View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION) == 0
        val navigation = if (excludesNavigation)
            view.rootWindowInsets?.getInsets(WindowInsets.Type.navigationBars())?.bottom ?: 0 else 0
        return (inset - navigation).coerceAtLeast(0)
    }

    private fun emit(fraction: Float, duration: Long) {
        sink?.success(mapOf(
            "inset" to currentInset / view.resources.displayMetrics.density.toDouble(),
            "fraction" to fraction.toDouble(),
            "durationMs" to duration,
            "opening" to opening
        ))
    }

    fun close() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) view.setWindowInsetsAnimationCallback(null)
        channel.setStreamHandler(null)
        sink = null
    }
}
