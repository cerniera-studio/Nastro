package com.fergusonconsultancy.nastro

import android.content.Context
import android.content.SharedPreferences

/** Everything behind the battery door. */
object Prefs {
    private lateinit var sp: SharedPreferences
    private val listeners = mutableListOf<() -> Unit>()

    fun init(ctx: Context) {
        if (!::sp.isInitialized) sp = ctx.applicationContext.getSharedPreferences("settings", Context.MODE_PRIVATE)
    }

    fun listen(l: () -> Unit) { listeners += l }
    fun unlisten(l: () -> Unit) { listeners -= l }
    private fun changed() = listeners.toList().forEach { it() }

    private fun b(k: String, d: Boolean) = if (::sp.isInitialized) sp.getBoolean(k, d) else d
    private fun s(k: String, d: String) = if (::sp.isInitialized) sp.getString(k, d) ?: d else d
    private fun i(k: String, d: Int) = if (::sp.isInitialized) sp.getInt(k, d) else d
    private fun put(k: String, v: Any) {
        val e = sp.edit()
        when (v) { is Boolean -> e.putBoolean(k, v); is String -> e.putString(k, v); is Int -> e.putInt(k, v) }
        e.apply(); changed()
    }

    /** visconti (the default) is the Alfa green; blue and grey were the WM-EX610's own; graphite and rosso are ours. */
    var finish: String get() = s("finish", "visconti"); set(v) = put("finish", v)
    var sounds: Boolean get() = b("sounds", true); set(v) = put("sounds", v)
    var hiss: Boolean get() = b("hiss", false); set(v) = put("hiss", v)
    /** Fast wind: 30 is the machine's own speed. */
    var windX: Int get() = i("windX", 30); set(v) = put("windX", v)
    var concentrato: Boolean get() = b("concentrato", true); set(v) = put("concentrato", v)
    var doorSwing: Boolean get() = b("doorSwing", true); set(v) = put("doorSwing", v)
    var haptics: Boolean get() = b("haptics", true); set(v) = put("haptics", v)
    var singles: Boolean get() = b("singles", true); set(v) = put("singles", v)
    /**
     * How big the tape can be drawn, as a fraction of its real size, on each screen's upright
     * layout (14 Nov 2026). The two screens share the smaller, so the tape behind the cover's lens
     * and the tape in the open compartment are the same physical size, as one tape would be.
     */
    fun fit(screen: String): Float = if (::sp.isInitialized) sp.getFloat("fitpx_$screen", 0f) else 0f
    fun setFit(screen: String, v: Float) {
        if (!::sp.isInitialized || kotlin.math.abs(fit(screen) - v) < 0.01f) return
        sp.edit().putFloat("fitpx_$screen", v).apply()
    }

    /**
     * Where the tape sits in the open compartment, in pixels from the crease and from the top (14 Nov
     * 2026): folded, the door lies over the compartment, so the tape behind the cover's lens sits on
     * the same spot.
     */
    fun anchor(): Pair<Float, Float>? = if (::sp.isInitialized && sp.contains("anchorX")) sp.getFloat("anchorX", 0f) to sp.getFloat("anchorY", 0f) else null
    fun setAnchor(x: Float, y: Float) {
        if (!::sp.isInitialized) return
        val a = anchor()
        if (a != null && kotlin.math.abs(a.first - x) < 1f && kotlin.math.abs(a.second - y) < 1f) return
        sp.edit().putFloat("anchorX", x).putFloat("anchorY", y).apply()
    }

    /**
     * The tape's size and place, shared between the two screens (28 Nov 2026). Mechack: the cover's tape
     * is as big as the cover allows, and the open compartment's tape follows it. Pixels can't be shared
     * (the screens differ in density, and the main screen's reported density isn't trusted), so each is
     * kept as a fraction of the screen's height, on the assumption that the cover and the inner screen
     * are about the same height on the phone. coverK: the cover's px per mm over its height; coverCy:
     * where the cover's tape centre sits down the screen; mainMax: the largest px per mm the open
     * compartment has room for, over its height, so the cover never draws a tape the open phone can't match.
     */
    fun tapeF(key: String): Float = if (::sp.isInitialized) sp.getFloat("tape_$key", 0f) else 0f
    fun setTapeF(key: String, v: Float) {
        if (!::sp.isInitialized || v <= 0f) return
        val old = tapeF(key)
        if (old > 0f && kotlin.math.abs(old - v) <= old * 0.002f) return
        sp.edit().putFloat("tape_$key", v).apply()
    }

    /** artist, album or newest */
    var order: String get() = s("order", "artist"); set(v) = put("order", v)
}
