package com.aegisvault.app.ui.screens.settings

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.material3.SnackbarHostState
import com.aegisvault.app.domain.repository.AppIconDisguise
import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.ui.components.BrandedTitle
import com.aegisvault.app.ui.components.ProStatusCard
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onOpenPaywall: () -> Unit,
    onOpenIntruderLog: () -> Unit,
    onOpenVerifyOffline: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> viewModel.setIntruderAlertsEnabled(granted) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = { TopAppBar(title = { BrandedTitle("Settings") }) },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState()),
        ) {
            ProStatusCard(
                purchaseState = uiState.purchaseState,
                onUpgradeClick = onOpenPaywall,
                modifier = Modifier.padding(16.dp),
            )

            ListItem(
                headlineContent = { Text("Theme") },
                supportingContent = { Text("Choose the app's appearance") },
                trailingContent = {
                    var expanded by remember { mutableStateOf(false) }
                    Row {
                        TextButton(onClick = { expanded = true }) { Text(uiState.settings.theme.name) }
                        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            AppTheme.entries.forEach { theme ->
                                DropdownMenuItem(
                                    text = { Text(theme.name) },
                                    onClick = { viewModel.setTheme(theme); expanded = false },
                                )
                            }
                        }
                    }
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Biometric / PIN lock") },
                supportingContent = { Text("Require unlock to open the Vault") },
                trailingContent = {
                    Switch(
                        checked = uiState.settings.biometricLockEnabled,
                        onCheckedChange = viewModel::setBiometricLockEnabled,
                    )
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Auto-strip EXIF on export") },
                supportingContent = { Text("Always remove metadata when sharing photos") },
                trailingContent = {
                    Switch(
                        checked = uiState.settings.autoStripExifOnExport,
                        onCheckedChange = viewModel::setAutoStripExif,
                    )
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Lock on screen off") },
                supportingContent = { Text("Re-lock the Vault whenever the screen turns off") },
                trailingContent = {
                    Switch(
                        checked = uiState.settings.lockOnScreenOff,
                        onCheckedChange = viewModel::setLockOnScreenOff,
                    )
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Lock when face down") },
                supportingContent = { Text("Re-lock the Vault when you flip the phone face down") },
                trailingContent = {
                    Switch(
                        checked = uiState.settings.lockOnFaceDown,
                        onCheckedChange = viewModel::setLockOnFaceDown,
                    )
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Intruder alerts") },
                supportingContent = { Text("Snap a front-camera photo after a failed PIN attempt") },
                trailingContent = {
                    Switch(
                        checked = uiState.settings.intruderAlertsEnabled,
                        onCheckedChange = { enabled ->
                            if (!enabled) {
                                viewModel.setIntruderAlertsEnabled(false)
                                return@Switch
                            }
                            val alreadyGranted = ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.CAMERA,
                            ) == PackageManager.PERMISSION_GRANTED
                            if (alreadyGranted) {
                                viewModel.setIntruderAlertsEnabled(true)
                            } else {
                                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                            }
                        },
                    )
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("App icon") },
                supportingContent = { Text("Disguise the home screen icon and app name") },
                trailingContent = {
                    var expanded by remember { mutableStateOf(false) }
                    Row {
                        TextButton(onClick = { expanded = true }) {
                            Text(uiState.settings.iconDisguise.name)
                        }
                        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            AppIconDisguise.entries.forEach { disguise ->
                                DropdownMenuItem(
                                    text = { Text(disguise.name) },
                                    onClick = {
                                        viewModel.setIconDisguise(disguise)
                                        expanded = false
                                        scope.launch {
                                            snackbarHostState.showSnackbar(
                                                "Icon updated — you may need to check your home screen",
                                            )
                                        }
                                    },
                                )
                            }
                        }
                    }
                },
            )
            Divider()

            ListItem(
                headlineContent = { Text("Intruder log") },
                supportingContent = { Text("View or clear captured intruder photos") },
                modifier = Modifier.clickable(onClick = onOpenIntruderLog),
            )
            Divider()

            ListItem(
                headlineContent = { Text("Verify we're offline") },
                supportingContent = { Text("Prove this app has never requested network access") },
                modifier = Modifier.clickable(onClick = onOpenVerifyOffline),
            )
            Divider()

            Text(
                "Aegis Vault & Privacy Gallery is 100% offline — no data ever leaves this device.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(16.dp),
            )
        }
    }
}
