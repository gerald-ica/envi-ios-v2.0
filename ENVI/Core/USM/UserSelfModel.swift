import Foundation

/// Root User Self-Model v1 struct with unified schema and all six blocks.
public struct UserSelfModel: Codable, Sendable, Equatable {
    
    public let identity: Identity
    public let astroBlock: USMAstroBlock
    public let psychBlock: USMPsychBlock
    public let dynamicBlock: USMDynamicBlock
    public let visualBlock: USMVisualBlock
    public let predictBlock: USMPredictBlock
    public let neuroBlock: USMNeuroBlock
    
    /// Metadata and identity wrapper for self-model instance.
    public struct Identity: Codable, Sendable, Equatable {
        public let userId: String
        public let modelVersion: Int
        public let createdAt: Date
        public let updatedAt: Date
        public let recomputedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case modelVersion = "model_version"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case recomputedAt = "recomputed_at"
        }
        
        public init(
            userId: String,
            modelVersion: Int = 1,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            recomputedAt: Date = Date()
        ) {
            self.userId = userId
            self.modelVersion = modelVersion
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.recomputedAt = recomputedAt
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case identity
        case astroBlock = "astro_block"
        case psychBlock = "psych_block"
        case dynamicBlock = "dynamic_block"
        case visualBlock = "visual_block"
        case predictBlock = "predict_block"
        case neuroBlock = "neuro_block"
    }
    
    public init(
        identity: Identity,
        astroBlock: USMAstroBlock,
        psychBlock: USMPsychBlock,
        dynamicBlock: USMDynamicBlock,
        visualBlock: USMVisualBlock,
        predictBlock: USMPredictBlock,
        neuroBlock: USMNeuroBlock
    ) {
        self.identity = identity
        self.astroBlock = astroBlock
        self.psychBlock = psychBlock
        self.dynamicBlock = dynamicBlock
        self.visualBlock = visualBlock
        self.predictBlock = predictBlock
        self.neuroBlock = neuroBlock
    }
    
    /// Create an empty self-model placeholder.
    public static func makeEmpty(userId: String) -> UserSelfModel {
        UserSelfModel(
            identity: Identity(userId: userId),
            astroBlock: USMAstroBlock.makeEmpty(),
            psychBlock: USMPsychBlock.makeEmpty(),
            dynamicBlock: USMDynamicBlock.makeEmpty(),
            visualBlock: USMVisualBlock.makeEmpty(),
            predictBlock: USMPredictBlock.makeEmpty(),
            neuroBlock: USMNeuroBlock.makeEmpty()
        )
    }
    
    /// Upgrade a self-model from an older schema version.
    public static func upgrade(
        from oldModel: UserSelfModel,
        fromVersion: Int,
        toVersion: Int
    ) throws -> UserSelfModel {
        guard fromVersion == toVersion else {
            throw USMError.upgradeFailed("Upgrade from version \(fromVersion) to \(toVersion) not supported")
        }
        return oldModel
    }
}

// MARK: - Block Definitions

/// Astrological / Vedic astrology component of the self-model.
public struct USMAstroBlock: Codable, Sendable, Equatable {
    public let sunSign: String
    public let moonSign: String
    public let risingSign: String
    public let planetaryPositions: [String: JSONValue]
    public let nakshatras: [String: String]
    public let dashaCycle: String
    
    enum CodingKeys: String, CodingKey {
        case sunSign = "sun_sign"
        case moonSign = "moon_sign"
        case risingSign = "rising_sign"
        case planetaryPositions = "planetary_positions"
        case nakshatras
        case dashaCycle = "dasha_cycle"
    }
    
    public init(
        sunSign: String,
        moonSign: String,
        risingSign: String,
        planetaryPositions: [String: JSONValue] = [:],
        nakshatras: [String: String] = [:],
        dashaCycle: String = ""
    ) {
        self.sunSign = sunSign
        self.moonSign = moonSign
        self.risingSign = risingSign
        self.planetaryPositions = planetaryPositions
        self.nakshatras = nakshatras
        self.dashaCycle = dashaCycle
    }
    
    static func makeEmpty() -> USMAstroBlock {
        USMAstroBlock(sunSign: "", moonSign: "", risingSign: "")
    }
}

/// Psychological / personality framework component.
public struct USMPsychBlock: Codable, Sendable, Equatable {
    public let mbtiType: String
    public let enneagramType: Int
    public let enneagramWing: String
    public let archetype: String
    public let bigFiveScores: [String: Double]
    public let cognitiveFunctions: [String]
    
    enum CodingKeys: String, CodingKey {
        case mbtiType = "mbti_type"
        case enneagramType = "enneagram_type"
        case enneagramWing = "enneagram_wing"
        case archetype
        case bigFiveScores = "big_five_scores"
        case cognitiveFunctions = "cognitive_functions"
    }
    
