package com.aegisvault.app.ui.screens.security

import android.content.pm.PackageManager
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

private data class OfflineCheck(val label: String, val detail: String, val passed: Boolean)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VerifyOfflineScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var permissionCheck by remember { mutableStateOf<OfflineCheck?>(null) }
    var liveCheck by remember { mutableStateOf<OfflineCheck?>(null) }
    var isRunningLiveCheck by remember { mutableStateOf(false) }
    var liveCheckRunCount by remember { mutableStateOf(0) }

    LaunchedEffect(Unit) {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        val requestsInternet = packageInfo.requestedPermissions?.contains(android.Manifest.permission.INTERNET) == true
        permissionCheck = OfflineCheck(
            label = "Requested permissions",
            detail = if (requestsInternet) {
                "This app has requested android.permission.INTERNET — that shouldn't be possible."
            } else {
                "This app has never requested android.permission.INTERNET. This is a fact reported by Android itself, not by this app."
            },
            passed = !requestsInternet,
        )
    }

    suspend fun runLiveCheck() {
        isRunningLiveCheck = true
        liveCheck = withContext(Dispatchers.IO) {
            try {
                (URL("https://example.com").openConnection() as HttpURLConnection).apply {
                    connectTimeout = 3000
                    connect()
                    disconnect()
                }
                OfflineCheck(
                    label = "Live network attempt",
                    detail = "A network call actually succeeded. This should never happen — please report this.",
                    passed = false,
                )
            } catch (e: SecurityException) {
                OfflineCheck(
                    label = "Live network attempt",
                    detail = "Android blocked the attempt: ${e.message ?: "Permission denied (missing INTERNET permission)"}",
                    passed = true,
                )
            } catch (e: Exception) {
                OfflineCheck(
                    label = "Live network attempt",
                    detail = "The attempt failed with ${e::class.simpleName}: ${e.message}. Network access is not available to this app.",
                    passed = true,
                )
            }
        }
        isRunningLiveCheck = false
    }

    LaunchedEffect(liveCheckRunCount) { runLiveCheck() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Verify we're offline") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, contentDescription = "Back") }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding).padding(16.dp)) {
            Text(
                "Two independent proofs that Aegis Vault cannot send your data anywhere.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            permissionCheck?.let { CheckCard(it, modifier = Modifier.padding(top = 20.dp)) }

            Column(modifier = Modifier.padding(top = 12.dp)) {
                if (isRunningLiveCheck && liveCheck == null) {
                    Row(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                        CircularProgressIndicator(modifier = Modifier.padding(end = 12.dp))
                        Text("Attempting a network call...")
                    }
                } else {
                    liveCheck?.let { CheckCard(it) }
                }
            }

            Button(
                onClick = { liveCheck = null; liveCheckRunCount++ },
                modifier = Modifier.padding(top = 20.dp),
                enabled = !isRunningLiveCheck,
            ) { Text("Run the live check again") }
        }
    }
}

@Composable
private fun CheckCard(check: OfflineCheck, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 1.dp,
    ) {
        Row(modifier = Modifier.padding(16.dp)) {
            Icon(
                imageVector = if (check.passed) Icons.Filled.CheckCircle else Icons.Filled.Error,
                contentDescription = null,
                tint = if (check.passed) Color(0xFF3F6B4F) else MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(end = 12.dp),
            )
            Column {
                Text(check.label, style = MaterialTheme.typography.titleMedium)
                Text(
                    check.detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
