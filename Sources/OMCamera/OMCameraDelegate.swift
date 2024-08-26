//
//  File.swift
//  
//
//  Created by John Knowles on 7/12/24.
//

import Foundation
import CoreGraphics
import AVFoundation

public  protocol OMCameraDelegate {
    func cameraManager(didProcess image: CGImage, buffer: CVPixelBuffer)
    func cameraManager(didCapture photo: AVCapturePhoto)
    func cameraManager(didFail error: Error)
}

public extension OMCameraDelegate {
    func cameraManager(didProcess image: CGImage, buffer: CVPixelBuffer) {}
    func cameraManager(didCapture photo: AVCapturePhoto) {}
    func cameraManager(didFail error: Error) {}
}
