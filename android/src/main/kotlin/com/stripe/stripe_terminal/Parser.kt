package com.stripe.stripe_terminal

import com.stripe.stripeterminal.external.models.DiscoveryMethod

class StripeTerminalParser {
    companion object {
        fun getScanMethod(method: String): DiscoveryMethod? {
            return when (method) {
                "bluetooth" -> DiscoveryMethod.BLUETOOTH_SCAN;
                "internet" -> DiscoveryMethod.INTERNET;
                "localMobile" -> DiscoveryMethod.LOCAL_MOBILE;
                "handOff" -> DiscoveryMethod.HANDOFF;
                "embedded" -> DiscoveryMethod.EMBEDDED;
                "usb" -> DiscoveryMethod.USB;
                else -> null
            }
        }
    }
}