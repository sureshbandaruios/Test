/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    
    private let blurEffect = (NSClassFromString("_UICustomBlurEffect") as! UIBlurEffect.Type).init()

    
    //var imageView : UIImageView

    
    // Main view for showing camera content.
    
    
    
    var cameraImage: UIImage?

    @IBOutlet weak var ImageV: UIImageView!
    
    @IBOutlet weak var previewView: UIView?
    
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Layer UI for drawing Vision results
    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
       // setupTimer()
        
        
//        imageView  = UIImageView(frame:CGRect(x: 10, y: 50, width: 250, height: 300));
//        imageView.image = UIImage(named:"image.jpg")
//        self.previewView!.addSubview(imageView)
//        
//
//        //let imageView = UIImageView(image: imag)
//        let imageView = CGRect(x: 0, y: 0, width: 300, height: 500)
//        previewView!.addSubview(imageView.image)
//
//
        
        
        //ImageUploadinServer()
        
        
        
        self.session = self.setupAVCaptureSession()
        
        self.prepareVisionRequest()
        
        self.session?.startRunning()
    }
    
    
    
//
//    func ImageUploadinServer()
//    {
//
//
//        let subscriptionKey = "935ac35bce0149d8bf2818b936e25e1c"
//        //let image = #imageLiteral(resourceName:"monkey.jpg")
//
//        //let image = UIImage.init(named: "ff.jpeg")
//
//
//        imageview.image = UIImage(named: "ff.jpeg")
//
//
//
//
//        //let image = UIImage.init(named: image.imageview)
//
//        //let imageData  = UIImageJPEGRepresentation(image!, 0.75)!
//
//        let imageData = imageview.image!.jpegData(compressionQuality: 0.75)
//
//        //https://centralindia.api.cognitive.microsoft.com/face/v1.0/largefacelists/ldt00901/persistedFaces
//        var imageBaseurlstr = "https://centralindia.api.cognitive.microsoft.com/face/v1.0/largefacelists/"
//        var middleUrlstr = custbrCode
//        var endUrlstr = "/persistedFaces"
//
//
//        let endpointurlstr = "\(imageBaseurlstr)\(middleUrlstr)\(endUrlstr)"
//        print("endpoint1----",endpointurlstr)
//
//
//
//        let endpoint = (endpointurlstr)
//        let requestURL = URL(string: endpoint)!
//        let session = URLSession(configuration: URLSessionConfiguration.default)
//        var request:URLRequest = URLRequest(url: requestURL)
//        request.httpMethod = "POST"
//        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
//        request.addValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
//        request.httpBody = imageData
//
//        var semaphore = DispatchSemaphore.init(value: 0);
//
//        let task = session.dataTask(with: request) { (data, response, error) in
//            guard let data = data, error == nil else { return }
//            do {
//                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:Any]
//                print("image send to server---- success Response \(json)")
//
//                DispatchQueue.main.async {
//
//
//                    self.PopupView.isHidden = false
//
//                }
//
//
//            } catch let error as Error {
//                print("Error \(error)")
//            }
//            semaphore.signal()
//        }
//
//        task.resume()
//
//    }
//
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: AVCapture Setup
    
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try self.configureFrontCamera(for: captureSession)
            self.configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            self.designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            self.presentError(executionError)
        } catch {
            self.presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        self.teardownAVCapture()
        
        return nil
    }
    
    /// - Tag: ConfigureDeviceResolution
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }
    
    /// - Tag: CreateSerialDispatchQueue
    fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        self.captureDevice = inputDevice
        self.captureDeviceResolution = resolution
    }
    
    /// - Tag: DesignatePreviewLayer
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.ImageV?.layer {
            self.rootLayer = previewRootLayer
            
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    // Removes infrastructure for AVCapture as part of cleanup.
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    // MARK: Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {
        
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                    return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        
        self.setupVisionDrawingLayers()
    }
    
    // MARK: Drawing Vision Observations
    
    fileprivate func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution
        
        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)
        
        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)
        
        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        
        guard let rootLayer = self.rootLayer else {
            self.presentErrorAlert(message: "view was not property initialized")
            return
        }
        
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        
        let sampleMask = UIView()
        sampleMask.frame = self.view.frame
        sampleMask.backgroundColor =  UIColor.black.withAlphaComponent(0.6)
        //assume you work in UIViewcontroller
        self.view.addSubview(sampleMask)
        let maskLayer = CALayer()
        maskLayer.frame = sampleMask.bounds
        let circleLayer = CAShapeLayer()
        //assume the circle's radius is 150
        circleLayer.frame = CGRect(x:0 , y:0,width: sampleMask.frame.size.width,height: sampleMask.frame.size.height)
        let finalPath = UIBezierPath(roundedRect: CGRect(x:0 , y:0,width: sampleMask.frame.size.width,height: sampleMask.frame.size.height), cornerRadius: 0)
        let circlePath = UIBezierPath(ovalIn: CGRect(x:sampleMask.center.x - 150, y:sampleMask.center.y - 150, width: 300, height: 300))
        finalPath.append(circlePath.reversing())
        circleLayer.path = finalPath.cgPath
        circleLayer.borderColor = UIColor.white.withAlphaComponent(1).cgColor
        circleLayer.borderWidth = 1
        maskLayer.addSublayer(circleLayer)

        sampleMask.layer.mask = maskLayer

        
        
        
        
        
        
        
        
        overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        var faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
        faceRectangleShapeLayer.bounds = captureDeviceBounds
        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.green.withAlphaComponent(0.7).cgColor
        faceRectangleShapeLayer.lineWidth = 5
        faceRectangleShapeLayer.shadowOpacity = 0.7
        faceRectangleShapeLayer.shadowRadius = 50
        
        
        
        
        let alert = UIAlertController(title: "Alert-6", message: "Message", preferredStyle: UIAlertController.Style.alert)
                       alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                       self.present(alert, animated: true, completion: nil)
        
        
        
        
        
        
        
        
