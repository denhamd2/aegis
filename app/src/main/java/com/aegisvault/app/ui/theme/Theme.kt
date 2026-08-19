package com.aegisvault.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = AegisPrimaryLight,
    onPrimary = AegisOnPrimaryLight,
    secondary = AegisSecondaryLight,
    background = AegisBackgroundLight,
    surface = AegisSurfaceLight,
)

// AMOLED dark scheme: background/surface pinned to true black (#000000) regardless of the
// seed/dynamic tonal palette, per the design spec's "Dark Mode Priority" requirement.
private val DarkColors = darkColorScheme(
    primary = AegisPrimaryDark,
    onPrimary = AegisOnPrimaryDark,
    secondary = AegisSecondaryDark,
    background = AegisAmoledBlack,
    surface = AegisAmoledBlack,
    surfaceVariant = AegisAmoledSurface,
)

@Composable
fun AegisTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (darkTheme) {
                dynamicDarkColorScheme(context).copy(
                    background = AegisAmoledBlack,
                    surface = AegisAmoledBlack,
                )
            } else {
                dynamicLightColorScheme(context)
            }
        }
        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AegisTypography,
        shapes = AegisShapes,
        content = content,
    )
}
