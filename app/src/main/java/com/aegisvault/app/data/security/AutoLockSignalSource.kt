package com.aegisvault.app.data.security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.inject.Inject
import javax.inject.Singleton

/** A reason the vault should be locked, other than the process backgrounding. */
sealed interface AutoLockTrigger {
    data object ScreenOff : AutoLockTrigger
    data object FaceDown : AutoLockTrigger
}

/**
 * Emits [AutoLockTrigger]s from device signals (screen-off, face-down orientation). Both signals
 * are read entirely on-device via `BroadcastReceiver`/`SensorManager` — no network involved.
 */
interface AutoLockSignalSource {
    fun observeScreenOff(): Flow<AutoLockTrigger>
    fun observeFaceDown(): Flow<AutoLockTrigger>
}

@Singleton
class AutoLockSignalSourceImpl @Inject constructor(
    @ApplicationContext private val context: Context,
) : AutoLockSignalSource {

    private companion object {
        // Gravity's z-component points toward the sky when the device lies face-up; a value near
        // -9.8 means the screen is facing the ground.
        const val FACE_DOWN_Z_THRESHOLD = -9.0f
    }

    override fun observeScreenOff(): Flow<AutoLockTrigger> = callbackFlow {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(receivedContext: Context?, intent: Intent?) {
                trySend(AutoLockTrigger.ScreenOff)
            }
        }
        context.registerReceiver(receiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        awaitClose { context.unregisterReceiver(receiver) }
    }

    override fun observeFaceDown(): Flow<AutoLockTrigger> = callbackFlow {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
        if (sensorManager == null || gravitySensor == null) {
            awaitClose { }
            return@callbackFlow
        }

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.values[2] < FACE_DOWN_Z_THRESHOLD) trySend(AutoLockTrigger.FaceDown)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        sensorManager.registerListener(listener, gravitySensor, SensorManager.SENSOR_DELAY_NORMAL)
        awaitClose { sensorManager.unregisterListener(listener) }
    }
}
