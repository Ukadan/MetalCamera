//
//  VideoCollectionsView.swift
//  CameraMetalShader
//
//  Created by Ali on 17.11.2024.
//
import SwiftUI

struct VideoCollectionsView: View {
    @Binding var isPresented: Bool
    
    @State private var videoManager = VideoStorageManager.shared
    
    var colums = [GridItem(.adaptive(minimum: 160),spacing: 20 )]
        
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVGrid(columns: colums,spacing: 20) {
                        ForEach(Array(videoManager.thumbnails.enumerated()), id: \.element) { index, thumbnail in
                            NavigationLink {
                                VideoThumbnailView(videoURL: videoManager.videos[index])
                            } label: {
                                VideoCard(image: thumbnail, name: videoManager.videoName(at: index)!)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented.toggle()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

//#Preview {
//    VideoCollectionsView(isPresented: true)
//}
