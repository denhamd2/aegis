package com.aegisvault.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp

const val VAULT_BACKUP_MIN_PASSWORD_LENGTH = 8

enum class VaultBackupDialogMode { EXPORT, IMPORT }

/**
 * One reusable password prompt for both vault backup flows. Export requires entering the
 * password twice (nothing recovers it if mistyped and never confirmed); import only needs it
 * once, since a wrong guess there just fails cleanly and can be retried.
 */
@Composable
fun VaultBackupPasswordDialog(
    mode: VaultBackupDialogMode,
    onDismiss: () -> Unit,
    onConfirm: (CharArray) -> Unit,
) {
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }

    val tooShort = password.length < VAULT_BACKUP_MIN_PASSWORD_LENGTH
    val mismatch = mode == VaultBackupDialogMode.EXPORT && password != confirmPassword
    val canConfirm = password.isNotEmpty() && !tooShort && !mismatch

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(if (mode == VaultBackupDialogMode.EXPORT) "Set a backup password" else "Enter the backup password")
        },
        text = {
            Column {
                if (mode == VaultBackupDialogMode.EXPORT) {
                    Text("You'll need this password to restore the backup later. There's no way to recover it if you forget it — Aegis Vault never sees or stores it.")
                } else {
                    Text("Enter the password this backup was created with.")
                }
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    isError = password.isNotEmpty() && tooShort,
                    modifier = Modifier.padding(top = 12.dp),
                )
                if (mode == VaultBackupDialogMode.EXPORT) {
                    OutlinedTextField(
                        value = confirmPassword,
                        onValueChange = { confirmPassword = it },
                        label = { Text("Confirm password") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        isError = confirmPassword.isNotEmpty() && mismatch,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                if (password.isNotEmpty() && tooShort) {
                    Text("Use at least $VAULT_BACKUP_MIN_PASSWORD_LENGTH characters.", modifier = Modifier.padding(top = 4.dp))
                } else if (confirmPassword.isNotEmpty() && mismatch) {
                    Text("Passwords don't match.", modifier = Modifier.padding(top = 4.dp))
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = canConfirm,
                onClick = { onConfirm(password.toCharArray()) },
            ) { Text(if (mode == VaultBackupDialogMode.EXPORT) "Export" else "Import") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}
