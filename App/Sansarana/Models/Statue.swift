//
//  Statue.swift
//  Sansarana
//
//  Core data model representing the three Buddha statues at Gal Viharaya.
//

import Foundation
import simd

// MARK: - Statue

enum Statue: String, Codable, CaseIterable, Identifiable {
    case seatedBuddha = "Seated Buddha"
    case standingBuddha = "Standing Buddha"
    case recliningBuddha = "Reclining Buddha"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var subtitle: String {
        switch self {
        case .seatedBuddha: "Vijjadhara Guha"
        case .standingBuddha: "Utthitapathima Guha"
        case .recliningBuddha: "Nipannapatima Guha"
        }
    }
    
    var description: String {
        "12th Century, Gal Viharaya, Polonnaruwa, Sri Lanka"
    }
    
    var height: String {
        switch self {
        case .seatedBuddha: "Approx. 15 ft (4.6 m)"
        case .standingBuddha: "Approx. 23 ft (7 m)"
        case .recliningBuddha: "Approx. 46 ft (14 m)"
        }
    }
    
    var width: String {
        switch self {
        case .seatedBuddha: "Approx. 25 ft (7.6 m)"
        case .standingBuddha: "Approx. 5 ft (1.5 m)"
        case .recliningBuddha: "Approx. 5 ft (1.5 m)"
        }
    }
}

// MARK: - Annotation

struct Annotation: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let position3D: SIMD3<Float>
    let content: AnnotationContent
}

struct AnnotationContent: Codable {
    let title: String
    let description: String
    let facts: [String]
    let images: [String]
}

// MARK: - App Tab

enum AppTab {
    case ar
    case chat
    case history
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp = Date()
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}

// MARK: - Suggestion Prompts

enum SuggestionPrompt: String, CaseIterable {
    case tellMeAbout = "Tell me about this statue"
    case poseSignificance = "What does the pose mean?"
    case whoBuilt = "Who built this?"
    case interestingFacts = "Any interesting facts?"
    
    var displayText: String { rawValue }
}

// MARK: - Place Visit

struct PlaceVisit: Identifiable, Equatable {
    let id: UUID
    let placeName: String
    let location: String
    let visitDate: Date
    let artifactsSeen: [Statue]
    let verified: Bool
    
    var artifactCount: Int { artifactsSeen.count }
    
    static func == (lhs: PlaceVisit, rhs: PlaceVisit) -> Bool {
        lhs.id == rhs.id
    }
}
