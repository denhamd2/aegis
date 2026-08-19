package com.aegisvault.app.ui.screens.vault

import android.content.Intent
import android.graphics.BitmapFactory
import androidx.activity.ComponentActivity
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.model.MediaType
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VaultDetailScreen(
    vaultItemId: Long,
    onBack: () -> Unit,
    viewModel: VaultViewModel = hiltViewModel(LocalContext.current as ComponentActivity),
) {
    val uiState by viewModel.uiState.collectAsState()
    val item = uiState.items.firstOrNull { it.id == vaultItemId } ?: run { onBack(); return }
    val bytes = uiState.decryptedThumbnails[item.id]
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(item.id) { viewModel.ensureDecrypted(item) }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is VaultEvent.ShareUri -> {
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = event.mimeType
                        putExtra(Intent.EXTRA_STREAM, event.uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    context.startActivity(Intent.createChooser(shareIntent, "Share"))
                }
                is VaultEvent.Error -> scope.launch { snackbarHostState.showSnackbar(event.message) }
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text(item.originalDisplayName) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
                actions = {
                    IconButton(onClick = { viewModel.shareItem(item) }) {
                        Icon(Icons.Filled.Share, contentDescription = "Share (metadata stripped)")
                    }
                    IconButton(onClick = { viewModel.restoreItem(item) { onBack() } }) {
                        Icon(Icons.Filled.Restore, contentDescription = "Restore to gallery")
                    }
                    IconButton(onClick = { viewModel.deleteItem(item); onBack() }) {
                        Icon(Icons.Filled.Delete, contentDescription = "Delete permanently")
                    }
                },
            )
        },
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
            when {
                bytes == null -> CircularProgressIndicator()
                item.mediaType == MediaType.IMAGE -> {
                    val bitmap = remember(item.id, bytes) {
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImageBitmap()
                    }
                    Image(
                        bitmap = bitmap,
                        contentDescription = item.originalDisplayName,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
                else -> Text("Preview not available for this file type. Use Restore to view it outside the vault.")
            }
        }
    }
}
