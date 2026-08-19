package com.aegisvault.app.ui.screens.security

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.aegisvault.app.domain.model.IntruderCapture
import java.text.DateFormat
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IntruderLogScreen(
    onBack: () -> Unit,
    viewModel: IntruderLogViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Intruder log") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
                actions = {
                    if (uiState.captures.isNotEmpty()) {
                        IconButton(onClick = viewModel::clearAll) {
                            Icon(Icons.Filled.DeleteSweep, contentDescription = "Clear all")
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        if (uiState.captures.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                Text(
                    "No intruder captures yet. Turn on Intruder alerts in Settings to start recording failed unlock attempts.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(32.dp),
                )
            }
            return@Scaffold
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            items(uiState.captures, key = { it.id }) { capture ->
                LaunchedEffect(capture.id) { viewModel.ensureDecrypted(capture) }
                IntruderCaptureCell(
                    capture = capture,
                    bytes = uiState.decryptedPhotos[capture.id],
                    onDelete = { viewModel.delete(capture) },
                )
            }
        }
    }
}

@Composable
private fun IntruderCaptureCell(capture: IntruderCapture, bytes: ByteArray?, onDelete: () -> Unit) {
    Box(modifier = Modifier.aspectRatio(1f)) {
        if (bytes != null) {
            val bitmap = remember(capture.id, bytes) {
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImageBitmap()
            }
            Image(
                bitmap = bitmap,
                contentDescription = "Intruder photo captured ${DateFormat.getDateTimeInstance().format(Date(capture.capturedAtMillis))}",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }

        Text(
            DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT).format(Date(capture.capturedAtMillis)),
            style = MaterialTheme.typography.labelSmall,
            color = Color.White,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .background(Color.Black.copy(alpha = 0.5f))
                .padding(4.dp),
        )

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(4.dp)
                .background(Color.Black.copy(alpha = 0.4f), RoundedCornerShape(50))
                .clickable(onClick = onDelete),
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Delete this capture",
                tint = Color.White,
                modifier = Modifier.padding(4.dp),
            )
        }
    }
}
