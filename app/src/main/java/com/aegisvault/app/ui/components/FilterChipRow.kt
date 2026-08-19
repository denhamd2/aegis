package com.aegisvault.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aegisvault.app.domain.model.MediaFilter

@Composable
fun FilterChipRow(
    selected: MediaFilter,
    onSelected: (MediaFilter) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(MediaFilter.entries) { filter ->
            FilterChip(
                selected = filter == selected,
                onClick = { onSelected(filter) },
                label = { Text(filter.label()) },
                colors = FilterChipDefaults.filterChipColors(),
            )
        }
    }
}

private fun MediaFilter.label(): String = when (this) {
    MediaFilter.ALL -> "All"
    MediaFilter.PHOTOS -> "Photos"
    MediaFilter.VIDEOS -> "Videos"
    MediaFilter.ALBUMS -> "Albums"
}
