package com.biolearn.biology_app_v2

import android.content.Context
import android.util.Log
import android.view.View
import android.os.Handler
import android.os.Looper
import com.my.target.ads.MyTargetView
import com.my.target.common.MyTargetManager
import com.my.target.common.models.IAdLoadingError
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MyTargetBannerPlatformView(
    private val context: Context,
    creationParams: Map<String, Any>?
) : PlatformView {

    private val adView: MyTargetView = MyTargetView(context).apply {
        // Disable internal scrolling to show full ad content at once
        isVerticalScrollBarEnabled = false
        isHorizontalScrollBarEnabled = false
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var disposed = false
    private var retryDelayMs: Long = 20_000L
    private val maxRetryDelayMs: Long = 300_000L // 5 minutes

    init {
        val TAG = "VKBanner"

        // Enable/disable debug if passed from Flutter
        val debug = (creationParams?.get("debug") as? Boolean) ?: false
        MyTargetManager.setDebugMode(debug)
        Log.d(TAG, "Debug mode: $debug")

        // Optional test mode (API may differ across SDK versions)
        val testMode = (creationParams?.get("testMode") as? Boolean) ?: false
        if (testMode) {
            try {
                val m = MyTargetManager::class.java.getMethod("setTestMode", Boolean::class.javaPrimitiveType)
                m.invoke(null, true)
                Log.d(TAG, "Test mode: enabled")
            } catch (t: Throwable) {
                Log.w(TAG, "Test mode requested, but SDK doesn't support setTestMode(Boolean)", t)
            }
        }

        // Slot id is required
        val slotId = (creationParams?.get("slotId") as? Number)?.toInt() ?: 0
        if (slotId <= 0) {
            Log.e(TAG, "Invalid slotId: $slotId. Banner will not load.")
        } else {
            adView.setSlotId(slotId)
            Log.d(TAG, "SlotId set: $slotId")

            // Set ad size if provided from Flutter (for myTarget SDK 5.x)
            val adSize = creationParams?.get("adSize") as? String
            if (adSize != null) {
                Log.d(TAG, "AdSize received: $adSize")
                // For SDK 5.x, size is set automatically based on slot configuration
                // Just log what was requested
                Log.d(TAG, "Requested size: $adSize (will use slot configuration)")
            } else {
                Log.d(TAG, "Using slot default ad size")
            }

            // Add listener to track ad loading (SDK 5.x API)
            adView.listener = object : MyTargetView.MyTargetViewListener {
                override fun onLoad(ad: MyTargetView) {
                    Log.d(TAG, "Ad loaded successfully. SlotId: $slotId")
                    retryDelayMs = 20_000L // reset backoff on success
                }

                override fun onNoAd(error: IAdLoadingError, ad: MyTargetView) {
                    Log.e(TAG, "Ad failed to load. Reason: ${error.message}, SlotId: $slotId")
                    scheduleRetry(TAG)
                }

                override fun onClick(ad: MyTargetView) {
                    Log.d(TAG, "Ad clicked")
                }

                override fun onShow(ad: MyTargetView) {
                    Log.d(TAG, "Ad shown")
                }
            }

            // Start loading immediately
            Log.d(TAG, "Starting ad load...")
            adView.load()
        }
    }

    private fun scheduleRetry(tag: String) {
        if (disposed) return
        // cancel previous retry (if any)
        mainHandler.removeCallbacksAndMessages(null)
        val delay = retryDelayMs
        Log.d(tag, "Scheduling retry in ${delay}ms")
        mainHandler.postDelayed({
            if (disposed) return@postDelayed
            Log.d(tag, "Retrying ad load...")
            try {
                adView.load()
            } catch (t: Throwable) {
                Log.w(tag, "Retry load failed", t)
            }
        }, delay)
        retryDelayMs = (retryDelayMs * 2).coerceAtMost(maxRetryDelayMs)
    }

    override fun getView(): View = adView

    override fun dispose() {
        disposed = true
        mainHandler.removeCallbacksAndMessages(null)
        try {
            adView.destroy()
        } catch (t: Throwable) {
            Log.w("VKBanner", "Error during adView.destroy()", t)
        }
    }
}

class MyTargetBannerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any>
        return MyTargetBannerPlatformView(context, params)
    }
}
