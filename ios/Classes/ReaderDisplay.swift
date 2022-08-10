//
//  ReaderDisplay.swift
//  stripe_terminal
//
//  Created by Aawaz Gyawali on 10/08/2022.
//

import Foundation

// MARK: - ReaderDisplay
struct ReaderDisplay: Codable {
    let type: String
    let cart: DisplayCart
}

// MARK: - Cart
struct DisplayCart: Codable {
    let lineItems: [DisplayLineItem]
    let tax, total: Int
    let currency: String
}

// MARK: - LineItem
struct DisplayLineItem: Codable {
    let description: String
    let amount, quantity: Int
}
