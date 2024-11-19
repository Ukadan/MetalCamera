//
//  AVCaptureManger.swift
//  CameraMetalShader
//
//  Created by Ali on 17.11.2024.
//
import Foundation
import AVFoundation
import Photos
import SwiftUI

class AVCaptureManger: NSObject {
    static let shared = AVCaptureManger()
}


//MARK: - Save video to gallery
extension AVCaptureManger {
    func saveVideoToGallery(from videoURL: URL) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
//        if status == .authorized {
//            try await PHPhotoLibrary.shared().performChanges {
//                let request = PHAssetCreationRequest.forAsset()
//                request.addResource(with: .video, fileURL: url, options: nil)
//            }
//        }
        if status == .authorized {
            PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: videoURL, options: options)
            } completionHandler: { success, error in
                if success {
                    print("Video saved to photo library.")
                } else if let error = error {
                    print("Error saving video to photo library: \(error.localizedDescription)")
                }
            }
        }
    }
}

