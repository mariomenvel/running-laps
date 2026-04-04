package com.runninglaps.wear

data class WearTemplateAlerts(
    val enabled: Boolean = false,
    val mode: String = "time",      // "time" | "pace"
    val timeMin: Int = 0,
    val timeSec: Double = 0.0,       // 0.0 .. 59.5 step 0.5
    val paceMin: Int = 4,
    val paceSec: Int = 0,            // actual seconds 0-59
    val segmentDistance: Int = 300,  // actual meters, e.g. 300, 400
)

data class WearTemplateBlock(
    val id: Int = 0,
    val order: Int = 0,
    val type: String = "distance",   // "distance" | "time"
    val value: Int = 400,            // meters for distance, seconds for time
    val restSeconds: Int = 60,
    val alerts: WearTemplateAlerts = WearTemplateAlerts(),
)

data class WearTemplate(
    val id: String = "",
    val name: String = "",
    val blocks: List<WearTemplateBlock> = emptyList(),
    val colorValue: Long = 0xFF9C27B0L,
)

fun parseTemplateFromFirestore(id: String, data: Map<String, Any>): WearTemplate {
    val name = data["name"] as? String ?: ""
    val colorValue: Long = when (val cv = data["colorValue"]) {
        is Long -> cv
        is Int  -> cv.toLong()
        else    -> 0xFF9C27B0L
    }
    val rawBlocks = data["blocks"] as? List<*> ?: emptyList<Any>()
    val blocks = rawBlocks.mapIndexedNotNull { idx, raw ->
        @Suppress("UNCHECKED_CAST")
        val b = raw as? Map<String, Any> ?: return@mapIndexedNotNull null

        @Suppress("UNCHECKED_CAST")
        val alertsMap = b["alerts"] as? Map<String, Any>
        val alerts = if (alertsMap != null) {
            WearTemplateAlerts(
                enabled         = alertsMap["enabled"] as? Boolean ?: false,
                mode            = alertsMap["mode"] as? String ?: "time",
                timeMin         = (alertsMap["timeMin"] as? Long)?.toInt() ?: 0,
                timeSec         = when (val ts = alertsMap["timeSec"]) {
                    is Double -> ts
                    is Long   -> ts.toDouble()
                    else      -> 0.0
                },
                paceMin         = (alertsMap["paceMin"] as? Long)?.toInt() ?: 4,
                paceSec         = (alertsMap["paceSec"] as? Long)?.toInt() ?: 0,
                segmentDistance = (alertsMap["segmentDistance"] as? Long)?.toInt() ?: 300,
            )
        } else WearTemplateAlerts()

        WearTemplateBlock(
            id          = idx,
            order       = (b["order"] as? Long)?.toInt() ?: idx,
            type        = b["type"] as? String ?: "distance",
            value       = (b["value"] as? Long)?.toInt() ?: 400,
            restSeconds = (b["restSeconds"] as? Long)?.toInt() ?: 60,
            alerts      = alerts,
        )
    }
    return WearTemplate(id = id, name = name, blocks = blocks, colorValue = colorValue)
}
