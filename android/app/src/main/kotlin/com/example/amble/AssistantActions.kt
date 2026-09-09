package com.example.amble

import android.app.Activity
import android.content.Intent
import java.time.LocalTime
import java.time.format.DateTimeParseException

/** App Actions opens this app; it does not provide Siri-style parameter dialogs. */
class AssistantActions(private val activity: Activity) {
    private val dialogsDelegate = lazy { AssistantDialogs(activity) }
    private val dialogs by dialogsDelegate
    private var busy = false

    fun handle(intent: Intent) {
        val action = intent.action?.removePrefix(PREFIX) ?: return
        if (intent.action != PREFIX + action || action !in ACTIONS) return
        // Consume before any async work so recreation/resume never replays a write.
        intent.action = Intent.ACTION_MAIN
        if (busy) {
            dialogs.message("Finish the current Amble action, then ask again.")
            return
        }
        busy = true
        when (action) {
            "ADD_TASK", "ADD_NOTE" -> {
                dialogs.text("Add ${if (action == "ADD_TASK") "task" else "note"}",
                    intent.getStringExtra("text")) { text ->
                    if (text == null) finish() else call(
                        if (action == "ADD_TASK") "addTask" else "addNote",
                        mapOf("text" to text)) { dialogs.message(it.toString()); finish() }
                }
            }
            "ADD_ZONE" -> dialogs.zone(intent) { title, start, end ->
                if (title == null) { finish(); return@zone }
                try {
                    val startMinutes = minutes(start!!)
                    val endMinutes = minutes(end!!).let { if (it == 0) 1440 else it }
                    call("addZone", mapOf("title" to title,
                        "startMinutes" to startMinutes, "endMinutes" to endMinutes)) {
                        dialogs.message(it.toString()); finish()
                    }
                } catch (_: DateTimeParseException) {
                    dialogs.message("Give unambiguous times in 24-hour HH:mm format.")
                    finish()
                }
            }
            "DAY_SUMMARY" -> call("daySummary", emptyMap()) {
                dialogs.message(it.toString()); finish()
            }
            "REMOVE_TASK" -> dialogs.text("Remove task", intent.getStringExtra("text")) {
                if (it == null) finish() else findForRemoval(it)
            }
        }
    }

    private fun findForRemoval(query: String) {
        call("findTasks", mapOf("query" to query)) { value ->
            val matches = (value as? List<*>)?.mapNotNull { it as? Map<*, *> }.orEmpty()
            if (matches.isEmpty()) {
                dialogs.message("No matching scheduled task in the next 14 days.")
                finish()
                return@call
            }
            // Always a deliberate selection, including a unique exact match.
            // An exported Activity is not proof that an assistant authorized deletion.
            dialogs.chooseTask(matches) { selected ->
                if (selected == null) { finish(); return@chooseTask }
                val args = mapOf("id" to selected["id"]!!,
                    "title" to selected["title"]!!,
                    "scheduledAt" to selected["scheduledAt"]!!)
                call("removeTask", args) { dialogs.message(it.toString()); finish() }
            }
        }
    }

    private fun call(method: String, args: Map<String, Any>, onSuccess: (Any) -> Unit) {
        AmbleFlutterHost.request(activity, method, args) { result ->
            if (activity.isDestroyed || activity.isFinishing) { finish(); return@request }
            result.fold(onSuccess, {
                dialogs.message(it.message ?: "Amble could not complete this action.")
                finish()
            })
        }
    }

    private fun minutes(value: String): Int {
        val time = LocalTime.parse(value.trim())
        if (time.second != 0 || time.nano != 0) throw DateTimeParseException(
            "Use whole minutes", value, 0)
        return time.hour * 60 + time.minute
    }

    private fun finish() { busy = false }
    fun close() { if (dialogsDelegate.isInitialized()) dialogs.close() }

    companion object {
        const val PREFIX = "com.example.amble.assistant."
        private val ACTIONS = setOf("ADD_TASK", "ADD_NOTE", "ADD_ZONE", "DAY_SUMMARY", "REMOVE_TASK")
    }
}
