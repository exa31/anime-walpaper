package com.exa31.animewallpaper.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val SakuraPink = Color(0xFFFF7597)
val DeepPurple = Color(0xFF1E142B)
val DarkSurface = Color(0xFF161120)
val CardBackground = Color(0xFF241C33)
val TextPrimary = Color(0xFFF3EDF7)
val TextSecondary = Color(0xFFB9B0C4)
val AccentCyan = Color(0xFF80DEEA)

private val DarkColorScheme = darkColorScheme(
    primary = SakuraPink,
    secondary = AccentCyan,
    background = DeepPurple,
    surface = DarkSurface,
    surfaceVariant = CardBackground,
    onPrimary = Color.White,
    onBackground = TextPrimary,
    onSurface = TextPrimary
)

@Composable
fun AnimeWallpaperTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
