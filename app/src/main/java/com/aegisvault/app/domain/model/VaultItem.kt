package com.aegisvault.app.domain.model

data class VaultItem(
    val id: Long,
    val storageFileName: String,
    val originalDisplayName: String,
    val mimeType: String,
    val mediaType: MediaType,
    val sizeBytes: Long,
    val dateAdded: Long,
)
