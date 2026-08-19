package com.aegisvault.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aegisvault.app.util.Constants

/** A 6-digit numeric keypad + progress dots, used for both PIN entry and PIN setup. */
@Composable
fun PinEntryPad(
    pinLength: Int,
    errorMessage: String?,
    onDigit: (Char) -> Unit,
    onBackspace: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(bottom = 16.dp)) {
            repeat(Constants.PIN_LENGTH) { index ->
                Surface(
                    shape = CircleShape,
                    color = if (index < pinLength) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.size(14.dp),
                ) {}
            }
        }

        if (errorMessage != null) {
            Text(
                errorMessage,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(bottom = 12.dp),
            )
        }

        val rows = listOf("123", "456", "789", " 0⌫")
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(vertical = 6.dp)) {
                row.forEach { char ->
                    when {
                        char == ' ' -> Surface(modifier = Modifier.size(64.dp), color = MaterialTheme.colorScheme.background) {}
                        char == '⌫' -> OutlinedButton(onClick = onBackspace, modifier = Modifier.size(64.dp)) { Text("⌫") }
                        else -> Button(onClick = { onDigit(char) }, modifier = Modifier.size(64.dp)) { Text(char.toString()) }
                    }
                }
            }
        }
    }
}
