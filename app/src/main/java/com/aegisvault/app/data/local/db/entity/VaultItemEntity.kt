package com.aegisvault.app.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class MediaTypeEntity { IMAGE, VIDEO }

@Entity(tableName = "vault_items")
data class VaultItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val storageFileName: String,
    val originalDisplayName: String,
    val mimeType: String,
    val mediaType: MediaTypeEntity,
    val sizeBytes: Long,
    val dateAdded: Long,
)
