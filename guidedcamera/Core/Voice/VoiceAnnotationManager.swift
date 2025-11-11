//
//  VoiceAnnotationManager.swift
//  guidedcamera
//
//  Created by Frank Li on 11/3/25.
//

import Foundation

/// Handles Contextual Q&A and basic annotation capture
class VoiceAnnotationManager {
    static let shared = VoiceAnnotationManager()
    
    private let speechRecognizer = SpeechRecognizer.shared
    private let annotationStore = AnnotationStore.shared
    
    private init() {}
    
    /// Start recording a voice annotation
    func startAnnotation(stepId: String, mediaId: UUID? = nil, completion: @escaping (Result<Annotation, Error>) -> Void) {
        speechRecognizer.startRecognition { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let text):
                let annotation = Annotation(
                    mediaId: mediaId,
                    stepId: stepId,
                    type: .voice,
                    content: text
                )
                
                self.annotationStore.save(annotation)
                completion(.success(annotation))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Stop recording annotation
    func stopAnnotation() {
        speechRecognizer.stopRecognition()
    }
    
    /// Create a text annotation
    func createTextAnnotation(stepId: String, mediaId: UUID? = nil, content: String) -> Annotation {
        let annotation = Annotation(
            mediaId: mediaId,
            stepId: stepId,
            type: .text,
            content: content
        )
        
        annotationStore.save(annotation)
        return annotation
    }
    
    /// Create a contextual Q&A annotation
    func createContextualQA(stepId: String, question: String, answer: String) -> Annotation {
        let content = "Q: \(question)\nA: \(answer)"
        let annotation = Annotation(
            stepId: stepId,
            type: .contextualQA,
            content: content
        )
        
        annotationStore.save(annotation)
        return annotation
    }
}

