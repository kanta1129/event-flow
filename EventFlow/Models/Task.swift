//
//  Task.swift
//  EventFlow
//
//  Data model representing a task within an event.
//

import Foundation

struct Task: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var priority: TaskPriority
    var status: TaskStatus
    var assignedTo: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
}
