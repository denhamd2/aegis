package com.aegisvault.app.data.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import com.aegisvault.app.util.IoDispatcher
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * Wraps android.graphics.pdf.PdfRenderer. Not thread-safe: all calls are confined to
 * [ioDispatcher] and pages are always closed before the next one is opened.
 */
class PdfRendererSource @Inject constructor(
    @ApplicationContext private val context: Context,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    private var fileDescriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null

    suspend fun open(uri: Uri): Int = withContext(ioDispatcher) {
        close()
        val pfd = context.contentResolver.openFileDescriptor(uri, "r") ?: error("Cannot open $uri")
        fileDescriptor = pfd
        val newRenderer = PdfRenderer(pfd)
        renderer = newRenderer
        newRenderer.pageCount
    }

    suspend fun renderPage(pageIndex: Int, scale: Int = 2): Bitmap = withContext(ioDispatcher) {
        val currentRenderer = renderer ?: error("PdfRenderer not open; call open() first")
        currentRenderer.openPage(pageIndex).use { page ->
            val bitmap = Bitmap.createBitmap(page.width * scale, page.height * scale, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            bitmap
        }
    }

    fun close() {
        renderer?.close()
        renderer = null
        fileDescriptor?.close()
        fileDescriptor = null
    }
}
