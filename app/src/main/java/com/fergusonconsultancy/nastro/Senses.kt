package com.fergusonconsultancy.nastro

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

/**
 * What the phone can feel besides tilt (24 Nov 2026): how far its hinge is open, and how bright the
 * room is. The hinge angle tells a phone stood half open on a table (the tabletop deck); the room's
 * light backlights the keys after dark and sharpens their engraving in sunlight.
 */
object Senses : SensorEventListener {
    /** The hinge's angle in degrees: 180 flat open, 0 shut. Null until the phone reports one. */
    var hinge: Float? = null; private set
    /** The room's light in lux, as last reported. Null on a phone without the sensor. */
    var lux: Float? = null; private set
    private var sm: SensorManager? = null
    private var onHinge: (() -> Unit)? = null
    private var onLux: (() -> Unit)? = null

    fun start(ctx: Context, hingeChanged: () -> Unit, luxChanged: () -> Unit) {
        val m = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        sm = m; onHinge = hingeChanged; onLux = luxChanged
        m.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)?.let { m.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        m.getDefaultSensor(Sensor.TYPE_LIGHT)?.let { m.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    fun stop() { sm?.unregisterListener(this); sm = null; onHinge = null; onLux = null }

    override fun onSensorChanged(e: SensorEvent) {
        when (e.sensor.type) {
            Sensor.TYPE_HINGE_ANGLE -> { hinge = e.values[0]; onHinge?.invoke() }
            Sensor.TYPE_LIGHT -> { lux = e.values[0]; onLux?.invoke() }
        }
    }

    override fun onAccuracyChanged(s: Sensor?, a: Int) {}
}
