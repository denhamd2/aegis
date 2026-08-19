package com.aegisvault.app.data.security

import androidx.security.crypto.MasterKey
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.aegisvault.app.util.IoDispatcherStub
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Exercises the real AndroidKeyStore-backed EncryptedFile round trip. Requires a device or
 * emulator (AndroidKeyStore is unavailable to plain JVM unit tests), so this cannot run in a
 * headless sandbox without an Android SDK/emulator image.
 */
@RunWith(AndroidJUnit4::class)
class VaultRepositoryInstrumentedTest {

    @Test
    fun encryptedFileManager_roundTripsBytesThroughAndroidKeyStore() = runTest {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        val manager = EncryptedFileManager(context, masterKey, IoDispatcherStub.dispatcher)

        val sourceBytes = "aegis-vault-test-payload".toByteArray()
        val tempFile = File.createTempFile("aegis_test_source", ".bin", context.cacheDir)
        tempFile.writeBytes(sourceBytes)
        val sourceUri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", tempFile)

        val storageFileName = "vault_test_${System.currentTimeMillis()}.enc"
        manager.encryptContentUri(sourceUri, storageFileName)
        val decrypted = manager.decryptToBytes(storageFileName)

        assertArrayEquals(sourceBytes, decrypted)

        manager.delete(storageFileName)
        tempFile.delete()
    }
}
