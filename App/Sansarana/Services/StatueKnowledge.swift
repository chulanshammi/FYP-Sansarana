//
//  StatueKnowledge.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-24.
//

import Foundation

/// Curated knowledge base for all three statues at Gal Viharaya
/// Designed to be token-efficient for the Foundation Models 4096-token context window
struct StatueKnowledge {
    
    // MARK: - General Knowledge
    
    /// General information about Gal Viharaya (Rock Temple)
    /// ~150 words, ~200 tokens
    static let generalKnowledge = """
    Gal Viharaya (Rock Temple) is part of ancient Polonnaruwa, a UNESCO World Heritage Site since 1982, located in Sri Lanka's North Central Province. The four rock sculptures were carved from a single granite boulder in the 12th century during King Parakramabahu I's reign (1153-1186 CE). It represents one of the finest examples of Sinhalese rock carving and Buddhist art. The complex originally included a brick image house (gedige) enclosing the statues. The site showcases the cultural renaissance of the Polonnaruwa period, blending Anuradhapura tradition with distinctive new styles.
    """
    
    // MARK: - Statue-Specific Knowledge
    
    /// Knowledge about the Seated Buddha (Samadhi)
    /// ~400 words, ~500-550 tokens
    static let seatedBuddhaKnowledge = """
    The Seated Buddha depicts the Buddha in Dhyana Mudra (meditation posture) with legs crossed in lotus position and hands resting on the lap, right over left. Height: approximately 4.6 metres (15 feet). Carved from granite.
    
    Buddhist Significance: The statue depicts the Buddha in deep meditation (samadhi), representing the moment of enlightenment under the Bodhi Tree. The Dhyana Mudra hand gesture symbolizes concentration and contemplation on the path to enlightenment.
    
    Artistic Details: The serene facial expression with half-closed eyes is considered a masterpiece of Sinhalese sculpture. The robe drapes naturally over the left shoulder. A stone halo or nimbus originally existed behind the head. The rock-cut throne features a lotus petal base. The Makara Torana (decorative arch with mythical sea creatures) represents the gateway to enlightenment.
    
    Historical Context: King Parakramabahu I commissioned this during the cultural renaissance of the Polonnaruwa period. The carving technique shows influence from the Anuradhapura tradition while developing its own distinctive Polonnaruwa style.
    
    Architectural Features: The lion pedestal symbolizes the Buddha's royal heritage and provides spiritual elevation. Intricate carvings depict Makaras (mythical creatures) representing the threshold between worldly and spiritual realms. The entire statue is carved from monolithic granite gneiss, a highly durable metamorphic rock with natural striations. This exceptional craftsmanship has preserved the sculpture for over 800 years.
    """
    
    /// Knowledge about the Standing Buddha (Abaya Mudra)
    /// ~400 words, ~500-550 tokens
    static let standingBuddhaKnowledge = """
    The Standing Buddha measures approximately 7 metres (23 feet) tall, carved from granite. The figure stands with arms crossed over the chest in an unusual posture that has sparked scholarly debate.
    
    Scholarly Interpretation: There are two main interpretations. The traditional view suggests this represents the Buddha displaying the Abaya Mudra (fearlessness gesture) with right hand raised, palm facing outward. However, the crossed-arms posture has led many scholars to believe this depicts Ananda, Buddha's devoted disciple, grieving beside the reclining Buddha. If this is indeed Ananda, it represents a unique depiction among Sri Lankan Buddhist sculptures as a representation of a disciple rather than the Buddha himself.
    
    Artistic Excellence: The statue displays remarkable anatomical detail in the carving of the robe, which appears to cling naturally to the body as if responding to gravity and movement. The facial expression shows contemplative sadness that differs markedly from the serene meditation of the seated figure. This emotional depth suggests the figure may be expressing grief or reverence.
    
    Cultural Context: The unusual posture reflects the sophisticated artistic sensibilities of the Polonnaruwa period, where sculptors were willing to experiment with iconography and emotional expression. The crossed-arms gesture conveys both respect and sorrow, appropriate for depicting Ananda's reaction to the Buddha's passing into Parinirvana.
    
    Technical Achievement: Carved from the same granite outcrop as the other statues, the standing figure demonstrates masterful control of proportion and balance. The sculptors achieved a sense of vertical movement and emotional weight despite working within the constraints of the stone. The detailed rendering of fabric, anatomy, and facial features showcases the peak of 12th-century Sinhalese stone carving.
    """
    
