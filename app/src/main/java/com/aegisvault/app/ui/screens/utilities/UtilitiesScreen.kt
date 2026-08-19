package com.aegisvault.app.ui.screens.utilities

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aegisvault.app.ui.components.ToolCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UtilitiesScreen(
    onOpenExifStripper: () -> Unit,
    onOpenPdfViewer: () -> Unit,
    onOpenStorageAnalyzer: () -> Unit,
) {
    Scaffold(topBar = { TopAppBar(title = { Text("Utilities") }) }) { innerPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(innerPadding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ToolCard(
                icon = Icons.Filled.Shield,
                title = "EXIF Metadata Stripper",
                description = "Remove GPS, timestamps, and camera info from photos",
                onClick = onOpenExifStripper,
            )
            ToolCard(
                icon = Icons.Filled.PictureAsPdf,
                title = "Local PDF Reader",
                description = "View PDF documents entirely on-device",
                onClick = onOpenPdfViewer,
            )
            ToolCard(
                icon = Icons.Filled.Analytics,
                title = "Storage Analyzer",
                description = "See how photos, videos, and vault items use your storage",
                onClick = onOpenStorageAnalyzer,
            )
        }
    }
}
