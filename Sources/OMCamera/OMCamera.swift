// The Swift Programming Language
// https://docs.swift.org/swift-book

import Vision
import VideoIO
import MetalPetal

struct OMCameraState {
    // direction
    // isMirrored ????
    // hasPerson
}

public enum OMCameraError: Error {
    case mtiContextFailedToInitialize
}


public class OMCameraManager: NSObject {
    public init(masker: OMCameraMasker? = nil,
         processor: OMCameraProcessor? = nil,
         delegate: OMCameraDelegate? = nil) {
        self.masker = masker
        self.processor = processor
        self.delegate = delegate
    }
    
    private let camera: Camera = {
        var configurator = Camera.Configurator()
        configurator.videoConnectionConfigurator = { camera, connection in
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true
        }
        return Camera(captureSessionPreset: .vga640x480,
                      defaultCameraPosition: .back,
                      configurator: configurator)
    }()
    
    private var renderContext: MTIContext? = nil
    private var recorder: MovieRecorder?
    private let imageRenderer = PixelBufferPoolBackedImageRenderer()
    
//    private let captureQueue: DispatchQueue = DispatchSerialQueue(label: "org.metalpetal.capture", qos: .init(qosClass: .userInitiated, relativePriority: 100))
    
    var masker: OMCameraMasker?
    var processor: OMCameraProcessor?
    var delegate: OMCameraDelegate?
    
    
    let captureQueue = DispatchQueue(label: "omcamera.video", qos: .userInteractive)
    let videoQueue = DispatchQueue(label: "omcamera.video", qos: .userInteractive)
    var shouldDetectPersons: Bool = false
    var personDetector = OMCameraPersonRecognizer()
    
    public func startCapture() {
        self.camera.startRunningCaptureSession()
    }
    
    public func stopCapture() {
        self.camera.stopRunningCaptureSession()
    }
    
        
        public func startRecording() throws {
            
            let id = UUID()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(id.uuidString, conformingTo: .mpeg4Movie)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let recorder = try MovieRecorder(url: url, configuration: .init(hasAudio: false))
            
            videoQueue.async {
                self.recorder = recorder
                self.recordingURL = url
            }
        }
    public func cancelRecording() {
        guard let recorder else { return }

        videoQueue.async {
            recorder.cancelRecording(completion: {
                
            })
        }
    }
    
    private var recordingURL: URL? = nil
    
    public func stopRecording(onComplete: @escaping  (URL) -> (), onError: @escaping  (Error) -> ()) {
        guard let recorder, !recorder.isStopped, let recordingURL else { return }
        videoQueue.async {
            recorder.stopRecording(completion: { error in
                if let error {
                    print("ERRROR RECORdiNG")
                    onError(error)
                }
                onComplete(recordingURL)
            })
        }
    }
    
    
    
    
    public func start(on queue: DispatchQueue) throws{
//        captureQueue.async { [weak self] in
//            guard let self else { return }
//            do {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw OMCameraError.mtiContextFailedToInitialize
        }

        let options = MTIContextOptions()
        options.enablesRenderGraphOptimization = true
        renderContext = try MTIContext(device: device, options: options)
        
