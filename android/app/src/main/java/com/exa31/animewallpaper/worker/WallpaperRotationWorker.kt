package com.exa31.animewallpaper.worker

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.exa31.animewallpaper.data.api.WallhavenClient
import com.exa31.animewallpaper.data.model.UserPreferences
import com.exa31.animewallpaper.data.model.WallpaperTarget
import com.exa31.animewallpaper.service.WallpaperHelper
import java.util.concurrent.TimeUnit

class WallpaperRotationWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        Log.d(TAG, "Executing background wallpaper rotation worker...")

        // Read user preferences
        val sharedPrefs = context.getSharedPreferences("anime_prefs", Context.MODE_PRIVATE)
        val query = sharedPrefs.getString("query", "anime") ?: "anime"
        val sfwOnly = sharedPrefs.getBoolean("sfwOnly", true)
        val apiKey = sharedPrefs.getString("apiKey", "") ?: ""
        val targetName = sharedPrefs.getString("target", WallpaperTarget.BOTH.name) ?: WallpaperTarget.BOTH.name
        val target = try { WallpaperTarget.valueOf(targetName) } catch (_: Exception) { WallpaperTarget.BOTH }

        val prefs = UserPreferences(
            query = query,
            sfwOnly = sfwOnly,
            apiKey = apiKey,
            target = target
        )

        val wallpapers = WallhavenClient.searchWallpapers(prefs)
        if (wallpapers.isEmpty()) {
            Log.w(TAG, "No wallpapers retrieved during background worker run.")
            return Result.retry()
        }

        val selected = wallpapers.random()
        val success = WallpaperHelper.applyWallpaper(context, selected.path, target)

        if (success) {
            WallpaperHelper.pruneCache(context, 15)
            Log.i(TAG, "Background wallpaper rotation succeeded: ${selected.id}")
            return Result.success()
        }

        return Result.retry()
    }

    companion object {
        private const val TAG = "WallpaperWorker"
        const val WORK_NAME = "anime_wallpaper_rotation_work"

        fun schedulePeriodicWork(
            context: Context,
            intervalMinutes: Long,
            wifiOnly: Boolean
        ) {
            // WorkManager minimum periodic interval is 15 minutes
            val safeInterval = intervalMinutes.coerceAtLeast(15)

            val constraints = Constraints.Builder()
                .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<WallpaperRotationWorker>(
                safeInterval,
                TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                workRequest
            )

            Log.i(TAG, "Scheduled periodic wallpaper rotation every $safeInterval minutes (Wi-Fi only: $wifiOnly)")
        }

        fun cancelWork(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.i(TAG, "Cancelled periodic wallpaper rotation work.")
        }
    }
}
