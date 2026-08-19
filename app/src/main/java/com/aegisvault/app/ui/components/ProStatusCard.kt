package com.aegisvault.app.ui.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aegisvault.app.domain.model.PurchaseState

@Composable
fun ProStatusCard(
    purchaseState: PurchaseState,
    onUpgradeClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Row(
            modifier = Modifier.padding(16.dp).fillMaxWidth(),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (purchaseState == PurchaseState.PRO_LIFETIME) "Aegis Pro" else "Free Plan",
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = if (purchaseState == PurchaseState.PRO_LIFETIME) {
                        "Unlimited vault storage & auto EXIF cleaning unlocked"
                    } else {
                        "Vault limited to 15 items. Upgrade for unlimited storage."
                    },
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            if (purchaseState != PurchaseState.PRO_LIFETIME) {
                Button(onClick = onUpgradeClick) { Text("Upgrade") }
            }
        }
    }
}
