//
//  File.swift
//  
//
//  Created by John Knowles on 7/12/24.
//

import Vision

class OMCameraPersonRecognizer {
    
    var confidence: Float  = 0.2
    lazy var faceRectanglesRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest()
//        request.preferBackgroundProcessing = true
        return request
    }()
    
    
    func checkForDetectedPerson(pixelBuffer: CVPixelBuffer) throws -> Bool {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try handler.perform([faceRectanglesRequest])
        
        for result in faceRectanglesRequest.results ?? [] {
            if result.confidence > confidence {
                return true
            }
        }
       
        return false
    }
}
