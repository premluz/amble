package com.example.amble

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.speech.tts.TextToSpeech
import android.widget.EditText
import android.widget.LinearLayout
import java.text.DateFormat
import java.util.Date

/** Native Android fulfillment UI; selection belongs to Amble, not Assistant. */
class AssistantDialogs(private val activity: Activity) {
    private var ready = false
    private var pendingSpeech: String? = null
    private val speech = TextToSpeech(activity) { status ->
        ready = status == TextToSpeech.SUCCESS
        pendingSpeech?.let { speak(it) }
    }

    fun message(text: String) {
        if (activity.isDestroyed || activity.isFinishing) return
        AlertDialog.Builder(activity).setTitle("Amble").setMessage(text)
            .setPositiveButton("OK", null).show()
        speak(text)
    }

    private fun speak(text: String) {
        if (!ready) { pendingSpeech = text; return }
        pendingSpeech = null
        // Use an installed offline voice; visual feedback remains if unavailable.
        val voice = speech.voices?.firstOrNull {
            !it.isNetworkConnectionRequired && it.locale.language == java.util.Locale.getDefault().language
        } ?: return
        speech.voice = voice
        speech.speak(text, TextToSpeech.QUEUE_FLUSH, null, "amble-assistant")
    }

    fun text(title: String, supplied: String?, done: (String?) -> Unit) {
        if (!supplied.isNullOrBlank()) { done(supplied); return }
        val input = EditText(activity).apply { hint = "Text" }
        AlertDialog.Builder(activity).setTitle(title).setView(input)
            .setPositiveButton("Continue") { _, _ -> done(input.text.toString()) }
            .setNegativeButton("Cancel") { _, _ -> done(null) }
            .setOnCancelListener { done(null) }.show()
    }

    fun zone(intent: Intent, done: (String?, String?, String?) -> Unit) {
        val title = intent.getStringExtra("title")
        val start = intent.getStringExtra("start")
        val end = intent.getStringExtra("end")
        if (!title.isNullOrBlank() && !start.isNullOrBlank() && !end.isNullOrBlank()) {
            done(title, start, end)
            return
        }
        val fields = listOf("Zone title" to title, "Start (HH:mm)" to start, "End (HH:mm)" to end)
            .map { (hintText, value) -> EditText(activity).apply { hint = hintText; setText(value) } }
        val layout = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            fields.forEach { addView(it) }
        }
        AlertDialog.Builder(activity).setTitle("Add zone").setView(layout)
            .setPositiveButton("Add") { _, _ ->
                done(fields[0].text.toString(), fields[1].text.toString(), fields[2].text.toString())
            }.setNegativeButton("Cancel") { _, _ -> done(null, null, null) }
            .setOnCancelListener { done(null, null, null) }.show()
    }

    fun chooseTask(tasks: List<Map<*, *>>, done: (Map<*, *>?) -> Unit) {
        val labels = tasks.map {
            val date = Date((it["scheduledAt"] as Number).toLong())
            "${it["title"]} — ${DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(date)}"
        }.toTypedArray()
        AlertDialog.Builder(activity).setTitle("Choose a task to remove")
            .setItems(labels) { _, index -> done(tasks[index]) }
            .setNegativeButton("Cancel") { _, _ -> done(null) }
            .setOnCancelListener { done(null) }.show()
    }

    fun close() { speech.stop(); speech.shutdown() }
}
