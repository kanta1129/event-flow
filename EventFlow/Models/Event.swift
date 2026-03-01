//
//  Event.swift
//  EventFlow
//
//  Data model representing an event with all its details.
//

import Foundation

struct Event: Identifiable, Codable {
    let id: String
    var title: String
    var eventType: String
    var date: Date
    var organizerId: String
    var participantCount: Int
    var budget: Double
    var shareUrl: String
    var createdAt: Date
    var updatedAt: Date
}
