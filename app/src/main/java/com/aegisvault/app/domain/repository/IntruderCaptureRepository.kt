package com.aegisvault.app.domain.repository

import com.aegisvault.app.domain.model.IntruderCapture
import kotlinx.coroutines.flow.Flow

interface IntruderCaptureRepository {
    fun observeAll(): Flow<List<IntruderCapture>>

    /** Encrypts [jpegBytes] and records a capture, then prunes anything beyond the retention cap. */
    suspend fun record(jpegBytes: ByteArray)
    suspend fun delete(capture: IntruderCapture)
    suspend fun deleteAll()
    suspend fun decrypt(capture: IntruderCapture): ByteArray
}
