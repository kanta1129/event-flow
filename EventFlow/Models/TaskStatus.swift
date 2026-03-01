//
//  TaskStatus.swift
//  EventFlow
//
//  Enumeration representing task status states.
//

import Foundation

enum TaskStatus: String, Codable {
    case unassigned
    case assigned
    case inProgress
    case completed
}
