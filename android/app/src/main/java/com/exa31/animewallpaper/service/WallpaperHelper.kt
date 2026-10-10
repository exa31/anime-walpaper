package com.exa31.animewallpaper.service

import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import com.exa31.animewallpaper.data.model.WallpaperTarget
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.URL

object WallpaperHelper {
    private const val TAG = "WallpaperHelper"

    suspend fun applyWallpaper(
        context: Context,
        imageUrl: String,
        target: WallpaperTarget
    ): Boolean = withContext(Dispatchers.IO) {
        var inputStream: InputStream? = null
        try {
            Log.d(TAG, "Downloading full wallpaper to apply: $imageUrl")
            val url = URL(imageUrl)
            val connection = url.openConnection()
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            inputStream = connection.getInputStream()

            val bitmap = BitmapFactory.decodeStream(inputStream)
                ?: return@withContext false

            val wallpaperManager = WallpaperManager.getInstance(context)

            val flags = when (target) {
                WallpaperTarget.HOME_SCREEN -> WallpaperManager.FLAG_SYSTEM
                WallpaperTarget.LOCK_SCREEN -> WallpaperManager.FLAG_LOCK
                WallpaperTarget.BOTH -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                wallpaperManager.setBitmap(bitmap, null, true, flags)
            } else {
                wallpaperManager.setBitmap(bitmap)
            }

            Log.i(TAG, "Successfully applied wallpaper to $target")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error applying wallpaper", e)
            false
        } finally {
            try { inputStream?.close() } catch (_: Exception) {}
        }
    }

    suspend fun saveToGallery(context: Context, imageUrl: String, filename: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = URL(imageUrl)
            val connection = url.openConnection()
            connection.connectTimeout = 30000
            val input = connection.getInputStream()
            val bitmap = BitmapFactory.decodeStream(input) ?: return@withContext false
            input.close()

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, "$filename.jpg")
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/AnimeWallpapers")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: return@withContext false

            resolver.openOutputStream(uri)?.use { outputStream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, outputStream)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }

            Log.i(TAG, "Saved wallpaper to gallery successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save wallpaper to gallery", e)
            false
        }
    }

    fun pruneCache(context: Context, maxLimit: Int) {
        try {
            val cacheDir = File(context.cacheDir, "wallpapers")
            if (!cacheDir.exists()) return

            val files = cacheDir.listFiles() ?: return
            if (files.size <= maxLimit) return

            files.sortBy { it.lastModified() }
            val deleteCount = files.size - maxLimit

            for (i in 0 until deleteCount) {
                files[i].delete()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not prune cache", e)
        }
    }
}