//        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
//        let previewView = UIVisualEffectView(effect: blurEffect)
//        previewView.frame = view.bounds
//        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        view.addSubview(previewView)
//        
        
        
        let faceLandmarksShapeLayer = CAShapeLayer()
//        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
//        faceLandmarksShapeLayer.bounds = captureDeviceBounds
//        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
//        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
//        faceLandmarksShapeLayer.fillColor = nil
//        faceLandmarksShapeLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.7).cgColor
//        faceLandmarksShapeLayer.lineWidth = 3
//        faceLandmarksShapeLayer.shadowOpacity = 0.7
//        faceLandmarksShapeLayer.shadowRadius = 5
        
        overlayLayer.addSublayer(faceRectangleShapeLayer)
        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
        rootLayer.addSublayer(overlayLayer)
        
        self.detectionOverlayLayer = overlayLayer
        self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
        self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
        
        self.updateLayerGeometry()
    }
    
    fileprivate func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer,
            let rootLayer = self.rootLayer,
            let previewLayer = self.previewLayer
            else {
            return
        }
        
        
        
        
        
        
        let alert = UIAlertController(title: "Facedetect-2", message: "Message", preferredStyle: UIAlertController.Style.alert)
                       alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                       self.present(alert, animated: true, completion: nil)
        
        
        
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width/2
            scaleY = videoPreviewRect.height / captureDeviceResolution.height/2

            
            
            let alert = UIAlertController(title: "Facedetect-3", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            
            
            
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

            
            
            let alert = UIAlertController(title: "Facedetect-4", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            
            
            
        case .landscapeRight:

            
            
            let alert = UIAlertController(title: "Facedetect-5", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            
            
            
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }
        
        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        
//
//
//
//        let alert = UIAlertController(title: "Facedetect-1", message: "Message", preferredStyle: UIAlertController.Style.alert)
//                       alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
//                       self.present(alert, animated: true, completion: nil)
//
        
        
        
        // Cover entire screen UI.
        let rootLayerBounds = rootLayer.bounds
        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }
    
//    fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
//        let pointCount = landmarkRegion.pointCount
//        if pointCount > 1 {
//            let points: [CGPoint] = landmarkRegion.normalizedPoints
//            path.move(to: points[0], transform: affineTransform)
//            path.addLines(between: points, transform: affineTransform)
//            if closePath {
//                path.addLine(to: points[0], transform: affineTransform)
//                path.closeSubpath()
//            }
//        }
//    }
    
    fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = self.captureDeviceResolution
        
        
        
        
        
        
        let alert = UIAlertController(title: "Facedetect-6", message: "Message", preferredStyle: UIAlertController.Style.alert)
                       alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                       self.present(alert, animated: true, completion: nil)
        
        //setupTimer()
        
        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
        faceRectanglePath.addRect(faceBounds)
        
        if let landmarks = faceObservation.landmarks {
            // Landmarks are relative to -- and normalized within --- face bounds
            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
                .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
            
            // Treat eyebrows and lines as open-ended regions when drawing paths.
            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.faceContour,
                landmarks.noseCrest,
                landmarks.medianLine
            ]
//            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
//                self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
//            }
            
            // Draw eyes, lips, and nose as closed regions.
            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.outerLips,
                landmarks.innerLips,
                landmarks.nose
            ]