    /// Knowledge about the Reclining Buddha (Parinirvana)
    /// ~400 words, ~500-550 tokens
    static let recliningBuddhaKnowledge = """
    The Reclining Buddha is the largest statue at Gal Viharaya, measuring approximately 14 metres (46 feet) long, carved from granite. It depicts the Buddha lying on his right side in the moment of Parinirvana.
    
    Buddhist Significance: Parinirvana represents the Buddha's final passing and release from the cycle of rebirth (samsara). This is the ultimate state of liberation, when an enlightened being's physical form ceases and they enter complete nirvana. The moment depicted is the Buddha's death at age 80 in Kushinagar, surrounded by disciples.
    
    Iconographic Details: The head rests on a pillow (some scholars describe it as the right hand serving as pillow). The feet are slightly separated—a crucial iconographic detail that distinguishes Parinirvana from a sleeping pose. In Buddhist art tradition, perfectly aligned feet indicate sleep, while slightly separated feet signal the Buddha has already passed. This subtle distinction demonstrates the sculptors' deep understanding of Buddhist iconography.
    
    Artistic Mastery: The facial expression is extraordinarily peaceful, with a faint smile suggesting the serenity of final liberation. The robe is carved with flowing lines that follow the body's contour, creating natural draping effects. A lotus flower and Dharmachakra (wheel of dharma) symbol are carved near the feet, representing Buddhist teachings. The depression in the pillow where the head rests adds remarkable realism, showing weight and pressure.
    
    Scale and Impact: At 14 metres, this is one of the largest and finest reclining Buddha statues in Southeast Asia. The massive scale creates a profound emotional impact on visitors, emphasizing the significance of the Buddha's final moment. The granite's natural grain and the play of light across the carved surface enhance the sense of peaceful repose.
    
    Preservation: Despite 800+ years of exposure to tropical climate, the sculpture remains in excellent condition, testament to both the durability of granite gneiss and the technical skill that ensured proper drainage and weathering resistance.
    """
    
    // MARK: - Helper Methods
    
    /// Returns the complete knowledge for a specific statue
    /// - Parameter statue: The statue to get knowledge for
    /// - Returns: Formatted knowledge string combining general + specific knowledge
    static func getKnowledge(for statue: Statue) -> String {
        let specificKnowledge: String
        
        switch statue {
        case .seatedBuddha:
            specificKnowledge = seatedBuddhaKnowledge
        case .standingBuddha:
            specificKnowledge = standingBuddhaKnowledge
        case .recliningBuddha:
            specificKnowledge = recliningBuddhaKnowledge
        }
        
        return """
        GENERAL KNOWLEDGE ABOUT GAL VIHARAYA:
        \(generalKnowledge)
        
        SPECIFIC KNOWLEDGE ABOUT THE \(statue.title.uppercased()):
        \(specificKnowledge)
        """
    }
    
    /// Returns knowledge organized by category (for tool calling)
    /// - Parameters:
    ///   - statue: The statue to get knowledge for
    ///   - category: The specific category of information
    /// - Returns: Knowledge string for the requested category
    static func getSection(for statue: Statue, category: InfoCategory) -> String {
        switch category {
        case .generalHistory:
            return generalKnowledge
            
        case .physicalDescription:
            return getPhysicalDescription(for: statue)
            
        case .buddhistSignificance:
            return getBuddhistSignificance(for: statue)
            
        case .artisticDetails:
            return getArtisticDetails(for: statue)
            
        case .dimensions:
            return getDimensions(for: statue)
            
        case .interestingFacts:
            return getInterestingFacts(for: statue)
        }
    }
    
    // MARK: - Category-Specific Helpers
    
