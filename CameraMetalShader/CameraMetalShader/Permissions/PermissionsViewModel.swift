//
//  PermissionsViewModel.swift
//  CameraMetalShader
//
//  Created by Ali on 19.11.2024.
//

import AVFoundation
import Foundation
import Observation
import Photos
import SwiftUI

@Observable final class PermissionsViewModel {
    var phAuthStatus = PHAuthorizationStatus.notDetermined
    var camAuthStatus = AVAuthorizationStatus.notDetermined
    var micAuthStatus = AVAuthorizationStatus.notDetermined
    let viewModel: MainViewModel
    
    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        self.checkPermissions()
    }
    
    func checkPermissions() {
        self.phAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.camAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        self.micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if camAuthStatus == .authorized {
            viewModel.appState = .camera
        } else {
            viewModel.appState = .permissions
        }
    }
    
    func requestCameraAccess() {
        
        switch self.camAuthStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    withAnimation { self.camAuthStatus = AVCaptureDevice.authorizationStatus(for: .video) }
                }
            }
            
        default:
            guard let settings = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settings) {
                UIApplication.shared.open(settings, options: [:]) { value in
                    DispatchQueue.main.async {
                        withAnimation { self.camAuthStatus = AVCaptureDevice.authorizationStatus(for: .video) }
                    }
                }
            }
        }
        
       
    }
    
    func requestMicrophoneAccess() {
        
        switch self.micAuthStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    withAnimation { self.micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio) }
                }
            }
            
        default:
            guard let settings = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settings) {
                UIApplication.shared.open(settings, options: [:]) { value in
                    DispatchQueue.main.async {
                        withAnimation { self.micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio) }
                    }
                }
            }
        }
        
       
    }
    
    func requestPHAccess() {
        
        switch self.phAuthStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { value in
                DispatchQueue.main.async {
                    withAnimation { self.phAuthStatus = value }
                    if self.phAuthStatus == .authorized {
                        //self.initPhotos()
                    }
                }
            }
        default:
            guard let settings = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settings) {
                UIApplication.shared.open(settings, options: [:]) { value in
                    DispatchQueue.main.async {
                        withAnimation { self.phAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite) }
                        if self.phAuthStatus == .authorized {
                            //self.initPhotos()
                        }
                    }
                }
            }
        }
         
    }
    
}


@Observable final class MainViewModel {
    var appState: AppStatus = .start
}

enum AppStatus {
    case start
    case camera
    case permissions
}

