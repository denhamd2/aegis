package com.aegisvault.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * The Aegis brand mark: a bold "A" whose counter carries a keyhole cut into it — the word
 * "Aegis" made literal in the glyph rather than a separate pictorial icon bolted onto it.
 * Same shape as res/drawable/ic_launcher_foreground.xml; keep the two in sync if this changes.
 */
@Composable
fun BrandMark(
    modifier: Modifier = Modifier,
    size: Dp = 24.dp,
    legColor: Color = MaterialTheme.colorScheme.onSurface,
    keyholeColor: Color = MaterialTheme.colorScheme.primary,
) {
    Canvas(modifier = modifier.size(size)) {
        drawBrandMark(this.size.minDimension, legColor, keyholeColor)
    }
}

/** A screen's top-bar title, prefixed with the small [BrandMark] — the app's usual pattern
 * for carrying the Aegis mark into the main screens without repeating the full wordmark. */
@Composable
fun BrandedTitle(text: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        BrandMark(size = 22.dp)
        Text(text)
    }
}

private fun DrawScope.drawBrandMark(pxSize: Float, legColor: Color, keyholeColor: Color) {
    fun pt(x: Float, y: Float) = Offset(x / 100f * pxSize, y / 100f * pxSize)

    val leftLeg = Path().apply {
        moveTo(pt(50f, 8f).x, pt(50f, 8f).y)
        lineTo(pt(54f, 8f).x, pt(54f, 8f).y)
        lineTo(pt(30f, 92f).x, pt(30f, 92f).y)
        lineTo(pt(14f, 92f).x, pt(14f, 92f).y)
        close()
    }
    val rightLeg = Path().apply {
        moveTo(pt(50f, 8f).x, pt(50f, 8f).y)
        lineTo(pt(46f, 8f).x, pt(46f, 8f).y)
        lineTo(pt(70f, 92f).x, pt(70f, 92f).y)
        lineTo(pt(86f, 92f).x, pt(86f, 92f).y)
        close()
    }
    val keyholeShaft = Path().apply {
        moveTo(pt(45f, 60f).x, pt(45f, 60f).y)
        lineTo(pt(55f, 60f).x, pt(55f, 60f).y)
        lineTo(pt(52f, 78f).x, pt(52f, 78f).y)
        lineTo(pt(48f, 78f).x, pt(48f, 78f).y)
        close()
    }

    drawPath(leftLeg, color = legColor)
    drawPath(rightLeg, color = legColor)
    drawCircle(color = keyholeColor, radius = 9f / 100f * pxSize, center = pt(50f, 55f))
    drawPath(keyholeShaft, color = keyholeColor)
}