    public init(
        mbtiType: String,
        enneagramType: Int,
        enneagramWing: String = "",
        archetype: String = "",
        bigFiveScores: [String: Double] = [:],
        cognitiveFunctions: [String] = []
    ) {
        self.mbtiType = mbtiType
        self.enneagramType = enneagramType
        self.enneagramWing = enneagramWing
        self.archetype = archetype
        self.bigFiveScores = bigFiveScores
        self.cognitiveFunctions = cognitiveFunctions
    }
    
    static func makeEmpty() -> USMPsychBlock {
        USMPsychBlock(mbtiType: "", enneagramType: 1)
    }
}

/// Dynamic personality state at a point in time.
public struct USMDynamicBlock: Codable, Sendable, Equatable {
    public let mood: String
    public let energyLevel: Double
    public let focusAreas: [String]
    public let stressLevel: Double
    public let recentEvents: [String]
    
    enum CodingKeys: String, CodingKey {
        case mood
        case energyLevel = "energy_level"
        case focusAreas = "focus_areas"
        case stressLevel = "stress_level"
        case recentEvents = "recent_events"
    }
    
    public init(
        mood: String,
        energyLevel: Double,
        focusAreas: [String] = [],
        stressLevel: Double = 0.5,
        recentEvents: [String] = []
    ) {
        self.mood = mood
        self.energyLevel = max(0.0, min(1.0, energyLevel))
        self.focusAreas = focusAreas
        self.stressLevel = max(0.0, min(1.0, stressLevel))
        self.recentEvents = recentEvents
    }
    
    static func makeEmpty() -> USMDynamicBlock {
        USMDynamicBlock(mood: "", energyLevel: 0.5)
    }
}

/// Visual / symbolic representation and aesthetics.
public struct USMVisualBlock: Codable, Sendable, Equatable {
    public let avatarUrl: String
    public let colorPalette: [String]
    public let symbolicElements: [String]
    public let designMetadata: [String: JSONValue]
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case colorPalette = "color_palette"
        case symbolicElements = "symbolic_elements"
        case designMetadata = "design_metadata"
    }
    
    public init(
        avatarUrl: String = "",
        colorPalette: [String] = [],
        symbolicElements: [String] = [],
        designMetadata: [String: JSONValue] = [:]
    ) {
        self.avatarUrl = avatarUrl
        self.colorPalette = colorPalette
        self.symbolicElements = symbolicElements
        self.designMetadata = designMetadata
    }
    
    static func makeEmpty() -> USMVisualBlock {
        USMVisualBlock()
    }
}

/// Forecast / prediction component.
public struct USMPredictBlock: Codable, Sendable, Equatable {
    public let nearTermOutlook: String
    public let longTermTrajectory: String
    public let keyPeriods: [[String: JSONValue]]
    public let riskFactors: [String]
    
    enum CodingKeys: String, CodingKey {
        case nearTermOutlook = "near_term_outlook"
        case longTermTrajectory = "long_term_trajectory"
        case keyPeriods = "key_periods"
        case riskFactors = "risk_factors"
    }
    
    public init(
        nearTermOutlook: String = "",
        longTermTrajectory: String = "",
        keyPeriods: [[String: JSONValue]] = [],
        riskFactors: [String] = []
    ) {
        self.nearTermOutlook = nearTermOutlook
        self.longTermTrajectory = longTermTrajectory
        self.keyPeriods = keyPeriods
        self.riskFactors = riskFactors
    }
    
    static func makeEmpty() -> USMPredictBlock {
        USMPredictBlock()
    }
}

/// Neurotype / cognitive style component.
public struct USMNeuroBlock: Codable, Sendable, Equatable {
    public let neurotype: String
    public let cognitiveStyle: String
    public let learningPreferences: [String]
    public let sensorySensitivities: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case neurotype
        case cognitiveStyle = "cognitive_style"
        case learningPreferences = "learning_preferences"
        case sensorySensitivities = "sensory_sensitivities"
    }
    
    public init(
        neurotype: String = "",
        cognitiveStyle: String = "",
        learningPreferences: [String] = [],
        sensorySensitivities: [String: String] = [:]
    ) {
        self.neurotype = neurotype
        self.cognitiveStyle = cognitiveStyle
        self.learningPreferences = learningPreferences
        self.sensorySensitivities = sensorySensitivities
    }
    
    static func makeEmpty() -> USMNeuroBlock {
        USMNeuroBlock()
    }
}

// MARK: - Utilities

/// Codable wrapper for arbitrary JSON values.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Errors

enum USMError: LocalizedError {
    case upgradeFailed(String)
    case cacheMissing
    case syncFailed(String)
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .upgradeFailed(let msg):
            return "Schema upgrade failed: \(msg)"
        case .cacheMissing:
            return "Cache unavailable"
        case .syncFailed(let msg):
            return "Sync failed: \(msg)"
        case .conflictResolutionFailed:
            return "Conflict resolution failed"
        }
    }
}
