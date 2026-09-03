package com.khawarizmie.medjat.kiosk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings the kiosk back after a power cut (FR-023).
 *
 * A branch tablet is mounted on a wall and nobody stands in front of it at
 * 6 a.m. to unlock a phone and tap an icon. If it does not return on its own,
 * the first shift of the day silently has no way to clock in and the branch
 * discovers it only when someone complains.
 *
 * This launches the activity; it does not re-enter screen pinning. Android will
 * not let an app pin itself from a boot broadcast, and it should not — a
 * supervisor re-pins from the kiosk's own screen, which also confirms a human
 * saw the tablet come back.
 */
class KioskBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(launch)
    }
}
