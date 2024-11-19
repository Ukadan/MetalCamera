//
//  VideoThumbnailViewModel.swift
//  CameraMetalShader
//
//  Created by Ali on 18.11.2024.
//

import Foundation


class VideoThumbnailViewModel: ObservableObject {
    private let captureManger = AVCaptureManger.shared
    
    func saveGallery(url: URL) {
        captureManger.saveVideoToGallery(from: url)
    }
}
