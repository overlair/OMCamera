//
//  File.swift
//  
//
//  Created by John Knowles on 7/12/24.
//

import MetalPetal
import Vision

public protocol OMCameraMasker {
    func mask(image: MTIImage) -> MTIImage
    
    func requests() -> [VNRequest]
}

extension OMCameraMasker {
    func requests() -> [VNRequest] {
        []
    }
}
