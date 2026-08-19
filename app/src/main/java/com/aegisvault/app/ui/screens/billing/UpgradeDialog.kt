package com.aegisvault.app.ui.screens.billing

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

/** Shown when a free-tier limit (the 15-item vault cap) is hit, offering a path to the paywall. */
@Composable
fun UpgradeDialog(
    onUpgrade: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Vault is full") },
        text = { Text("Free accounts can store up to 15 items in the vault. Upgrade to Aegis Pro for unlimited encrypted storage.") },
        confirmButton = { TextButton(onClick = onUpgrade) { Text("Upgrade") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Not now") } },
    )
}
