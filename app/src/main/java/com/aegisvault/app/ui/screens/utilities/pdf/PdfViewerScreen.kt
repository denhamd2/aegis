package com.aegisvault.app.ui.screens.utilities.pdf

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Draw
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.ui.components.EmptyState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PdfViewerScreen(
    initialUri: String?,
    onBack: () -> Unit,
    viewModel: PdfViewerViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) viewModel.openPdf(uri)
    }

    LaunchedEffect(initialUri) {
        if (initialUri != null) viewModel.openPdf(Uri.parse(initialUri))
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PDF Reader") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
                actions = {
                    if (uiState.currentPageBitmap != null) {
                        IconButton(onClick = viewModel::toggleSignatureMode) {
                            Icon(Icons.Filled.Draw, contentDescription = "Sign page")
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
            when {
                uiState.uri == null -> Column {
                    EmptyState(icon = Icons.Filled.PictureAsPdf, title = "No PDF open", subtitle = "Choose a local PDF file to view")
                    Button(onClick = { picker.launch("application/pdf") }, modifier = Modifier.padding(16.dp)) {
                        Text("Choose a PDF")
                    }
                }
                uiState.isLoading -> CircularProgressIndicator()
                uiState.currentPageBitmap != null -> Box(Modifier.fillMaxSize()) {
                    Image(
                        bitmap = uiState.currentPageBitmap!!.asImageBitmap(),
                        contentDescription = "PDF page ${uiState.currentPageIndex + 1}",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize(),
                    )
                    if (uiState.signatureMode) {
                        PdfSignerOverlay(onStrokesChanged = {}, modifier = Modifier.fillMaxSize())
                    }
                    Row(
                        modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(16.dp),
                        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
                    ) {
                        IconButton(onClick = viewModel::previousPage) {
                            Icon(Icons.Filled.ChevronLeft, contentDescription = "Previous page")
                        }
                        Text(
                            "${uiState.currentPageIndex + 1} / ${uiState.pageCount}",
                            modifier = Modifier.align(Alignment.CenterVertically),
                        )
                        IconButton(onClick = viewModel::nextPage) {
                            Icon(Icons.Filled.ChevronRight, contentDescription = "Next page")
                        }
                    }
                }
                uiState.error != null -> Text(uiState.error.orEmpty())
            }
        }
    }
}
