package com.aegisvault.app.domain.model

enum class MediaType { IMAGE, VIDEO }

data class MediaItem(
    val id: Long,
    val contentUri: String,
    val displayName: String,
    val mimeType: String,
    val mediaType: MediaType,
    val dateAdded: Long,
    val sizeBytes: Long,
    val durationMillis: Long? = null,
    val bucketId: Long? = null,
    val bucketDisplayName: String? = null,
)
