package com.exa31.animewallpaper

import android.content.Context
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.exa31.animewallpaper.data.api.WallhavenClient
import com.exa31.animewallpaper.data.model.UserPreferences
import com.exa31.animewallpaper.data.model.WallpaperTarget
import com.exa31.animewallpaper.data.model.WallhavenItem
import com.exa31.animewallpaper.service.WallpaperHelper
import com.exa31.animewallpaper.ui.theme.AnimeWallpaperTheme
import com.exa31.animewallpaper.ui.theme.SakuraPink
import com.exa31.animewallpaper.worker.WallpaperRotationWorker
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AnimeWallpaperTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AnimeWallpaperScreen()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnimeWallpaperScreen() {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val scrollState = rememberScrollState()

    val sharedPrefs = remember { context.getSharedPreferences("anime_prefs", Context.MODE_PRIVATE) }

    var query by remember { mutableStateOf(sharedPrefs.getString("query", "anime") ?: "anime") }
    var sfwOnly by remember { mutableStateOf(sharedPrefs.getBoolean("sfwOnly", true)) }
    var wifiOnly by remember { mutableStateOf(sharedPrefs.getBoolean("wifiOnly", true)) }
    var autoRotation by remember { mutableStateOf(sharedPrefs.getBoolean("autoRotation", false)) }
    var intervalMinutes by remember { mutableLongStateOf(sharedPrefs.getLong("intervalMinutes", 60L)) }
    var target by remember {
        mutableStateOf(
            try {
                WallpaperTarget.valueOf(sharedPrefs.getString("target", WallpaperTarget.BOTH.name) ?: WallpaperTarget.BOTH.name)
            } catch (_: Exception) {
                WallpaperTarget.BOTH
            }
        )
    }

    var currentItem by remember { mutableStateOf<WallhavenItem?>(null) }
    var isLoading by remember { mutableStateOf(false) }

    fun savePrefs() {
        sharedPrefs.edit()
            .putString("query", query)
            .putBoolean("sfwOnly", sfwOnly)
            .putBoolean("wifiOnly", wifiOnly)
            .putBoolean("autoRotation", autoRotation)
            .putLong("intervalMinutes", intervalMinutes)
            .putString("target", target.name)
            .apply()
    }

    fun fetchAndApplyNext() {
        coroutineScope.launch {
            isLoading = true
            val prefs = UserPreferences(
                query = query,
                sfwOnly = sfwOnly,
                target = target,
                wifiOnly = wifiOnly
            )
            val results = WallhavenClient.searchWallpapers(prefs)
            if (results.isNotEmpty()) {
                val selected = results.random()
                currentItem = selected
                val applied = WallpaperHelper.applyWallpaper(context, selected.path, target)
                if (applied) {
                    Toast.makeText(context, "✨ Wallpaper applied successfully!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(context, "❌ Failed to set wallpaper", Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(context, "No anime wallpapers found", Toast.LENGTH_SHORT).show()
            }
            isLoading = false
        }
    }

    val presetChips = listOf(
        "anime",
        "anime girl",
        "cyberpunk anime",
        "landscape anime",
        "studio ghibli",
        "makoto shinkai"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // App Header
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "🌸 Anime Wallpaper",
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontWeight = FontWeight.Bold,
                    color = SakuraPink
                )
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Preset Chips
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            presetChips.forEach { chip ->
                FilterChip(
                    selected = query.equals(chip, ignoreCase = true),
                    onClick = {
                        query = chip
                        savePrefs()
                        fetchAndApplyNext()
                    },
                    label = { Text(chip) }
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Live Preview Card (Portrait 9:16 aspect ratio preview)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(420.dp),
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                if (currentItem != null) {
                    AsyncImage(
                        model = currentItem?.thumbs?.large ?: currentItem?.path,
                        contentDescription = "Current Wallpaper",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )

                    // Gradient overlay with metadata
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .background(Color.Black.copy(alpha = 0.65f))
                            .padding(12.dp)
                    ) {
                        Column {
                            Text(
                                text = "ID: #${currentItem?.id} • ${currentItem?.resolution}",
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 13.sp
                            )
                            Text(
                                text = "Category: ${currentItem?.category} • Purity: ${currentItem?.purity}",
                                color = Color.LightGray,
                                fontSize = 11.sp
                            )
                        }
                    }
                } else {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.Wallpaper,
                            contentDescription = null,
                            tint = Color.Gray,
                            modifier = Modifier.size(54.dp)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Tap 'Next Wallpaper' to load anime art",
                            color = Color.LightGray,
                            fontSize = 14.sp
                        )
                    }
                }

                if (isLoading) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.5f)),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = SakuraPink)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Primary Action Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Button(
                onClick = { fetchAndApplyNext() },
                enabled = !isLoading,
                modifier = Modifier.weight(1f).height(50.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SakuraPink)
            ) {
                Icon(imageVector = Icons.Default.Refresh, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text(text = "Next Wallpaper", fontWeight = FontWeight.Bold)
            }

            OutlinedButton(
                onClick = {
                    currentItem?.let { item ->
                        coroutineScope.launch {
                            val saved = WallpaperHelper.saveToGallery(context, item.path, "wallhaven_${item.id}")
                            if (saved) {
                                Toast.makeText(context, "Saved to Gallery!", Toast.LENGTH_SHORT).show()
                            } else {
                                Toast.makeText(context, "Failed to save", Toast.LENGTH_SHORT).show()
                            }
                        }
                    } ?: Toast.makeText(context, "Load a wallpaper first", Toast.LENGTH_SHORT).show()
                },
                modifier = Modifier.height(50.dp)
            ) {
                Icon(imageVector = Icons.Default.Download, contentDescription = null)
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Target Chooser (Home, Lock, Both)
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = "Apply Target",
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    WallpaperTarget.values().forEach { t ->
                        FilterChip(
                            selected = target == t,
                            onClick = {
                                target = t
                                savePrefs()
                            },
                            label = {
                                Text(
                                    when (t) {
                                        WallpaperTarget.HOME_SCREEN -> "Home"
                                        WallpaperTarget.LOCK_SCREEN -> "Lock"
                                        WallpaperTarget.BOTH -> "Both"
                                    }
                                )
                            }
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Background Rotation & Battery/Wi-Fi Optimization Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Auto-Rotation (WorkManager)",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                        Text(
                            text = "Battery-efficient background rotation",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )
                    }
                    Switch(
                        checked = autoRotation,
                        onCheckedChange = { enabled ->
                            autoRotation = enabled
                            savePrefs()
                            if (enabled) {
                                WallpaperRotationWorker.schedulePeriodicWork(context, intervalMinutes, wifiOnly)
                                Toast.makeText(context, "Auto-rotation enabled", Toast.LENGTH_SHORT).show()
                            } else {
                                WallpaperRotationWorker.cancelWork(context)
                                Toast.makeText(context, "Auto-rotation stopped", Toast.LENGTH_SHORT).show()
                            }
                        }
                    )
                }

                Divider(modifier = Modifier.padding(vertical = 10.dp), color = Color.White.copy(alpha = 0.1f))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(text = "Download on Wi-Fi Only", fontSize = 14.sp)
                        Text(text = "Prevent cellular data usage", fontSize = 11.sp, color = Color.Gray)
                    }
                    Switch(
                        checked = wifiOnly,
                        onCheckedChange = {
                            wifiOnly = it
                            savePrefs()
                            if (autoRotation) {
                                WallpaperRotationWorker.schedulePeriodicWork(context, intervalMinutes, wifiOnly)
                            }
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}
