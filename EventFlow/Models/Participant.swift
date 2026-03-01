//
//  Participant.swift
//  EventFlow
//
//  Data model representing an event participant.
//

import Foundation

struct Participant: Identifiable, Codable {
    let id: String
    var name: String
    var expectedPayment: Double
    var paymentStatus: PaymentStatus
    var paidAmount: Double
    var joinedAt: Date
    var updatedAt: Date
}
