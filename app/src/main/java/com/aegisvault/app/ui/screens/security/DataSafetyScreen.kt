package com.aegisvault.app.ui.screens.security

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Key
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.repository.ExportVaultResult
import com.aegisvault.app.domain.repository.ImportVaultResult
import com.aegisvault.app.ui.components.VaultBackupDialogMode
import com.aegisvault.app.ui.components.VaultBackupPasswordDialog
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DataSafetyScreen(
    onBack: () -> Unit,
    viewModel: DataSafetyViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var exportDestinationUri by remember { mutableStateOf<Uri?>(null) }
    var importSourceUri by remember { mutableStateOf<Uri?>(null) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream"),
    ) { uri -> exportDestinationUri = uri }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri -> importSourceUri = uri }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is DataSafetyEvent.ExportFinished -> scope.launch {
                    snackbarHostState.showSnackbar(
                        when (val result = event.result) {
                            is ExportVaultResult.Success -> "Exported ${result.itemCount} item(s) to your backup file"
                            is ExportVaultResult.Error -> "Export failed: ${result.message}"
                        },
                    )
                }
                is DataSafetyEvent.ImportFinished -> scope.launch {
                    snackbarHostState.showSnackbar(
                        when (val result = event.result) {
                            is ImportVaultResult.Success -> "Imported ${result.itemCount} item(s)"
                            is ImportVaultResult.PartiallyImported ->
                                "Imported ${result.importedCount} item(s) — ${result.skippedCount} skipped (upgrade to Pro for unlimited vault storage)"
                            ImportVaultResult.WrongPassword -> "Wrong password — that backup couldn't be opened"
                            is ImportVaultResult.Error -> "Import failed: ${result.message}"
                        },
                    )
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Data Safety") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            Text(
                "What happens to your vault if you lose this device, and how to protect against it.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            InfoCard(
                icon = Icons.Filled.CloudOff,
                title = "Device-only storage",
                detail = "Vault photos and videos are encrypted and stored only on this device. " +
                    "They are never uploaded, synced, or backed up automatically. Losing, wiping, " +
                    "or reinstalling on this device permanently deletes them unless you've exported a backup.",
                modifier = Modifier.padding(top = 20.dp),
            )
            InfoCard(
                icon = Icons.Filled.Key,
                title = "No password recovery",
                detail = "A backup is encrypted with a password only you know. Aegis Vault never sees " +
                    "or stores it. If you forget it, that backup can't be opened by anyone, including us.",
                modifier = Modifier.padding(top = 12.dp),
            )

            Text(
                "Back up your vault",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 24.dp, bottom = 4.dp),
            )
            Text(
                "Creates a single encrypted file containing everything currently in your vault. " +
                    "Intruder-capture photos and app settings are not included.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Row(modifier = Modifier.padding(top = 16.dp)) {
                Button(
                    onClick = { exportLauncher.launch("aegis-vault-backup.aegisvault") },
                    enabled = !uiState.isExporting,
                ) { Text("Export Vault") }
                OutlinedButton(
                    onClick = { importLauncher.launch(arrayOf("*/*")) },
                    enabled = !uiState.isImporting,
                    modifier = Modifier.padding(start = 12.dp),
                ) { Text("Import Vault") }
            }

            if (uiState.isExporting || uiState.isImporting) {
                Row(modifier = Modifier.padding(top = 16.dp)) {
                    CircularProgressIndicator(modifier = Modifier.padding(end = 12.dp))
                    Text(if (uiState.isExporting) "Exporting…" else "Importing…")
                }
            }
        }
    }

    exportDestinationUri?.let { uri ->
        VaultBackupPasswordDialog(
            mode = VaultBackupDialogMode.EXPORT,
            onDismiss = { exportDestinationUri = null },
            onConfirm = { password ->
                viewModel.exportVault(uri, password)
                exportDestinationUri = null
            },
        )
    }

    importSourceUri?.let { uri ->
        VaultBackupPasswordDialog(
            mode = VaultBackupDialogMode.IMPORT,
            onDismiss = { importSourceUri = null },
            onConfirm = { password ->
                viewModel.importVault(uri, password)
                importSourceUri = null
            },
        )
    }
}

@Composable
private fun InfoCard(icon: ImageVector, title: String, detail: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 1.dp,
    ) {
        Row(modifier = Modifier.padding(16.dp)) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(end = 12.dp),
            )
            Column {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(
                    detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
