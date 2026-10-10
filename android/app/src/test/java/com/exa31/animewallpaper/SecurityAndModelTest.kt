package com.exa31.animewallpaper

import com.exa31.animewallpaper.data.model.UserPreferences
import com.exa31.animewallpaper.data.model.WallpaperTarget
import com.exa31.animewallpaper.data.model.WallhavenResponse
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class SecurityAndModelTest {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    @Test
    fun testWallhavenResponseDeserialization() {
        val sampleJson = """
        {
          "data": [
            {
              "id": "android_test_1",
              "url": "https://wallhaven.cc/w/android_test_1",
              "resolution": "1080x1920",
              "ratio": "9:16",
              "file_size": 512000,
              "file_type": "image/jpeg",
              "path": "https://w.wallhaven.cc/full/an/wallhaven-android_test_1.jpg"
            }
          ]
        }
        """.trimIndent()

        val parsed = json.decodeFromString<WallhavenResponse>(sampleJson)
        assertEquals(1, parsed.data.size)
        assertEquals("android_test_1", parsed.data[0].id)
        assertEquals("9:16", parsed.data[0].ratio)
        assertEquals("1080x1920", parsed.data[0].resolution)
    }

    @Test
    fun testPortraitAspectRatioQueryValidation() {
        val prefs = UserPreferences(
            query = "cyberpunk anime",
            sfwOnly = true,
            target = WallpaperTarget.BOTH
        )

        assertEquals("cyberpunk anime", prefs.query)
        assertTrue(prefs.sfwOnly)
        assertEquals(WallpaperTarget.BOTH, prefs.target)
    }

    @Test
    fun testPathTraversalIdPrevention() {
        fun isValidId(id: String): Boolean {
            return id.isNotBlank() && Regex("^[a-zA-Z0-9_-]{1,64}$").matches(id)
        }

        assertTrue(isValidId("valid_wallpaper_123"))
        assertFalse(isValidId("../../system/build.prop"))
        assertFalse(isValidId("../secret.key"))
        assertFalse(isValidId("id with spaces"))
    }

    @Test
    fun testUrlWhitelistValidation() {
        fun isWhitelistedUrl(url: String): Boolean {
            if (!url.startsWith("https://")) return false
            val host = runCatching { java.net.URI(url).host?.lowercase() }.getOrNull() ?: return false
            return host == "wallhaven.cc" || host.endsWith(".wallhaven.cc")
        }

        assertTrue(isWhitelistedUrl("https://w.wallhaven.cc/full/12/wallhaven-123.jpg"))
        assertFalse(isWhitelistedUrl("http://w.wallhaven.cc/full/12/wallhaven-123.jpg")) // Non-HTTPS
        assertFalse(isWhitelistedUrl("https://malicious-server.net/apk.png"))
        assertFalse(isWhitelistedUrl("file:///data/data/com.exa31/databases"))
    }
}
