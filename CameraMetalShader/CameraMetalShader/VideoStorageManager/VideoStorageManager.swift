//
//  VideoStorageManager.swift
//  CameraMetalShader
//
//  Created by Ali on 18.11.2024.
//

import Foundation
import UIKit

class VideoStorageManager {
    static let shared = VideoStorageManager()

    var videos: [URL] = []
    var thumbnails: [UIImage] = []
    var videoNames: [String] = []

    private init() {
    }
    
    func addVideo(url: URL, name: String) {
        videos.append(url)
        videoNames.append(name)
    }
    
    func addThumbnail(_ thumbnail: UIImage) {
        thumbnails.append(thumbnail)
    }
    
    func thumbnail(at index: Int) -> UIImage? {
        return thumbnails[index]
    }
    
    func video(at index: Int) -> URL? {
        return videos[index]
    }
    
    func videoName(at index: Int) -> String? {
        return videoNames[index]
    }
}

