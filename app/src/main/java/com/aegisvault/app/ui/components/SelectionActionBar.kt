package com.aegisvault.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Clearly-labeled selection actions, shown as a bottom bar (not icon-only top-bar buttons)
 * so "move to vault" reads as an obvious, tappable action rather than a decorative icon.
 */
@Composable
fun SelectionActionBar(
    selectedCount: Int,
    onShareStripped: () -> Unit,
    onMoveToVault: () -> Unit,
) {
    BottomAppBar {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceEvenly,
        ) {
            TextButton(onClick = onShareStripped, enabled = selectedCount > 0) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.IosShare, contentDescription = null)
                    Text("Share cleaned", style = MaterialTheme.typography.labelLarge)
                }
            }
            TextButton(onClick = onMoveToVault, enabled = selectedCount > 0) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Lock, contentDescription = null)
                    Text("Move to Vault", style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}
