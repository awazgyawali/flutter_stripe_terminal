package com.stripe.stripe_terminal

import android.app.Activity
import com.stripe.stripeterminal.external.callable.ConnectionTokenCallback
import com.stripe.stripeterminal.external.callable.ConnectionTokenProvider
import com.stripe.stripeterminal.external.models.ConnectionTokenException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class StripeTokenProvider(val activity: Activity, val methodChannel: MethodChannel) :
    ConnectionTokenProvider {
    override fun fetchConnectionToken(callback: ConnectionTokenCallback) {
        try {
            activity.runOnUiThread {

                methodChannel.invokeMethod(
                    "requestConnectionToken",
                    null,

                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            val token = result as String
                            callback.onSuccess(token)
                        }

                        override fun error(
                            errorCode: String,
                            errorMessage: String?,
                            errorDetails: Any?
                        ) {
                            callback.onFailure(
                                ConnectionTokenException(
                                    errorMessage
                                        ?: "Unable to fetch token",
                                    Exception(errorMessage),
                                ),
                            )
                        }

                        override fun notImplemented() {
                            throw  Exception("This was not supposed to happen, contact the plugin administrator")
                        }
                    })
            }
        } catch (e: Exception) {
            callback.onFailure(
                ConnectionTokenException("Failed to fetch connection token", e)
            )
        }
    }
}