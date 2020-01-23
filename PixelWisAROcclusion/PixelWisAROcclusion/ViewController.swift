//
//  ViewController.swift
//  PixelWisAROcclusion
//
//  Created by uselessfatty on 1/23/20.
//  Copyright © 2020 uselessfatty. All rights reserved.
//

import UIKit
import SceneKit
import MetalKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, MTKViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private var currentDrawableSize: CGSize!
    private var maskBuffer: CVPixelBuffer?
    private var maskImage: CIImage?
    
    @IBOutlet weak var mtkView: MTKView!
    
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
        
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        mtkView.backgroundColor = UIColor.clear
        mtkView.delegate = self
        currentDrawableSize = mtkView.currentDrawable!.layer.drawableSize
        renderer = MetalRenderer(metalDevice: device, renderDestination: mtkView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        
        // People segmentation options
        if #available(iOS 13.0, *) {
            configuration.frameSemantics = .personSegmentationWithDepth
            // .personSegmentation .personSegmentationWithDepth .bodyDetection
        } else {
        }

        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
            guard let frame = self.sceneView.session.currentFrame else { return }

            self.maskImage = CIImage(cvPixelBuffer: self.maskBuffer!)
            if let depthImage = frame.transformedDepthImage(targetSize: self.currentDrawableSize) {
                self.maskImage = depthImage
            }
        }
    }
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
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

extension CVPixelBuffer {
    func transformedImage(targetSize: CGSize, rotationAngle: CGFloat) -> CIImage? {
        let image = CIImage(cvPixelBuffer: self, options: [:])
        let scaleFactor = Float(targetSize.width) / Float(image.extent.width)
        return image.transformed(by: CGAffineTransform(rotationAngle: rotationAngle)).applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scaleFactor])
    }
}

extension ARFrame {
    func transformedDepthImage(targetSize: CGSize) -> CIImage? {
        if #available(iOS 13.0, *) {
            guard let depthData = estimatedDepthData else { return nil }
            return depthData.transformedImage(targetSize: CGSize(width: targetSize.height, height: targetSize.width), rotationAngle: -CGFloat.pi/2)
        } else {
            // Fallback on earlier versions
            return nil
        }

    }
}