        try? self.camera.enableVideoDataOutput(on: queue,
                                               delegate: self)

//            } catch {
//                print(error)
//            }
//        }
    }
    
    public func stop() {
//        captureQueue.async {[weak self] in
//            guard let self else { return }
            
            camera.stopRunningCaptureSession()
//        }
//        pipeline?.stop()
    }
    
    func changeDirection(position: AVCaptureDevice.Position) throws {
//        captureQueue.async { [weak self] in
//            guard let self else { return }
//            do {
                try camera.switchToVideoCaptureDevice(with: position)
                camera.videoCaptureConnection?.isVideoMirrored = position == .front
//            } catch {
//                
////            }
//        }
        
    }
    
    func capture() {
        
        camera.capturePhoto(with: .init(), delegate: self)

    }
    
    private func record(recorder: MovieRecorder,
                sampleBuffer: CMSampleBuffer,
                pixelBuffer: CVPixelBuffer) {
            do {
                if let buffer = SampleBufferUtilities.makeSampleBufferByReplacingImageBuffer(of: sampleBuffer,
                                                                                             with: pixelBuffer) {
                    try recorder.appendSampleBuffer(buffer)
                }
            } catch {
                
            }
        
    }
    
    private func render(pixelBuffer: CVPixelBuffer, context: MTIContext) throws -> (pixelBuffer: CVPixelBuffer, cgImage: CGImage){
        
        var processImage = MTIImage(cvPixelBuffer: pixelBuffer,
                                    alphaType: .alphaIsOne)

        
        // also should check for flag
        if let masker {
            processImage =  masker.mask(image: processImage)
        }
        
        
        
        // if has backgruound
        /*
         let newSize = processImage.size
         var newRect = CGRect.zero
         let aspectWidth = newSize.width / backgroundImage.size.width
         let aspectHeight = newSize.height / backgroundImage.size.height
         let aspectRatio = max( aspectWidth, aspectHeight )
         
         newRect.size.width = backgroundImage.size.width * aspectRatio
         newRect.size.height = backgroundImage.size.height * aspectRatio
         
         if let background = backgroundImage.resized(to: newSize, resizingMode: .scale) {
         processImage = blend(image: processImage,
         background: background)
         }
         */
        if let processor {
            
            processImage = processor.process(processImage)
        }
        
        let renderOutput = try self.imageRenderer.render(processImage,
                                                         using: context)
        
        
        return renderOutput
    }
}

extension OMCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    var hasRequests: Bool {
        if let masker, !masker.requests().isEmpty {
            return true
        } else if let processor, !processor.requests().isEmpty {
            return true
        }
        return false
    }
   public func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        captureQueue.async {[weak self] in
            guard let self else { return }
            
           print(Thread.isMainThread, Thread.current)
       
            guard let context = renderContext,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            do {
               
                if hasRequests {
                    try handleRequests(pixelBuffer: pixelBuffer)
                }
                var renderOutput = try render(pixelBuffer: pixelBuffer, context: context)
                
                videoQueue.async {
                    if let recorder = self.recorder {
                        self.record(recorder: recorder,
                               sampleBuffer: sampleBuffer,
                               pixelBuffer: renderOutput.pixelBuffer)
                    }
                }
                
                
                // send to delegate
                DispatchQueue.main.async {
                    self.delegate?.cameraManager(didProcess: renderOutput.cgImage,
                                             buffer: renderOutput
                        .pixelBuffer)
                    
                }
                
               
                if shouldDetectPersons {
                    let detected = try personDetector.checkForDetectedPerson(pixelBuffer: pixelBuffer)
                    
                }
                
            } catch {
                
            }
        }
        
    }
    
    private func handleRequests(pixelBuffer: CVPixelBuffer) throws {
        let maskRequests: [VNRequest] = masker?.requests() ?? []
        let processorRequests: [VNRequest] = processor?.requests() ?? []
        
        let requests = maskRequests + processorRequests
        // do this elsewhere?
        if !requests.isEmpty {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            try handler.perform(requests)
        }
        
    }
}

extension OMCameraManager: AVCapturePhotoCaptureDelegate {
    public  func photoOutput(_ output: AVCapturePhotoOutput,
                     didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //        output.
    }
    
    public  func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            // send error
        }
        
        guard let context = renderContext,
              let buffer = photo.pixelBuffer else { return }
        
        do {
            let output  = try render(pixelBuffer: buffer, context: context)
            
            delegate?.cameraManager(didCapture: photo)
        } catch {
            // send error
        }
    }
    
}








@available(iOS 15.0, *)
class OMCameraPersonMasker: OMCameraMasker {
    
    private lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
//        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()
    
    
    func requests() -> [VNRequest] {
        [
            segmentationRequest
        ]
    }
    
    func mask(image: MTIImage) -> MTIImage {
        guard let result = segmentationRequest.results?.first else { return image }
        let maskBlend = MTIBlendWithMaskFilter()
        let maskPixelBuffer = result.pixelBuffer
        let maskImage = MTIImage(cvPixelBuffer: maskPixelBuffer, alphaType: .alphaIsOne)
        let mask = MTIMask(content: maskImage)
        
        maskBlend.inputImage = image
        maskBlend.inputMask = mask
        maskBlend.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: image.size)
        return maskBlend.outputImage ?? image
    }
}
