package com.aegisvault.app.ui.screens.utilities.exif

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.ui.components.EmptyState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExifStripperScreen(
    onBack: () -> Unit,
    viewModel: ExifStripperViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            val name = context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                cursor.moveToFirst()
                if (nameIndex >= 0) cursor.getString(nameIndex) else "image.jpg"
            } ?: "image.jpg"
            viewModel.onImagePicked(uri, name)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("EXIF Metadata Stripper") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding).padding(16.dp)) {
            Button(onClick = { picker.launch("image/*") }, modifier = Modifier.fillMaxWidth()) {
                Text("Choose a photo")
            }

            when {
                uiState.pickedUri == null -> EmptyState(
                    icon = Icons.Filled.ArrowBack,
                    title = "No photo selected",
                    subtitle = "Pick a photo to see what metadata it carries",
                )
                uiState.isProcessing -> Column(
                    modifier = Modifier.fillMaxSize().padding(top = 32.dp),
                    horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
                ) { CircularProgressIndicator() }
                uiState.strippedUri != null -> Column(modifier = Modifier.padding(top = 24.dp)) {
                    Text("Metadata removed successfully.", style = MaterialTheme.typography.titleMedium)
                    Button(
                        onClick = {
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/*"
                                putExtra(Intent.EXTRA_STREAM, uiState.strippedUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(Intent.createChooser(shareIntent, "Share cleaned photo"))
                        },
                        modifier = Modifier.padding(top = 16.dp).fillMaxWidth(),
                    ) { Text("Share cleaned photo") }
                }
                else -> Column {
                    Text(
                        text = if (uiState.foundTags.isEmpty()) "No sensitive metadata found." else "Found ${uiState.foundTags.size} sensitive tag(s):",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(top = 16.dp, bottom = 8.dp),
                    )
                    LazyColumn(modifier = Modifier.weight(1f, fill = false)) {
                        items(uiState.foundTags.entries.toList()) { (tag, value) ->
                            ListItem(headlineContent = { Text(tag) }, supportingContent = { Text(value) })
                        }
                    }
                    Button(
                        onClick = viewModel::stripMetadata,
                        modifier = Modifier.padding(top = 16.dp).fillMaxWidth(),
                    ) { Text("Strip Metadata") }
                }
            }
        }
    }
}
