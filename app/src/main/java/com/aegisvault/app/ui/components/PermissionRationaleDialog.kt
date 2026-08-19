package com.aegisvault.app.ui.components

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable

@Composable
fun PermissionRationaleDialog(
    permanentlyDenied: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Media access needed") },
        text = {
            Text(
                if (permanentlyDenied) {
                    "Aegis Vault needs media access to show your photos and videos. " +
                        "Since permission was permanently denied, open Settings to grant it."
                } else {
                    "Aegis Vault reads your photos and videos entirely on-device — nothing is " +
                        "ever uploaded. Grant access to browse your gallery."
                },
            )
        },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(if (permanentlyDenied) "Open Settings" else "Grant access") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Not now") }
        },
    )
}
