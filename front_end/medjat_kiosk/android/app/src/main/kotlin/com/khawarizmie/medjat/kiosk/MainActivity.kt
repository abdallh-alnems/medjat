package com.khawarizmie.medjat.kiosk

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Kiosk lockdown.
 *
 * Uses **screen pinning** (lock task), deliberately not `DEVICE_ADMIN`. Device
 * admin would attract Play policy scrutiny and demand an enrolment flow, and it
 * buys nothing here: pinning already stops an employee reaching Settings, a
 * browser, or another app, which is the whole requirement.
 *
 * Worth being precise about what this does and does not guarantee.
 * `startLockTask()` on a device that has NOT been provisioned as a device owner
 * shows a one-time system confirmation and can still be exited with the
 * platform gesture — so it is a strong deterrent, not a cage. Making it a cage
 * requires provisioning the tablet as a device owner, which is a decision for
 * whoever deploys the hardware and not something an app can or should seize for
 * itself. The application-level guard is the one that always holds: leaving
 * kiosk mode from inside the app costs an administrator-generated access code.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "medjat.kiosk/lock"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // A wall-mounted tablet must not sleep mid-shift: nobody should have to
        // wake a screen before they can clock in.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterKioskMode" -> result.success(enterKioskMode())
                    "exitKioskMode" -> result.success(exitKioskMode())
                    "isLocked" -> result.success(isLocked())
                    else -> result.notImplemented()
                }
            }
    }

    private fun enterKioskMode(): Boolean = try {
        if (!isLocked()) startLockTask()
        true
    } catch (e: Exception) {
        // Pinning can be refused by the OS or unavailable on a stripped build.
        // The kiosk still works — it is simply easier to navigate away from —
        // so this reports failure rather than crashing a device on a wall.
        android.util.Log.w("MedjatKiosk", "startLockTask failed", e)
        false
    }

    private fun exitKioskMode(): Boolean = try {
        if (isLocked()) stopLockTask()
        true
    } catch (e: Exception) {
        android.util.Log.w("MedjatKiosk", "stopLockTask failed", e)
        false
    }

    private fun isLocked(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            am.isInLockTaskMode
        }
    }

    /**
     * A kiosk has no back stack — there is nothing behind the identification
     * screen except the launcher — so the back gesture is swallowed rather than
     * allowed to drop an employee onto the home screen.
     */
    @Deprecated("Retained deliberately: swallowing back is the point")
    override fun onBackPressed() {
        // Intentionally empty.
    }
}
