//
//  ViewController.swift
//  ScenekitExploration
//
//  Created by uselessfatty on 1/27/20.
//  Copyright © 2020 uselessfatty. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import VideoToolbox


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var latestPrediction : String = "…" // a variable containing the latest CoreML prediction
    private var currentDrawableSize: CGSize!

    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    private var segmentation: MLMultiArray?
    
    var maskNode : SCNNode!
    var maskMaterial : SCNMaterial!
    private var maskBuffer: CVPixelBuffer?
    private var maskImage: CIImage?
    private var maskContents: CGImage?


    var planeColor = UIColor.brown;
    
    var currentBuffer: CVPixelBuffer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        //////////////////////////////////////////////////
        currentDrawableSize = sceneView.intrinsicContentSize
        bilbordCreate()
        
        //////////////////////////////////////////////////
    
        // Set up Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: DeepLabV3().model) else {
            fatalError("Could not load model.")
        }
        
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: segmentationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        //////////////////////////////////////////////////
        
        print("created");
        print(Int(self.currentDrawableSize!.width));
        print(Int(self.currentDrawableSize!.height));
        CVPixelBufferCreate(kCFAllocatorDefault, 100, 100, kCVPixelFormatType_32ARGB, nil, &self.maskBuffer)
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal


        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
        
    }
    
    func segmentationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        
        guard let observations = request.results else {
            print("No results")
            return
        }
                
//        print((observations[0] as? VNCoreMLFeatureValueObservation)!.featureValue)

        self.segmentation = (observations[0] as? VNCoreMLFeatureValueObservation)!.featureValue.multiArrayValue
//        print("modify");
        modifyBuffer(from: maskBuffer!);
        
        VTCreateCGImageFromCVPixelBuffer(maskBuffer!, options: nil, imageOut: &maskContents);
        
        maskMaterial.diffuse.contents = maskContents;
//        DispatchQueue.main.async {
//            self.maskMaterial.diffuse.contents = maskCGImage
//        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        // let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage!, orientation: myOrientation, options: [:]) // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
        
        ///////////////////////////
        // Run Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    func bilbordCreate() {
        maskMaterial = SCNMaterial()
        maskMaterial.diffuse.contents = UIColor.white
//        maskMaterial.colorBufferWriteMask = .alpha
        
        let rectangle = SCNPlane(width: 0.0326, height: 0.058)
        rectangle.materials = [maskMaterial]
        
        maskNode = SCNNode(geometry: rectangle)
        maskNode?.eulerAngles = SCNVector3Make(0, 0, 0)
        maskNode?.position = SCNVector3Make(0, 0, -0.05)
        maskNode.renderingOrder = -1
        
        sceneView.pointOfView?.presentation.addChildNode(maskNode!)
    }
    
    private func modifyBuffer(from pixelBuffer: CVPixelBuffer) -> Void {
        let kBytesPerPixel = 4;
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0));
//        let bufferWidth = Int(CVPixelBufferGetWidth(pixelBuffer)); //828
//        let bufferHeight = Int(CVPixelBufferGetHeight(pixelBuffer));  //804
        let bufferWidth = 100;
        let bufferHeight = 100;
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer); //3328 = 4 * 828
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return
        }
        
        for row in 0..<bufferHeight {
            var pixel = baseAddress + row * bytesPerRow
            for col in 0..<bufferWidth {
                let blue = pixel
                if ((col-50) * (col - 50) + (row-50) * (row - 50) < 100) {
                    blue.storeBytes(of: 255, as: UInt8.self)
                } else {
                    blue.storeBytes(of: 0, as: UInt8.self)
                }
                
                let red = pixel + 1
                red.storeBytes(of: 0, as: UInt8.self)
             

                let green = pixel + 2
                green.storeBytes(of: 0, as: UInt8.self)

                let alpha = pixel + 3
                alpha.storeBytes(of: 0, as: UInt8.self)

                pixel += kBytesPerPixel;
            }

        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
