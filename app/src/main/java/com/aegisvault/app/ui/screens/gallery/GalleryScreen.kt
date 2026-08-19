package com.aegisvault.app.ui.screens.gallery

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoLibrary
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.MainActivity
import com.aegisvault.app.ui.components.EmptyState
import com.aegisvault.app.ui.components.FilterChipRow
import com.aegisvault.app.ui.components.MasonryGrid
import com.aegisvault.app.ui.components.SelectionTopBar
import com.aegisvault.app.ui.screens.permissions.PermissionRequestScreen
import kotlinx.coroutines.launch

private fun hasMediaPermission(context: android.content.Context): Boolean {
    val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        Manifest.permission.READ_MEDIA_IMAGES
    } else {
        Manifest.permission.READ_EXTERNAL_STORAGE
    }
    return androidx.core.content.ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GalleryScreen(
    onOpenVault: () -> Unit,
    viewModel: GalleryViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    var permissionGranted by remember { mutableStateOf(hasMediaPermission(context)) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(permissionGranted) {
        if (permissionGranted) viewModel.onPermissionResult(true)
    }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is GalleryEvent.RequestDeleteConsent -> {
                    (context as? MainActivity)?.requestDeleteConsent(event.intentSender) { }
                }
                is GalleryEvent.CapacityExceeded ->
                    scope.launch { snackbarHostState.showSnackbar("Vault is full (${event.limit} items). Upgrade to Pro for unlimited storage.") }
                is GalleryEvent.MovedToVault ->
                    scope.launch { snackbarHostState.showSnackbar("${event.count} item(s) moved to vault") }
                is GalleryEvent.ShareUris -> {
                    val uris = event.uris.map { Uri.parse(it) }
                    val shareIntent = if (uris.size == 1) {
                        Intent(Intent.ACTION_SEND).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_STREAM, uris.first())
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    } else {
                        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = "*/*"
                            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    }
                    context.startActivity(Intent.createChooser(shareIntent, "Share"))
                }
                is GalleryEvent.Error ->
                    scope.launch { snackbarHostState.showSnackbar(event.message) }
            }
        }
    }

    if (!permissionGranted) {
        PermissionRequestScreen(onResult = { granted -> permissionGranted = granted })
        return
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            if (uiState.selectionModeActive) {
                SelectionTopBar(
                    selectedCount = uiState.selectedIds.size,
                    onClose = viewModel::clearSelection,
                    onShareStripped = viewModel::shareSelectedStripped,
                    onMoveToVault = viewModel::moveSelectedToVault,
                )
            } else {
                TopAppBar(
                    title = { Text("Gallery") },
                    actions = {
                        IconButton(onClick = onOpenVault) {
                            Icon(Icons.Filled.PhotoLibrary, contentDescription = "Open vault")
                        }
                    },
                )
            }
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            FilterChipRow(selected = uiState.filter, onSelected = viewModel::setFilter)

            if (uiState.mediaItems.isEmpty() && !uiState.isLoading) {
                EmptyState(
                    icon = Icons.Filled.PhotoLibrary,
                    title = "No media found",
                    subtitle = "Photos and videos on this device will appear here",
                )
            } else {
                MasonryGrid(
                    items = uiState.mediaItems,
                    selectedIds = uiState.selectedIds,
                    selectionModeActive = uiState.selectionModeActive,
                    onItemClick = { item ->
                        if (uiState.selectionModeActive) viewModel.toggleSelection(item)
                    },
                    onItemLongClick = viewModel::toggleSelection,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}
