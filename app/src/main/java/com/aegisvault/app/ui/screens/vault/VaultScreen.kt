package com.aegisvault.app.ui.screens.vault

import android.graphics.BitmapFactory
import androidx.activity.ComponentActivity
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.ui.components.BrandedTitle
import com.aegisvault.app.ui.components.EmptyState
import com.aegisvault.app.ui.components.ProStatusCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VaultScreen(
    onOpenItem: (Long) -> Unit,
    onUpgradeRequired: () -> Unit,
    onLocked: () -> Unit,
    viewModel: VaultViewModel = hiltViewModel(LocalContext.current as ComponentActivity),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.unlocked) {
        if (!uiState.unlocked) onLocked()
    }
    if (!uiState.unlocked) return

    Scaffold(
        topBar = { TopAppBar(title = { BrandedTitle("Vault") }) },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            if (uiState.vaultFull) {
                ProStatusCard(
                    purchaseState = uiState.purchaseState,
                    onUpgradeClick = onUpgradeRequired,
                    modifier = Modifier.padding(16.dp),
                )
            }

            if (uiState.items.isEmpty() && !uiState.isLoading) {
                EmptyState(
                    icon = Icons.Filled.Lock,
                    title = "Vault is empty",
                    subtitle = "Move photos, videos, or documents here from the Gallery tab",
                )
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 110.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(uiState.items, key = { it.id }) { item ->
                        VaultThumbnail(
                            item = item,
                            decryptedBytes = uiState.decryptedThumbnails[item.id],
                            onClick = { onOpenItem(item.id) },
                            requestDecrypt = { viewModel.ensureDecrypted(item) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun VaultThumbnail(
    item: VaultItem,
    decryptedBytes: ByteArray?,
    onClick: () -> Unit,
    requestDecrypt: () -> Unit,
) {
    LaunchedEffect(item.id) {
        if (item.mediaType == MediaType.IMAGE) requestDecrypt()
    }

    Surface(modifier = Modifier.aspectRatio(1f).clickable(onClick = onClick)) {
        Box(Modifier.fillMaxSize()) {
            if (item.mediaType == MediaType.IMAGE && decryptedBytes != null) {
                val bitmap = remember(item.id, decryptedBytes) {
                    BitmapFactory.decodeByteArray(decryptedBytes, 0, decryptedBytes.size).asImageBitmap()
                }
                Image(
                    bitmap = bitmap,
                    contentDescription = item.originalDisplayName,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.InsertDriveFile,
                        contentDescription = item.originalDisplayName,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        item.originalDisplayName,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }
            }

            TrustBadge(modifier = Modifier.align(Alignment.TopEnd).padding(6.dp))
        }
    }
}

/** Reinforces the vault's trust claim at the point of use, not just at install/marketing time. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TrustBadge(modifier: Modifier = Modifier) {
    TooltipBox(
        positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
        tooltip = { PlainTooltip { Text("AES-256, on-device only. Never uploaded, never backed up.") } },
        state = rememberTooltipState(),
    ) {
        Box(
            modifier = modifier
                .background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(50)),
        ) {
            Icon(
                imageVector = Icons.Filled.Shield,
                contentDescription = "AES-256, on-device only. Never uploaded, never backed up.",
                tint = Color.White,
                modifier = Modifier.padding(4.dp),
            )
        }
    }
}
