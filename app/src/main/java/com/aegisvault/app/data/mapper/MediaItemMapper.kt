package com.aegisvault.app.data.mapper

import com.aegisvault.app.data.local.db.entity.MediaTypeEntity
import com.aegisvault.app.data.local.db.entity.VaultItemEntity
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem

fun VaultItemEntity.toDomain(): VaultItem = VaultItem(
    id = id,
    storageFileName = storageFileName,
    originalDisplayName = originalDisplayName,
    mimeType = mimeType,
    mediaType = mediaType.toDomain(),
    sizeBytes = sizeBytes,
    dateAdded = dateAdded,
)

fun VaultItem.toEntity(): VaultItemEntity = VaultItemEntity(
    id = id,
    storageFileName = storageFileName,
    originalDisplayName = originalDisplayName,
    mimeType = mimeType,
    mediaType = mediaType.toEntity(),
    sizeBytes = sizeBytes,
    dateAdded = dateAdded,
)

fun MediaTypeEntity.toDomain(): MediaType = when (this) {
    MediaTypeEntity.IMAGE -> MediaType.IMAGE
    MediaTypeEntity.VIDEO -> MediaType.VIDEO
}

fun MediaType.toEntity(): MediaTypeEntity = when (this) {
    MediaType.IMAGE -> MediaTypeEntity.IMAGE
    MediaType.VIDEO -> MediaTypeEntity.VIDEO
}
