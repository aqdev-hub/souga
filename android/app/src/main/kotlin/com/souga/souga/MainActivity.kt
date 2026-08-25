package com.souga.souga

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * ✅ تمت إضافة دعم Deep Link يدوي (بدون أي حزمة خارجية):
 *   - عند فتح التطبيق من رابط مثل souga://product/PRODUCT_ID (حالة Cold Start):
 *     نحفظ الرابط في pendingLink وننتظر أن يطلبه Flutter عبر getInitialLink.
 *   - عند النقر على الرابط والتطبيق يعمل بالفعل بالخلفية (onNewIntent):
 *     نُرسل الرابط فوراً لـ Flutter عبر onNewLink.
 *
 * لا حاجة لتعديل AndroidManifest.xml لأنه يحتوي بالفعل على:
 *   <data android:scheme="souga"/>  وعلى launchMode="singleTop"
 * مما يضمن استدعاء onNewIntent بدل إعادة إنشاء الـ Activity.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "souga/deeplink"
    private var methodChannel: MethodChannel? = null

    // رابط بانتظار أن يطلبه Flutter (حالة Cold Start فقط)
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    // Flutter يطلب الرابط الابتدائي مرة واحدة عند الإقلاع
                    result.success(pendingLink)
                    pendingLink = null
                }
                else -> result.notImplemented()
            }
        }

        // حالة Cold Start: التقاط الرابط الذي فتح التطبيق لأول مرة
        val startupLink = intent?.data?.toString()
        if (!startupLink.isNullOrEmpty()) {
            pendingLink = startupLink
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val link = intent.data?.toString()
        if (link.isNullOrEmpty()) return

        val channel = methodChannel
        if (channel != null) {
            // التطبيق يعمل بالفعل — أرسل الرابط مباشرة لـ Flutter
            channel.invokeMethod("onNewLink", link)
        } else {
            // احتياطي نادر: القناة غير جاهزة بعد
            pendingLink = link
        }
    }
}
