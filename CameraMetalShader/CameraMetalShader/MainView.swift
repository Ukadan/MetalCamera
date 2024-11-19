//
//  MainView.swift
//  CameraMetalShader
//
//  Created by Ali on 17.11.2024.
//

import SwiftUI
import AVKit
import AVFoundation

struct MainView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(PermissionsViewModel.self) var permissions
        
    @AppStorage("backDevice") var backDevice: BackDeviceType = .wideAngle
    @AppStorage("cameraPosition") var cameraPosition: AVCaptureDevice.Position = .back
    
    @State var videoManager = VideoStorageManager.shared
    @State var cameraViewModel: CameraViewModel = .init()
    @State var showGallery = false
    
    var body: some View {
        NavigationStack {
            VStack {
                CameraView(camera: cameraViewModel)
                
                listFillter()
                
                HStack {
                    Button {
                        showGallery.toggle()
                    } label: {
                        
                        roundRectangleVideoList(with: videoManager.thumbnails.isEmpty ? Image("Snow") : Image(uiImage: videoManager.thumbnails.last!), size: 60)
                    }
                    
                    Spacer()
                    
                    RecordButtonView(isPressed: $cameraViewModel.isWriting) {
                        if cameraViewModel.isWriting {
                            cameraViewModel.stopWriting()
                        } else {
                            cameraViewModel.startWriting()
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        cameraPosition = cameraPosition == .back ? .front : .back
                        cameraViewModel.start(with: cameraPosition, and: backDevice)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .resizable()
                            .foregroundColor(.white)
                            .scaledToFit()
                            .frame(width:60, height: 60)
                            .padding(20)
                            .padding(.trailing, 20)
                    }
                    .shadow(radius: 5)
                    .contentShape(Rectangle())
                }
            }
            .background(.black)
        }
        .background(.black)
        .fullScreenCover(isPresented: $showGallery) {
            VideoCollectionsView(isPresented: $showGallery)
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            cameraViewModel.prepareCamera()
            cameraViewModel.start(with: cameraPosition, and: backDevice)
        }
        .onChange(of: cameraViewModel.torchMode) { _, newValue in
            guard let activeDevice = cameraViewModel.activeDevice else { return }
            
            if activeDevice.isTorchAvailable {
                do {
                    try activeDevice.lockForConfiguration()
                    activeDevice.torchMode = newValue
                    activeDevice.unlockForConfiguration()
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            cameraViewModel.stopSession()
            cameraViewModel.hardware.mManager.stopAccelerometerUpdates()
            cameraViewModel.cancellable.removeAll()
            cameraViewModel.audioSession.removeObserver(cameraViewModel, forKeyPath: "outputVolume", context: nil)
            try? cameraViewModel.audioSession.setActive(false)
        }
    }
}

extension MainView {
    @ViewBuilder
    func listFillter() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cameraViewModel.luts, id: \.self) { lut in
                    Button(action: {
                        withAnimation(.spring(duration: 0.25)) {
                            cameraViewModel.selectedLUT = lut
                            cameraViewModel.load(lut: cameraViewModel.selectedLUT ?? "@")
                        }
                    }) {
                        ZStack () {
                            Text(lut)
                                .font(.system(size: 14, weight: cameraViewModel.selectedLUT == lut ? .semibold : .regular))
                                .foregroundStyle(cameraViewModel.selectedLUT == lut ? .yellow : .white)
                                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            
                        }
                    }
                }
            }
        }
    }
}

extension MainView {
    @ViewBuilder
    func roundRectangleVideoList(with image: Image, size: CGFloat) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size, alignment: .center)
            .clipped()
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white, lineWidth: 1)
            )
            .padding(20)
    }
}

#Preview {
    MainView()
}



struct RecordButtonView: View {
    @Binding var isPressed: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            RecordButtonLabel(isPressed: $isPressed)
                .padding(.vertical)
        }
    }
}

struct RecordButtonLabel: View {
    @Binding var isPressed: Bool
    
    var body: some View {
        Circle()
            .stroke(lineWidth: 3)
            .frame(width: 70)
            .foregroundStyle(.white)
            .overlay(alignment: .center) {
                if isPressed {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.red)
                        .animation(.linear, value: isPressed)
                } else {
                    Circle()
                        .frame(width: 55)
                        .foregroundStyle(.red)
                        .animation(.linear, value: isPressed)
                }
            }
    }
}

//#Preview {
//    MainView()
//}
