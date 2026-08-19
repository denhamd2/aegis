package com.aegisvault.app.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.aegisvault.app.ui.screens.billing.PaywallScreen
import com.aegisvault.app.ui.screens.gallery.GalleryScreen
import com.aegisvault.app.ui.screens.landing.LandingScreen
import com.aegisvault.app.ui.screens.security.IntruderLogScreen
import com.aegisvault.app.ui.screens.security.VerifyOfflineScreen
import com.aegisvault.app.ui.screens.settings.SettingsScreen
import com.aegisvault.app.ui.screens.utilities.UtilitiesScreen
import com.aegisvault.app.ui.screens.utilities.exif.ExifStripperScreen
import com.aegisvault.app.ui.screens.utilities.pdf.PdfViewerScreen
import com.aegisvault.app.ui.screens.utilities.storage.StorageAnalyzerScreen
import com.aegisvault.app.ui.screens.vault.VaultDetailScreen
import com.aegisvault.app.ui.screens.vault.VaultGateScreen
import com.aegisvault.app.ui.screens.vault.VaultScreen
import java.net.URLDecoder
import java.net.URLEncoder

private const val ANIM_DURATION_MILLIS = 260

@Composable
fun AegisNavHost() {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val topLevelRoutes = setOf(
        NavRoutes.GALLERY, NavRoutes.VAULT_GATE, NavRoutes.VAULT, NavRoutes.UTILITIES, NavRoutes.SETTINGS,
        // Utilities sub-screens keep the bottom nav too, rather than hiding it like Vault detail does.
        NavRoutes.EXIF_STRIPPER, "${NavRoutes.PDF_VIEWER}?uri={uri}", NavRoutes.STORAGE_ANALYZER,
    )

    Scaffold(
        bottomBar = {
            if (currentRoute in topLevelRoutes) AegisBottomNavBar(navController)
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = NavRoutes.LANDING,
            modifier = Modifier.padding(innerPadding),
            enterTransition = { fadeIn(tween(ANIM_DURATION_MILLIS)) + slideInHorizontally(tween(ANIM_DURATION_MILLIS)) { it / 8 } },
            exitTransition = { fadeOut(tween(ANIM_DURATION_MILLIS)) },
            popEnterTransition = { fadeIn(tween(ANIM_DURATION_MILLIS)) },
            popExitTransition = { fadeOut(tween(ANIM_DURATION_MILLIS)) + slideOutHorizontally(tween(ANIM_DURATION_MILLIS)) { it / 8 } },
        ) {
            composable(NavRoutes.LANDING) {
                LandingScreen(
                    onGetStarted = {
                        navController.navigate(NavRoutes.GALLERY) {
                            popUpTo(NavRoutes.LANDING) { inclusive = true }
                        }
                    },
                )
            }

            composable(NavRoutes.GALLERY) {
                GalleryScreen(
                    onOpenVault = { navController.navigate(NavRoutes.VAULT_GATE) },
                )
            }

            composable(NavRoutes.VAULT_GATE) {
                VaultGateScreen(
                    onUnlocked = {
                        navController.navigate(NavRoutes.VAULT) {
                            popUpTo(NavRoutes.VAULT_GATE) { inclusive = true }
                        }
                    },
                )
            }

            composable(NavRoutes.VAULT) {
                VaultScreen(
                    onOpenItem = { id -> navController.navigate(NavRoutes.vaultDetail(id)) },
                    onUpgradeRequired = { navController.navigate(NavRoutes.PAYWALL) },
                    onLocked = {
                        navController.navigate(NavRoutes.GALLERY) {
                            popUpTo(NavRoutes.GALLERY) { inclusive = true }
                        }
                    },
                )
            }

            composable(
                route = NavRoutes.VAULT_DETAIL,
                arguments = listOf(navArgument("vaultItemId") { type = NavType.LongType }),
            ) { backStack ->
                val vaultItemId = backStack.arguments?.getLong("vaultItemId") ?: return@composable
                VaultDetailScreen(vaultItemId = vaultItemId, onBack = { navController.popBackStack() })
            }

            composable(NavRoutes.UTILITIES) {
                UtilitiesScreen(
                    onOpenExifStripper = { navController.navigate(NavRoutes.EXIF_STRIPPER) },
                    onOpenPdfViewer = { navController.navigate(NavRoutes.PDF_VIEWER) },
                    onOpenStorageAnalyzer = { navController.navigate(NavRoutes.STORAGE_ANALYZER) },
                )
            }

            composable(NavRoutes.EXIF_STRIPPER) {
                ExifStripperScreen(onBack = { navController.popBackStack() })
            }

            composable(
                route = "${NavRoutes.PDF_VIEWER}?uri={uri}",
                arguments = listOf(navArgument("uri") { type = NavType.StringType; defaultValue = "" }),
            ) { backStack ->
                val encodedUri = backStack.arguments?.getString("uri").orEmpty()
                val uri = if (encodedUri.isNotEmpty()) URLDecoder.decode(encodedUri, "UTF-8") else null
                PdfViewerScreen(initialUri = uri, onBack = { navController.popBackStack() })
            }

            composable(NavRoutes.STORAGE_ANALYZER) {
                StorageAnalyzerScreen(onBack = { navController.popBackStack() })
            }

            composable(NavRoutes.SETTINGS) {
                SettingsScreen(
                    onOpenPaywall = { navController.navigate(NavRoutes.PAYWALL) },
                    onOpenIntruderLog = { navController.navigate(NavRoutes.INTRUDER_LOG) },
                    onOpenVerifyOffline = { navController.navigate(NavRoutes.VERIFY_OFFLINE) },
                )
            }

            composable(NavRoutes.PAYWALL) {
                PaywallScreen(onBack = { navController.popBackStack() })
            }

            composable(NavRoutes.INTRUDER_LOG) {
                IntruderLogScreen(onBack = { navController.popBackStack() })
            }

            composable(NavRoutes.VERIFY_OFFLINE) {
                VerifyOfflineScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}

fun encodeUriForNav(uri: String): String = URLEncoder.encode(uri, "UTF-8")
