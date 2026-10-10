package com.exa31.animewallpaper.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class WallhavenResponse(
    val data: List<WallhavenItem> = emptyList()
)

@Serializable
data class WallhavenItem(
    val id: String,
    val url: String,
    @SerialName("short_url") val shortUrl: String = "",
    val resolution: String = "",
    val ratio: String = "",
    @SerialName("file_size") val fileSize: Long = 0,
    @SerialName("file_type") val fileType: String = "",
    val path: String,
    val thumbs: WallhavenThumbs? = null
)

@Serializable
data class WallhavenThumbs(
    val large: String = "",
    val original: String = "",
    val small: String = ""
)

enum class WallpaperTarget {
    HOME_SCREEN,
    LOCK_SCREEN,
    BOTH
}

data class UserPreferences(
    val query: String = "anime",
    val sfwOnly: Boolean = true,
    val isRandom: Boolean = true,
    val intervalMinutes: Long = 60,
    val isAutoRotationEnabled: Boolean = false,
    val wifiOnly: Boolean = true,
    val target: WallpaperTarget = WallpaperTarget.BOTH,
    val apiKey: String = "",
    val maxCacheLimit: Int = 15
)
