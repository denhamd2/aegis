package com.aegisvault.app.data.security

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.ProcessLifecycleOwner
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/**
 * Captures a single front-camera frame headlessly (no preview surface, no UI) and returns it as
 * JPEG bytes — used only for on-device intruder alerts. Never touches the network or MediaStore;
 * callers are responsible for writing the result straight into [EncryptedFileManager].
 */
interface IntruderCaptureService {
    /** Returns null if the CAMERA permission isn't granted or no front camera is available. */
    suspend fun captureFrontCameraJpeg(): ByteArray?
}

@Singleton
class IntruderCaptureServiceImpl @Inject constructor(
    @ApplicationContext private val context: Context,
) : IntruderCaptureService {

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    override suspend fun captureFrontCameraJpeg(): ByteArray? {
        if (!hasCameraPermission()) return null

        val cameraProvider = ProcessCameraProvider.getInstance(context).get()
        // A started (but invisible) lifecycle owner is required to bind use cases; this app
        // process is always running when a PIN failure can happen, so ProcessLifecycleOwner's
        // lifecycle is a safe, always-available owner to bind against.
        val lifecycleOwner = ProcessLifecycleOwner.get()

        val imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build()

        return try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_FRONT_CAMERA, imageCapture)
            takePicture(imageCapture)
        } catch (e: Exception) {
            null
        } finally {
            cameraProvider.unbindAll()
        }
    }

    private suspend fun takePicture(imageCapture: ImageCapture): ByteArray? =
        suspendCancellableCoroutine { continuation ->
            imageCapture.takePicture(
                ContextCompat.getMainExecutor(context),
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        val bytes = image.toJpegBytes()
                        image.close()
                        if (continuation.isActive) continuation.resume(bytes)
                    }

                    override fun onError(exception: ImageCaptureException) {
                        if (continuation.isActive) continuation.resume(null)
                    }
                },
            )
        }

    private fun ImageProxy.toJpegBytes(): ByteArray? {
        val buffer = planes.firstOrNull()?.buffer ?: return null
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        // JPEG output format guarantees the buffer already contains an encoded JPEG (no EXIF/GPS
        // block is written by CameraX for a headless capture like this), so no further encoding
        // or metadata-stripping step is required — see ExifStripper for the vault-media path.
        return bytes
    }
}
