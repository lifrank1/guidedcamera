//
//  WorkflowPlan.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Root compiled plan structure from Gemini transpilation
struct WorkflowPlan: Codable, Identifiable {
    let id: String
    let planId: String
    let steps: [WorkflowStep]
    let report: ReportTemplate?
    let advice: [String]?
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case steps
        case report
        case advice
    }
    
    init(id: String = UUID().uuidString, planId: String, steps: [WorkflowStep], report: ReportTemplate? = nil, advice: [String]? = nil) {
        self.id = id
        self.planId = planId
        self.steps = steps
        self.report = report
        self.advice = advice
    }
    
    // Custom decoder to generate id from planId if not present
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planId = try container.decode(String.self, forKey: .planId)
        steps = try container.decode([WorkflowStep].self, forKey: .steps)
        report = try container.decodeIfPresent(ReportTemplate.self, forKey: .report)
        advice = try container.decodeIfPresent([String].self, forKey: .advice)
        
        // Generate id from planId (or use planId as id)
        id = planId
    }
}

/// Individual step in the workflow plan
struct WorkflowStep: Codable, Identifiable {
    let id: String
    let ui: StepUI
    let capture: CaptureRequirement
    let validators: [Validator]
    let transitions: [Transition]
}

/// UI configuration for a step
struct StepUI: Codable {
    let instruction: String
    let overlays: [String]?
}

/// Capture requirements for a step
struct CaptureRequirement: Codable {
    let type: CaptureType
    let minCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case minCount = "minCount"
    }
}

enum CaptureType: String, Codable {
    case photo
    case video
}

/// Validator for quality or content checks
struct Validator: Codable {
    let name: String
    let op: String?
    let value: Double?
    let args: [String: AnyCodable]?
}

/// Transition rule for state machine
struct Transition: Codable {
    let when: TransitionCondition
    let to: String
}

enum TransitionCondition: String, Codable {
    case onSuccess
    case onSkip
    case onFailure
}

/// Report template configuration
struct ReportTemplate: Codable {
    let template: String?
    
    init(template: String? = nil) {
        self.template = template
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle empty report object {} or missing template
        template = try container.decodeIfPresent(String.self, forKey: .template)
    }
    
    enum CodingKeys: String, CodingKey {
        case template
    }
}

/// Helper for encoding/decoding Any values in JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

