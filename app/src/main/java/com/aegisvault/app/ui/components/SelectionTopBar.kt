package com.aegisvault.app.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SelectionTopBar(
    selectedCount: Int,
    onClose: () -> Unit,
    onShareStripped: () -> Unit,
    onMoveToVault: () -> Unit,
) {
    TopAppBar(
        title = { Text("$selectedCount selected") },
        navigationIcon = {
            IconButton(onClick = onClose) {
                Icon(Icons.Filled.Close, contentDescription = "Cancel selection")
            }
        },
        actions = {
            IconButton(onClick = onShareStripped, enabled = selectedCount > 0) {
                Icon(Icons.Filled.IosShare, contentDescription = "Share with EXIF stripped")
            }
            IconButton(onClick = onMoveToVault, enabled = selectedCount > 0) {
                Icon(Icons.Filled.Lock, contentDescription = "Move to vault")
            }
        },
    )
}
