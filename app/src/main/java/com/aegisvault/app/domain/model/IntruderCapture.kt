package com.aegisvault.app.domain.model

data class IntruderCapture(
    val id: Long,
    val storageFileName: String,
    val capturedAtMillis: Long,
)
