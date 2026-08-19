package com.aegisvault.app.ui.screens.utilities.pdf

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput

/**
 * Freehand signature capture drawn atop the current PDF page render. Since
 * android.graphics.pdf.PdfRenderer is read-only, the signature is composited into an exported
 * raster image of the signed page rather than written back into the PDF's page content stream.
 */
@Composable
fun PdfSignerOverlay(
    onStrokesChanged: (List<Path>) -> Unit,
    modifier: Modifier = Modifier,
) {
    var currentPath by remember { mutableStateOf(Path()) }
    val strokes = remember { mutableListOf<Path>() }

    Canvas(
        modifier = modifier.fillMaxSize().pointerInput(Unit) {
            detectDragGestures(
                onDragStart = { offset ->
                    currentPath = Path().apply { moveTo(offset.x, offset.y) }
                },
                onDrag = { change, _ ->
                    currentPath.lineTo(change.position.x, change.position.y)
                    change.consume()
                },
                onDragEnd = {
                    strokes.add(currentPath)
                    onStrokesChanged(strokes.toList())
                },
            )
        },
    ) {
        strokes.forEach { path ->
            drawPath(path, color = Color(0xFF1565C0), style = Stroke(width = 5f))
        }
        drawPath(currentPath, color = Color(0xFF1565C0), style = Stroke(width = 5f))
    }
}
