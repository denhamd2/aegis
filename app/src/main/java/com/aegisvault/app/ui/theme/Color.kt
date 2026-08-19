package com.aegisvault.app.ui.theme

import androidx.compose.ui.graphics.Color

// Static fallback palette used on API < 31 (no dynamic color) and as light-scheme seed colors.
val AegisPrimaryLight = Color(0xFF3D5AFE)
val AegisOnPrimaryLight = Color(0xFFFFFFFF)
val AegisSecondaryLight = Color(0xFF5C6BC0)
val AegisBackgroundLight = Color(0xFFFAFAFA)
val AegisSurfaceLight = Color(0xFFFFFFFF)

val AegisPrimaryDark = Color(0xFF8C9EFF)
val AegisOnPrimaryDark = Color(0xFF001A6E)
val AegisSecondaryDark = Color(0xFFB4C2FF)

// AMOLED true-black — forced onto the dark scheme's background/surface regardless of
// dynamic tonal output, per the design spec.
val AegisAmoledBlack = Color(0xFF000000)
val AegisAmoledSurface = Color(0xFF0A0A0A)

val VaultAccent = Color(0xFFFFC107)
