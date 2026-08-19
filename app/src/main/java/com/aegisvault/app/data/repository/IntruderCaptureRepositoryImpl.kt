package com.aegisvault.app.data.repository

import com.aegisvault.app.data.local.db.dao.IntruderCaptureDao
import com.aegisvault.app.data.local.db.entity.IntruderCaptureEntity
import com.aegisvault.app.data.security.EncryptedFileManager
import com.aegisvault.app.domain.model.IntruderCapture
import com.aegisvault.app.domain.repository.IntruderCaptureRepository
import com.aegisvault.app.util.Constants
import com.aegisvault.app.util.IoDispatcher
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class IntruderCaptureRepositoryImpl @Inject constructor(
    private val dao: IntruderCaptureDao,
    private val encryptedFileManager: EncryptedFileManager,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : IntruderCaptureRepository {

    override fun observeAll(): Flow<List<IntruderCapture>> = dao.observeAll().map { list -> list.map { it.toDomain() } }

    override suspend fun record(jpegBytes: ByteArray) = withContext(ioDispatcher) {
        val storageFileName = "intruder_${UUID.randomUUID()}.enc"
        encryptedFileManager.encryptBytes(jpegBytes, storageFileName)
        dao.insert(IntruderCaptureEntity(storageFileName = storageFileName, capturedAtMillis = System.currentTimeMillis()))
        // Bound storage growth from repeated lockouts — keep only the most recent N captures.
        dao.beyond(Constants.MAX_INTRUDER_CAPTURES).forEach { stale ->
            encryptedFileManager.delete(stale.storageFileName)
            dao.deleteById(stale.id)
        }
    }

    override suspend fun delete(capture: IntruderCapture) = withContext(ioDispatcher) {
        encryptedFileManager.delete(capture.storageFileName)
        dao.deleteById(capture.id)
    }

    override suspend fun deleteAll() = withContext(ioDispatcher) {
        dao.getAll().forEach { encryptedFileManager.delete(it.storageFileName) }
        dao.deleteAll()
    }

    override suspend fun decrypt(capture: IntruderCapture): ByteArray =
        encryptedFileManager.decryptToBytes(capture.storageFileName)

    private fun IntruderCaptureEntity.toDomain() = IntruderCapture(
        id = id,
        storageFileName = storageFileName,
        capturedAtMillis = capturedAtMillis,
    )
}
