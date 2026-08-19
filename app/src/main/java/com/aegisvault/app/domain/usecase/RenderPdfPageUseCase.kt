package com.aegisvault.app.domain.usecase

import android.graphics.Bitmap
import android.net.Uri
import com.aegisvault.app.data.pdf.PdfRendererSource
import javax.inject.Inject

class RenderPdfPageUseCase @Inject constructor(
    private val pdfRendererSource: PdfRendererSource,
) {
    suspend fun open(uri: Uri): Int = pdfRendererSource.open(uri)
    suspend fun renderPage(pageIndex: Int): Bitmap = pdfRendererSource.renderPage(pageIndex)
    fun close() = pdfRendererSource.close()
}
