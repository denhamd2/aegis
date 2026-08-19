package com.aegisvault.app.ui.components

import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aegisvault.app.domain.model.MediaItem

/** Masonry-style grid over device media using Compose's native staggered grid. */
@Composable
fun MasonryGrid(
    items: List<MediaItem>,
    selectedIds: Set<Long>,
    selectionModeActive: Boolean,
    onItemClick: (MediaItem) -> Unit,
    onItemLongClick: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
    pendingRemovalIds: Set<Long> = emptySet(),
) {
    LazyVerticalStaggeredGrid(
        columns = StaggeredGridCells.Adaptive(minSize = 110.dp),
        modifier = modifier,
        verticalItemSpacing = 4.dp,
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(4.dp),
    ) {
        items(items, key = { it.id }) { item ->
            MediaGridItem(
                item = item,
                isSelected = selectedIds.contains(item.id),
                selectionModeActive = selectionModeActive,
                isPendingRemoval = pendingRemovalIds.contains(item.id),
                onClick = { onItemClick(item) },
                onLongClick = { onItemLongClick(item) },
            )
        }
    }
}
