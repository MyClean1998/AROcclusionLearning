//
//  Mask.swift
//  ScenekitExploration
//
//  Created by uselessfatty on 2/3/20.
//  Copyright © 2020 uselessfatty. All rights reserved.
//

import Foundation
import ARKit
import VideoToolbox


class Mask {
    private var maskBuffer: CVPixelBuffer?

    init() {
        CVPixelBufferCreate(kCFAllocatorDefault, 100, 100, kCVPixelFormatType_32ARGB, nil, &self.maskBuffer)
    }
    
    func drawHole() {
        let kBytesPerPixel = 4;
        if (maskBuffer == nil) {
            return;
        }
        let pixelBuffer: CVPixelBuffer = maskBuffer!
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
    
    func generateImage() -> CGImage? {
        var maskContents: CGImage?
        VTCreateCGImageFromCVPixelBuffer(maskBuffer!, options: nil, imageOut: &maskContents);
        return maskContents;
    }
}