//            for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
//                self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
//            }
        }
    }
    
    /// - Tag: DrawPaths
    fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
            else {
            return
        }
        
        CATransaction.begin()
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let faceRectanglePath = CGMutablePath()
        let faceLandmarksPath = CGMutablePath()
        
        for faceObservation in faceObservations {
            self.addIndicators(to: faceRectanglePath,
                               faceLandmarksPath: faceLandmarksPath,
                               for: faceObservation)
        }
        
        faceRectangleShapeLayer.path = faceRectanglePath
        faceLandmarksShapeLayer.path = faceLandmarksPath
        
        self.updateLayerGeometry()
        
        
        
        
        
        let alert = UIAlertController(title: "Facedetect-7", message: "Message", preferredStyle: UIAlertController.Style.alert)
                       alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                       self.present(alert, animated: true, completion: nil)
        
        
        
        CATransaction.commit()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            

            
            
            let alert = UIAlertController(title: "Facedetect-8", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            
            
            
            
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
                
                
                let alert = UIAlertController(title: "Alert-1", message: "Message", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
                
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                     on: pixelBuffer,
                                                     orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
            
            let alert = UIAlertController(title: "Alert-2", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            
            
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            
            

            
            
            let alert = UIAlertController(title: "Facedetect-9", message: "Message", preferredStyle: UIAlertController.Style.alert)
                           alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                           self.present(alert, animated: true, completion: nil)
            

            setupTimer()
            

            
            AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
            
            session?.stopRunning()

            
            guard let results = trackingRequest.results else {
                

                

                
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                

             
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                    
                  

                    
                }
              
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Nothing to track, so abort.
            return
        }
        
        // Perform face landmark tracking on detected faces.
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                    let alert = UIAlertController(title: "Alert-4", message: "Message", preferredStyle: UIAlertController.Style.alert)
                                   alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                                   self.present(alert, animated: true, completion: nil)
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                    let results = landmarksRequest.results as? [VNFaceObservation] else {
                        return
                }
                
                // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
                DispatchQueue.main.async {
                    self.drawFaceObservations(results)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
                
                
                let alert = UIAlertController(title: "Alert-5", message: "Message", preferredStyle: UIAlertController.Style.alert)
                               alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
                               self.present(alert, animated: true, completion: nil)
                
            }
            
//            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//                   CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
//                   let baseAddress = UnsafeMutableRawPointer(CVPixelBufferGetBaseAddress(imageBuffer!))
//                   let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
//                   let width = CVPixelBufferGetWidth(imageBuffer!)
//                   let height = CVPixelBufferGetHeight(imageBuffer!)
//
//                   let colorSpace = CGColorSpaceCreateDeviceRGB()
//
//
//
//            let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo:
//                       CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
//
//            let newImage = newContext!.makeImage()
//            cameraImage = UIImage(cgImage: newImage!)
            
        }
    }
    
    
    func setupTimer() {
        _ = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(snapshot), userInfo: nil, repeats: false)
    }
    
    @objc func snapshot() {
        print("SNAPSHOT")
         print("SNAPSHOT")
               ImageV.image = cameraImage
               
               session?.stopRunning()

               
               AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
                   AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
               }

    }
    

}
