//
//  VideoThumbnailView.swift
//  CameraMetalShader
//
//  Created by Ali on 18.11.2024.
//

import SwiftUI
import AVKit

struct VideoThumbnailView: View {
    var videoURL: URL
    @State private var player = AVPlayer()
    @StateObject private var videoThumbnailViewModel = VideoThumbnailViewModel()

    var body: some View {
        VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        videoThumbnailViewModel.saveGallery(url: videoURL)
                    } label: {
                        Text("Save to Gallery")
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 20)
                            .background(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .onAppear {
                player = AVPlayer(url: videoURL)
                player.play()
            }
    }
}

//#Preview {
//    VideoThumbnailView()
//}
