//
//  CameraView.swift
//  CameraMetalShader
//
//  Created by Ali on 17.11.2024.
//
import MediaPlayer
import MetalKit
import SwiftUI

struct CameraView: UIViewRepresentable {
    let camera: CameraViewModel

    func makeUIView(context: Context) -> MTKView {
        camera.hardware.preview.framebufferOnly = false
        camera.hardware.preview.backgroundColor = UIColor.orange
        camera.hardware.preview.enableSetNeedsDisplay = false
        camera.hardware.preview.isPaused = true
        camera.hardware.preview.isUserInteractionEnabled = true
        camera.hardware.preview.isMultipleTouchEnabled = true
        camera.hardware.preview.delegate = camera
        
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.layer.position = CGPoint(x: -50, y: 20)
         
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                camera.isLockVolumeButtons = true
                slider.setValue(0.5, animated: false)
            }
        }
        
        return camera.hardware.preview
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) { }
}
