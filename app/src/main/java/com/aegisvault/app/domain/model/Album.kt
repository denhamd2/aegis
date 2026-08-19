package com.aegisvault.app.domain.model

data class Album(
    val bucketId: Long,
    val displayName: String,
    val coverContentUri: String,
    val itemCount: Int,
)
