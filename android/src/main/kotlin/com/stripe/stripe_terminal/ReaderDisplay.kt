package com.stripe.stripe_terminal

import com.beust.klaxon.*

private val klaxon = Klaxon()

data class ReaderDisplay (
    val type: String,
    val cart: DisplayCart
) {
    public fun toJson() = klaxon.toJsonString(this)

    companion object {
        public fun fromJson(json: String) = klaxon.parse<ReaderDisplay>(json)
    }
}

data class DisplayCart (
    val lineItems: List<DisplayLineItem>,
    val tax: Long,
    val total: Long,
    val currency: String
)

data class DisplayLineItem (
    val description: String,
    val amount: Long,
    val quantity: Int
)
