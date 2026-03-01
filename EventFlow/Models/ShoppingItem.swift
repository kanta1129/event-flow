//
//  ShoppingItem.swift
//  EventFlow
//
//  Data model representing a shopping list item.
//

import Foundation

struct ShoppingItem: Identifiable, Codable {
    let id: String
    var item: String
    var quantity: String
    var estimatedCost: Double
    var purchased: Bool
    var purchasedBy: String?
}
