//
//  VideoCard.swift
//  CameraMetalShader
//
//  Created by Ali on 18.11.2024.
//

import SwiftUI

struct VideoCard: View {
    var image: UIImage
    var name: String
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 250, alignment: .center)
                    .cornerRadius(10)

                VStack(alignment: .leading) {
                    Text("By \(name)")
                        .font(.system(size: 6))
                        .bold()
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .foregroundColor(.white)
                .shadow( radius: 20)
            }
            
            Image(systemName: "play.fill")
                .foregroundColor(.white)
                .font(.title)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(50)
        }
    }
}


#Preview {
    VideoCard(image: UIImage(imageLiteralResourceName: "Snow"), name: "New Video")
}
