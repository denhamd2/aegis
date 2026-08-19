package com.aegisvault.app.data.backup

import org.json.JSONArray
import org.json.JSONObject
import java.util.Base64

/**
 * Layout and JSON (de)serialization for the `.aegisvault` archive format:
 *
 * - `header.json` — plaintext, written/read first: KDF parameters needed to derive the key.
 * - `manifest.enc` — AES-GCM ciphertext of a JSON array of item metadata.
 * - `items/<uuid>.enc` — one AES-GCM ciphertext per vault item's decrypted bytes.
 *
 * Uses `org.json` (bundled with Android, zero new Gradle dependency) since the codebase has
 * no JSON library today and the shapes here are small.
 */
object VaultArchiveFormat {
    const val FORMAT_VERSION = 1
    const val HEADER_ENTRY = "header.json"
    const val MANIFEST_ENTRY = "manifest.enc"
    const val ITEMS_DIR = "items"
    const val KDF_NAME = "PBKDF2WithHmacSHA256"

    data class ArchiveHeader(
        val formatVersion: Int,
        val iterations: Int,
        val salt: ByteArray,
        val keyLengthBits: Int,
    )

    data class ManifestEntry(
        val archiveEntry: String,
        val originalDisplayName: String,
        val mimeType: String,
        val mediaType: String,
        val sizeBytes: Long,
        val dateAdded: Long,
    )

    fun writeHeader(header: ArchiveHeader): ByteArray = JSONObject().apply {
        put("formatVersion", header.formatVersion)
        put("kdf", KDF_NAME)
        put("iterations", header.iterations)
        put("saltBase64", Base64.getEncoder().encodeToString(header.salt))
        put("keyLengthBits", header.keyLengthBits)
    }.toString().toByteArray(Charsets.UTF_8)

    fun readHeader(bytes: ByteArray): ArchiveHeader {
        val json = JSONObject(String(bytes, Charsets.UTF_8))
        return ArchiveHeader(
            formatVersion = json.getInt("formatVersion"),
            iterations = json.getInt("iterations"),
            salt = Base64.getDecoder().decode(json.getString("saltBase64")),
            keyLengthBits = json.getInt("keyLengthBits"),
        )
    }

    fun writeManifest(entries: List<ManifestEntry>): ByteArray {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(
                JSONObject().apply {
                    put("archiveEntry", entry.archiveEntry)
                    put("originalDisplayName", entry.originalDisplayName)
                    put("mimeType", entry.mimeType)
                    put("mediaType", entry.mediaType)
                    put("sizeBytes", entry.sizeBytes)
                    put("dateAdded", entry.dateAdded)
                },
            )
        }
        return array.toString().toByteArray(Charsets.UTF_8)
    }

    fun readManifest(bytes: ByteArray): List<ManifestEntry> {
        val array = JSONArray(String(bytes, Charsets.UTF_8))
        return (0 until array.length()).map { i ->
            val obj = array.getJSONObject(i)
            ManifestEntry(
                archiveEntry = obj.getString("archiveEntry"),
                originalDisplayName = obj.getString("originalDisplayName"),
                mimeType = obj.getString("mimeType"),
                mediaType = obj.getString("mediaType"),
                sizeBytes = obj.getLong("sizeBytes"),
                dateAdded = obj.getLong("dateAdded"),
            )
        }
    }
}
