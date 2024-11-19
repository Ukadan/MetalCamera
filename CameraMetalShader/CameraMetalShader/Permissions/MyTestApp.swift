//
//  MyTestApp.swift
//  CameraMetalShader
//
//  Created by Ali on 19.11.2024.
//

import SwiftUI

@main
struct MyTestApp: App {
    @State var viewModel: MainViewModel
    @State var permissions: PermissionsViewModel
    
    init() {
        let viewModel = MainViewModel()
        self.viewModel = viewModel
        self.permissions = .init(viewModel: viewModel)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    permissions.requestPHAccess()
                    permissions.requestCameraAccess()
                    permissions.requestMicrophoneAccess()
                }
                .environment(viewModel)
                .environment(permissions)
        }
    }
}

