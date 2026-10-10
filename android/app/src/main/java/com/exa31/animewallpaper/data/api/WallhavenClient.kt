package com.exa31.animewallpaper.data.api

import android.util.Log
import com.exa31.animewallpaper.data.model.UserPreferences
import com.exa31.animewallpaper.data.model.WallhavenItem
import com.exa31.animewallpaper.data.model.WallhavenResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object WallhavenClient {
    private const val TAG = "WallhavenClient"

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            val request = chain.request().newBuilder()
                .header("User-Agent", "AnimeWallpaperAndroid/1.0")
                .build()
            chain.proceed(request)
        }
        .build()

    suspend fun searchWallpapers(prefs: UserPreferences): List<WallhavenItem> = withContext(Dispatchers.IO) {
        try {
            val query = prefs.query.ifBlank { "anime" }
            val categories = "010" // 010 = Anime category
            val purity = if (prefs.sfwOnly) "100" else "110"
            val sorting = if (prefs.isRandom) "random" else "toplist"

            // Optimization for mobile: Prioritize portrait ratios
            val ratios = "9x16,10x16,9x18,9x19.5"

            val urlBuilder = HttpUrl.Builder()
                .scheme("https")
                .host("wallhaven.cc")
                .addPathSegments("api/v1/search")
                .addQueryParameter("q", query)
                .addQueryParameter("categories", categories)
                .addQueryParameter("purity", purity)
                .addQueryParameter("sorting", sorting)
                .addQueryParameter("ratios", ratios)

            if (prefs.apiKey.isNotBlank()) {
                urlBuilder.addQueryParameter("apikey", prefs.apiKey.trim())
            }

            val requestBuilder = Request.Builder()
                .url(urlBuilder.build())
                .get()

            if (prefs.apiKey.isNotBlank()) {
                requestBuilder.header("X-API-Key", prefs.apiKey.trim())
            }

            val response = okHttpClient.newCall(requestBuilder.build()).execute()

            if (response.code == 429) {
                Log.w(TAG, "Wallhaven API rate limit hit (HTTP 429). Retrying later.")
                return@withContext emptyList()
            }

            if (!response.isSuccessful) {
                Log.w(TAG, "Wallhaven returned error: ${response.code} ${response.message}")
                return@withContext emptyList()
            }

            val body = response.body?.string() ?: return@withContext emptyList()
            val parsed = json.decodeFromString<WallhavenResponse>(body)
            Log.d(TAG, "Fetched ${parsed.data.size} portrait anime wallpapers.")
            parsed.data
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query Wallhaven API", e)
            emptyList()
        }
    }
}
