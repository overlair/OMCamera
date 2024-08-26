//
//  File.swift
//  
//
//  Created by John Knowles on 7/12/24.
//

import MetalPetal
import Vision

public  protocol OMCameraProcessor {
    func process(_ image: MTIImage) -> MTIImage
    func requests() -> [VNRequest]
}

extension OMCameraProcessor {
    func requests() -> [VNRequest] {
        []
    }
}