    private static func getPhysicalDescription(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "Seated Buddha in Dhyana Mudra (meditation posture) with legs crossed in lotus position, hands resting on lap (right over left). Approximately 4.6 metres (15 feet) tall. Carved from granite with natural robe draping over left shoulder. Rock-cut throne with lotus petal base and lion pedestal."
            
        case .standingBuddha:
            return "Standing figure approximately 7 metres (23 feet) tall with arms crossed over chest. Carved from granite with remarkable anatomical detail. Robe appears to cling naturally to the body. Facial expression shows contemplative sadness."
            
        case .recliningBuddha:
            return "Reclining figure approximately 14 metres (46 feet) long, lying on right side. Head rests on pillow. Feet slightly separated (indicating Parinirvana, not sleep). Carved from granite with flowing robe lines following body contour. Lotus flower and Dharmachakra symbols near feet."
        }
    }
    
    private static func getBuddhistSignificance(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "Depicts Buddha in deep meditation (samadhi), representing the moment of enlightenment under the Bodhi Tree. Dhyana Mudra hand gesture symbolizes concentration and contemplation on the path to enlightenment."
            
        case .standingBuddha:
            return "Debated interpretation: either Buddha in Abaya Mudra (fearlessness gesture) or Ananda (Buddha's disciple) grieving beside the reclining Buddha. The crossed-arms posture suggests respect and sorrow, possibly depicting Ananda's reaction to Buddha's passing into Parinirvana."
            
        case .recliningBuddha:
            return "Depicts Parinirvana—Buddha's final passing and release from the cycle of rebirth (samsara). Represents ultimate liberation when an enlightened being's physical form ceases and they enter complete nirvana. Shows Buddha's death at age 80 in Kushinagar."
        }
    }
    
    private static func getArtisticDetails(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "Masterpiece of Sinhalese sculpture with serene facial expression and half-closed eyes. Stone halo originally behind head. Makara Torana (decorative arch with mythical sea creatures) represents gateway to enlightenment. Blends Anuradhapura tradition with distinctive Polonnaruwa style. Carved from monolithic granite gneiss."
            
        case .standingBuddha:
            return "Remarkable anatomical detail with naturally clinging robe. Facial expression shows contemplative sadness, unique among Buddhist sculptures. Demonstrates sophisticated artistic sensibilities of Polonnaruwa period. Masterful control of proportion and balance despite stone constraints. Emotional depth distinguishes it from serene meditation poses."
            
        case .recliningBuddha:
            return "Extraordinarily peaceful facial expression with faint smile suggesting serenity of final liberation. Flowing robe lines follow body contour. Depression in pillow shows realistic weight and pressure. Subtle iconographic detail: slightly separated feet distinguish Parinirvana from sleep. One of the finest reclining Buddha statues in Southeast Asia."
        }
    }
    
    private static func getDimensions(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "Height: approximately 4.6 metres (15 feet). Width: approximately 7.6 metres (25 feet) including throne."
            
        case .standingBuddha:
            return "Height: approximately 7 metres (23 feet). Width: approximately 1.5 metres (5 feet)."
            
        case .recliningBuddha:
            return "Length: approximately 14 metres (46 feet). Height: approximately 1.5 metres (5 feet). This is one of the largest reclining Buddha statues in Southeast Asia."
        }
    }
    
    private static func getInterestingFacts(for statue: Statue) -> String {
        switch statue {
        case .seatedBuddha:
            return "1) The entire statue is carved from a single piece of granite gneiss. 2) The rock has lasted over 800 years due to its durability. 3) Natural striations are still visible in the stone. 4) The lotus petal base symbolizes purity arising from mud. 5) The lion pedestal represents Buddha's royal heritage as a prince before renunciation."
            
        case .standingBuddha:
            return "1) Scholarly debate continues about whether this depicts Buddha or his disciple Ananda. 2) If it's Ananda, it would be unique among Sri Lankan Buddhist sculptures. 3) The crossed-arms posture is extremely rare in Buddhist iconography. 4) The emotional expression differs markedly from typical serene Buddha faces. 5) Carved from the same granite outcrop as the other statues."
            
        case .recliningBuddha:
            return "1) At 14 metres, it's one of the largest reclining Buddha statues in Southeast Asia. 2) The slightly separated feet are a crucial detail indicating death rather than sleep. 3) A lotus and Dharmachakra are carved near the feet. 4) The pillow shows realistic depression from the head's weight. 5) Despite 800+ years in tropical climate, it remains in excellent condition."
        }
    }
}

// MARK: - Supporting Types

/// Categories of information available about each statue
enum InfoCategory: String, CaseIterable, Codable {
    case generalHistory = "General History"
    case physicalDescription = "Physical Description"
    case buddhistSignificance = "Buddhist Significance"
    case artisticDetails = "Artistic Details"
    case dimensions = "Dimensions"
    case interestingFacts = "Interesting Facts"
}
