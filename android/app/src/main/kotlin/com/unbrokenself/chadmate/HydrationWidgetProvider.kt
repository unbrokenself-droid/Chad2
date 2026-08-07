package com.unbrokenself.chadmate

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget for hydration check-in.
 *
 * Reads its display data from "HomeWidgetPreferences" — the same
 * SharedPreferences file the `home_widget` Flutter package reads and
 * writes on the Dart side (see HomeWidgetSyncService) — rather than
 * calling into that package's own Kotlin API. This class only needs
 * to know its one stable storage convention (file name
 * "HomeWidgetPreferences", string-keyed values), which keeps it
 * decoupled from that package's exact native API surface.
 *
 * The "+ Log a Glass" tap is handled entirely here, not by waking the
 * Flutter engine: it increments a pending-count value directly in
 * that same SharedPreferences file and redraws immediately, so the
 * widget stays responsive even if the app hasn't been opened in a
 * while. HomeWidgetSyncService is what folds that pending count into
 * the real HydrationService data the next time the app itself is
 * opened, and clears it back to zero once it has — see that class's
 * doc comment for the full reconciliation flow.
 */
class HydrationWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        const val ACTION_ADD_GLASS = "com.unbrokenself.chadmate.ACTION_ADD_GLASS"

        // Keys HomeWidgetSyncService writes with fresh data from
        // HydrationService; read (never written) here.
        private const val KEY_TOTAL_GLASSES = "hydration_widget_total_glasses"
        private const val KEY_FILLED_GLASSES = "hydration_widget_filled_glasses"

        // Key this provider owns: glasses logged by a widget tap that
        // HomeWidgetSyncService hasn't reconciled into the real app
        // data yet. Always added on top of KEY_FILLED_GLASSES for
        // display, and reset to 0 by HomeWidgetSyncService once it
        // has folded it in.
        private const val KEY_PENDING_GLASSES = "hydration_widget_pending_glasses"

        /**
         * Rebuilds and pushes fresh [RemoteViews] to every placed
         * instance of this widget. Called from [onUpdate] (the
         * system-triggered path) and directly after a tap updates the
         * pending count (so the display reflects a tap immediately,
         * without waiting on the next system-triggered update).
         */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, HydrationWidgetProvider::class.java)
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildRemoteViews(context))
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val total = prefs.getInt(KEY_TOTAL_GLASSES, 8)
            val filledFromApp = prefs.getInt(KEY_FILLED_GLASSES, 0)
            val pending = prefs.getInt(KEY_PENDING_GLASSES, 0)
            val filled = (filledFromApp + pending).coerceAtMost(total)

            val views = RemoteViews(context.packageName, R.layout.hydration_widget)
            views.setTextViewText(
                R.id.hydration_widget_summary,
                "$filled of $total glasses"
            )
            val progressPercent = if (total > 0) (filled * 100) / total else 0
            views.setProgressBar(
                R.id.hydration_widget_progress,
                /* max = */ 100,
                /* progress = */ progressPercent,
                /* indeterminate = */ false
            )

            val tapIntent = Intent(context, HydrationWidgetProvider::class.java).apply {
                action = ACTION_ADD_GLASS
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                /* requestCode = */ 0,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.hydration_widget_add_button, pendingIntent)

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
        // Always let the base class handle the standard AppWidget
        // lifecycle actions first (APPWIDGET_UPDATE and friends,
        // which is what actually invokes onUpdate above) — it simply
        // won't recognize ACTION_ADD_GLASS below, so calling it
        // unconditionally is safe.
        super.onReceive(context, intent)
        if (intent.action == ACTION_ADD_GLASS) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = prefs.getInt(KEY_PENDING_GLASSES, 0)
            prefs.edit().putInt(KEY_PENDING_GLASSES, current + 1).apply()
            updateAll(context)
        }
    }
}
