package com.aegisvault.app.domain.usecase

import android.net.Uri
import com.aegisvault.app.data.exif.ExifStripper
import com.aegisvault.app.domain.model.MediaType
import com.aegisvault.app.domain.model.VaultItem
import com.aegisvault.app.domain.repository.VaultRepository
import javax.inject.Inject

/**
 * Decrypts a vault item and stages it in the shared cache for an ACTION_SEND intent. EXIF
 * stripping is always-on here (unlike the Gallery bulk-share flow's optional setting) since
 * vault items are the user's most sensitive content — there is no separate opt-out.
 */
class ShareVaultItemUseCase @Inject constructor(
    private val vaultRepository: VaultRepository,
    private val exifStripper: ExifStripper,
) {
    suspend operator fun invoke(item: VaultItem): Uri {
        val bytes = vaultRepository.decrypt(item)
        return if (item.mediaType == MediaType.IMAGE) {
            exifStripper.stripBytesToCache(bytes, item.originalDisplayName)
        } else {
            // EXIF stripping doesn't apply to video — copy through unmodified, same as the
            // Gallery bulk-share flow's IMAGE/else branch.
            exifStripper.copyBytesToCache(bytes, item.originalDisplayName)
        }
    }
}
