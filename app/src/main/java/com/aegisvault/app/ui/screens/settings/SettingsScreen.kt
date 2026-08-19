package com.aegisvault.app.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.repository.AppTheme
import com.aegisvault.app.ui.components.ProStatusCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onOpenPaywall: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(topBar = { TopAppBar(title = { Text("Settings") }) }) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
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

            Text(
                "Aegis Vault & Privacy Gallery is 100% offline — no data ever leaves this device.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(16.dp),
            )
        }
    }
}
