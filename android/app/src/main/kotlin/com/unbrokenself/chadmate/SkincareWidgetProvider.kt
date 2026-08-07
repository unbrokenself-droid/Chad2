package com.unbrokenself.chadmate

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget for skincare check-in. Structurally mirrors
 * [HydrationWidgetProvider] — see that class's doc comment for the
 * shared reasoning (reads/writes "HomeWidgetPreferences" directly
 * rather than calling into the `home_widget` package's own Kotlin
 * API; a tap increments a pending count here, and
 * HomeWidgetSyncService reconciles it into the real app data the
 * next time the app is opened).
 *
 * The one real difference: *which* step a tap here checks off is
 * decided in HomeWidgetSyncService (Dart), not here — this provider
 * only ever increments a plain pending-count, the same shape as
 * hydration's pending glass count, and leaves picking "the next
 * incomplete step in today's relevant routine" to the Dart side,
 * where that decision can reuse SkincareService directly instead of
 * this class needing its own copy of step-ordering/routine-selection
 * logic.
 */
class SkincareWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        const val ACTION_CHECK_STEP = "com.unbrokenself.chadmate.ACTION_CHECK_STEP"

        // Keys HomeWidgetSyncService writes with fresh data from
        // SkincareService; read (never written) here.
        private const val KEY_ROUTINE_LABEL = "skincare_widget_routine_label"
        private const val KEY_TOTAL_STEPS = "skincare_widget_total_steps"
        private const val KEY_COMPLETED_STEPS = "skincare_widget_completed_steps"

        // Key this provider owns — see HydrationWidgetProvider's
        // identical KEY_PENDING_GLASSES for the full reasoning.
        private const val KEY_PENDING_STEPS = "skincare_widget_pending_steps"

        /** See [HydrationWidgetProvider.updateAll]'s doc comment —
         * identical reasoning, this widget's equivalent. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SkincareWidgetProvider::class.java)
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildRemoteViews(context))
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val routineLabel = prefs.getString(KEY_ROUTINE_LABEL, "Morning") ?: "Morning"
            val total = prefs.getInt(KEY_TOTAL_STEPS, 0)
            val completedFromApp = prefs.getInt(KEY_COMPLETED_STEPS, 0)
            val pending = prefs.getInt(KEY_PENDING_STEPS, 0)
            val completed = (completedFromApp + pending).coerceAtMost(total)

            val views = RemoteViews(context.packageName, R.layout.skincare_widget)
            views.setTextViewText(
                R.id.skincare_widget_summary,
                "$routineLabel \u00b7 $completed of $total"
            )
            val progressPercent = if (total > 0) (completed * 100) / total else 0
            views.setProgressBar(
                R.id.skincare_widget_progress,
                /* max = */ 100,
                /* progress = */ progressPercent,
                /* indeterminate = */ false
            )

            val tapIntent = Intent(context, SkincareWidgetProvider::class.java).apply {
                action = ACTION_CHECK_STEP
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                /* requestCode = */ 0,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.skincare_widget_check_button, pendingIntent)

            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildRemoteViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent) // See HydrationWidgetProvider's identical call.
        if (intent.action == ACTION_CHECK_STEP) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = prefs.getInt(KEY_PENDING_STEPS, 0)
            prefs.edit().putInt(KEY_PENDING_STEPS, current + 1).apply()
            updateAll(context)
        }
    }
}
