//
//  CameraViewModel.swift
//  CameraMetalShader
//
//  Created by Ali on 17.11.2024.
//

import Foundation
import AVFoundation
import Combine
import CoreMotion
import Foundation
import MetalKit
import Observation
import Photos
import VideoToolbox

enum BackDeviceType: String, Codable {
    case ultraWide
    case wideAngle
    case wideAngleX2
    case telephoto
}


@Observable
final class CameraViewModel: NSObject {
    var backDevices: [BackDeviceType] = []
    var frontDevice: AVCaptureDevice.DeviceType?
    var inclination: Double = 0
    var maxOpticalZoom: Int = 2
    var focus: Float = 0
    var isAdjustingFocus: Bool = false
    var isAdjustingExposure: Bool = false
    var supportedTorchModes: [AVCaptureDevice.TorchMode] = []
    var torchMode: AVCaptureDevice.TorchMode = .off
    var activeDevice: AVCaptureDevice?
    var selectedLUT: String?
    var showNoise: Bool = false
    var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    var isWriting: Bool = false
    var duration: Int = 0
    
    var lensPosition: Float = 0
    var focusImageVisibleSeconds: Double = 0
    var currentFocus: Float = 0
    var resultFocus: Float?
    var focusImage: CGImage?
    var pointOfInterest: CGPoint?
    
    @ObservationIgnored var sampleBuffer: CMSampleBuffer?
    @ObservationIgnored var cancellable: Set<AnyCancellable> = []
    @ObservationIgnored var cubeBuffer: (MTLBuffer, MTLBuffer)?
    @ObservationIgnored private var keyValueObservations = [NSKeyValueObservation]()
    
    @ObservationIgnored var assetWriter: AVAssetWriter?
    @ObservationIgnored var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    @ObservationIgnored var vInput: AVAssetWriterInput?
    @ObservationIgnored var aInput: AVAssetWriterInput?
    @ObservationIgnored var sessionAtSourceTime: CMTime?
    @ObservationIgnored var isLockVolumeButtons: Bool = true
    @ObservationIgnored var zoom: CGFloat = 1.0
    
    let hardware: HardwareContainer = .init()
    let audioSession = AVAudioSession.sharedInstance()
    let isClassicDevice: Bool = UIScreen.main.bounds.height / UIScreen.main.bounds.width <= 1.78
    let beginCapture: SystemSoundID = 1117
    let endCapture: SystemSoundID = 1118
     
    let luts = ["Arabica", "Ava", "Azrael", "BlueArchitecture", "BlueHour", "Bourbon", "Byers", "Chemical", "Clayton", "Clouseau", "Cobi", "ColdChrome", "Contrail", "CrispAutumn", "Cubicle", "DarkAndSomber", "Django", "Domingo", "Faded", "FastFilm", "Folger", "Fusion", "GoingForAWalk", "GoodMorning", "HardBoost", "Hyla", "Korben", "KToneVintage", "Lenox", "LongBeachMorning", "Lucky", "LushGreen", "MagicHour", "McKinnon", "Milo", "MoodyBlue", "MoodyStock", "Nah", "NaturalBoost", "Neon", "OnceUponATime", "OrangeAndBlue", "Paladin1875", "Pasadena", "Passing", "Pitaya", "Reeve", "Remy", "Serenity", "SmoothSailing", "SoftBlackAndWhite", "Sprocket", "Teigen", "Trent", "Tweed", "Undeniable", "Undeniable 2", "UrbanCowboy", "Vireo", "Waves", "WellSee", "YouCanDoIt", "Zed", "Zeke"]
    
    let neutralLutArray = [SIMD4<Float>(0.0, 0.0, 0.0, 1.0), SIMD4<Float>(1.0, 0.0, 0.0, 1.0), SIMD4<Float>(0.0, 1.0, 0.0, 1.0), SIMD4<Float>(1.0, 1.0, 0.0, 1.0), SIMD4<Float>(0.0, 0.0, 1.0, 1.0), SIMD4<Float>(1.0, 0.0, 1.0, 1.0), SIMD4<Float>(0.0, 1.0, 1.0, 1.0), SIMD4<Float>(1.0, 1.0, 1.0, 1.0)]
    
    private let toBackground = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    private let toForeground = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    private let thermal = NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
    
    override init() {
         
        super.init()
        
        print("size \(luts.count)")
        
        self.audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        try? self.audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
        try? self.audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
        try? self.audioSession.setActive(true)
        
        thermal
            .sink { value in
                if let processInfo = value.object as? ProcessInfo {
                    DispatchQueue.main.async {
                        if processInfo.thermalState == .critical {
                            if self.isWriting { self.stopWriting() }
                            self.hardware.sessionQueue.async { self.stopSession() }
                        }
                        self.thermalState = processInfo.thermalState
                    }
                }
            }
            .store(in: &cancellable)
        
        toBackground
            .sink{ _ in
                if self.isWriting { self.stopWriting() }
            }
            .store(in: &cancellable)
        
    }
    
    @inlinable
    func prepareCamera() {
        backDevices = avaliableBackDevices()
        frontDevice = avaliableFrontDevice()
        
        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            let factors = device.virtualDeviceSwitchOverVideoZoomFactors
            if factors.count == 2 {
                DispatchQueue.main.async { self.maxOpticalZoom = Int(truncating: factors[1])/Int(truncating: factors[0]) }
            }
        }

    }
    
    @inlinable
    func avaliableBackDevices() -> [BackDeviceType] {
        var result: [BackDeviceType] = []
        
        if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil { result.append(.ultraWide) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            result.append(.wideAngle)
            if !device.formats.filter({!$0.secondaryNativeResolutionZoomFactors.filter({$0 == 2.0}).isEmpty}).isEmpty { result.append(.wideAngleX2) }
        }
        if AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) != nil { result.append(.telephoto) }
    
        return result
    }
     
    @inlinable
    func avaliableFrontDevice() -> AVCaptureDevice.DeviceType? {
        let discoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInTelephotoCamera, .builtInTripleCamera, .builtInUltraWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .front)
        
        let devices = discoverSession.devices
        
        return devices.map({$0.deviceType}).last
    }
    
    @inlinable
    func start(with position: AVCaptureDevice.Position, and backDevice: BackDeviceType) {
        hardware.sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopSession()
            
            do {
                self.hardware.session.beginConfiguration()
                self.hardware.session.sessionPreset = .inputPriority
                
                switch position {
                case .back:
                    switch backDevice {
                    case .ultraWide:
                        guard let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) else { return }
                        self.activeDevice = device
                    case .wideAngle, .wideAngleX2:
                        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
                        self.activeDevice = device
                    case .telephoto:
                        guard let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) else { return }
                        self.activeDevice = device
                    }
                case .front:
                    guard let front = self.frontDevice, let device = AVCaptureDevice.default(front, for: .video, position: .front) else { return }
                    self.activeDevice = device
                default: return
                }
                
                guard let activeDevice else { return }
                
                var formats = activeDevice.formats
     
                if !formats.filter({!$0.secondaryNativeResolutionZoomFactors.filter({$0 == 2.0}).isEmpty}).isEmpty {
                    formats = formats.filter({!$0.secondaryNativeResolutionZoomFactors.filter({$0 == 2.0}).isEmpty})
                }
                
                if !formats.filter({$0.formatDescription.mediaSubType.description == "'420f'"}).isEmpty {
                    formats = formats.filter({$0.formatDescription.mediaSubType.description == "'420f'"})
                }
                
                
                let (bestFormat, bestFrameRateRange) = self.getVideoFormat(from: formats, for: 2160, frameRate: 120)
                
                if let bestFormat = bestFormat {
                    try activeDevice.lockForConfiguration()
                    activeDevice.activeFormat = bestFormat
                    activeDevice.unlockForConfiguration()
                }
                
                let vInput = try AVCaptureDeviceInput(device: activeDevice)
                if self.hardware.session.canAddInput(vInput) { self.hardware.session.addInput(vInput) }
                
                if self.hardware.session.canAddOutput(self.hardware.videoOut) {
                    
                    self.hardware.session.addOutput(self.hardware.videoOut)
                    self.hardware.videoOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                    
                    self.hardware.videoOut.alwaysDiscardsLateVideoFrames = true
                    let videoConnection = self.hardware.videoOut.connection(with: .video)
                    videoConnection?.videoRotationAngle = 90
                    videoConnection?.isVideoMirrored = position == .front ? true : false
                    videoConnection?.preferredVideoStabilizationMode = .standard
                    self.hardware.videoOut.setSampleBufferDelegate(self, queue: self.hardware.videoQueue)
                    
                }
                
                
                if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                   
                    let aDevice = AVCaptureDevice.default(for: .audio)!
                    let aInput = try AVCaptureDeviceInput(device: aDevice)
                    if self.hardware.session.canAddInput(aInput) { self.hardware.session.addInput(aInput) }
                    
                    self.hardware.audioOut.setSampleBufferDelegate(self, queue: self.hardware.videoQueue)
                    if self.hardware.session.canAddOutput(self.hardware.audioOut) { self.hardware.session.addOutput(self.hardware.audioOut) }
                }
                
                self.hardware.session.commitConfiguration()
                self.hardware.session.startRunning()
                 
                guard self.hardware.session.isRunning else { return }
                
                try activeDevice.lockForConfiguration()
                
                if let frameRateRange = bestFrameRateRange {
                    
                    let maxFrameRate = Int32(1/frameRateRange.minFrameDuration.seconds)
                    let rate = min(maxFrameRate, Int32(120))
                    
                    activeDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: rate)
                    activeDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: rate)

                }
                
                if position == .back && backDevice == .wideAngleX2 {
                    activeDevice.videoZoomFactor = 2.0
                } else {
                    activeDevice.videoZoomFactor = 1.0
                }
                
                activeDevice.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.supportedTorchModes = self.getSupportedTorchModes(for: activeDevice)
                }
                
                self.addObservers()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { self.isLockVolumeButtons = false }
                
            } catch {
                print(error.localizedDescription)
            }
            
        }
        
    }
    
    @inlinable
    func stopSession() {
        guard let activeDevice else { return }
        
        if hardware.session.isRunning {
            do {
                try activeDevice.lockForConfiguration()
                if activeDevice.isExposurePointOfInterestSupported { activeDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) }
                if activeDevice.isExposureModeSupported(.continuousAutoExposure) { activeDevice.exposureMode = .continuousAutoExposure }
                activeDevice.setExposureTargetBias(0) { _ in }
                 
                if activeDevice.isFocusPointOfInterestSupported { activeDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
                if activeDevice.isFocusModeSupported(.continuousAutoFocus) { activeDevice.focusMode = .continuousAutoFocus }
                
                activeDevice.unlockForConfiguration()
            } catch {
                print(error.localizedDescription)
            }
            hardware.session.stopRunning()
        }
        
        hardware.session.inputs.forEach{hardware.session.removeInput($0)}
        hardware.session.outputs.forEach{hardware.session.removeOutput($0)}
        
        self.keyValueObservations.forEach{ $0.invalidate() }
        self.keyValueObservations.removeAll()
    }
    
    @inlinable
    func addObservers() {
        guard let activeDevice else { return }
        
        let focusObserver = activeDevice.observe(\.isAdjustingFocus, options: .new) { [weak self] _, value in
            guard let self else { return }
            if let newValue = value.newValue { self.isAdjustingFocus = newValue }
        }
        self.keyValueObservations.append(focusObserver)
        
        let exposureObserver = activeDevice.observe(\.isAdjustingExposure, options: .new) { [weak self] _, value in
            guard let self else { return }
            if let newValue = value.newValue { self.isAdjustingExposure = newValue }
        }
        self.keyValueObservations.append(exposureObserver)
        
        let lensPositionObserver = activeDevice.observe(\.lensPosition, options: .new) { [weak self] _, value in
            guard let self else { return }
            if let newValue = value.newValue { self.lensPosition = newValue }
        }
        self.keyValueObservations.append(lensPositionObserver)
        
        //NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange,  object: activeDevice)
    }
    
    @inlinable
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let key = keyPath else { return }
        switch key {
        case "outputVolume":
            if isLockVolumeButtons { return }
             
            if isWriting { stopWriting() } else { startWriting() }
            
            for view in hardware.preview.subviews {
                for subview in view.subviews {
                    if let slider = subview as? UISlider {
                        self.isLockVolumeButtons = true
                        print("Set volume to 0.5")
                        slider.setValue(0.5, animated: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { self.isLockVolumeButtons = false }
                    }
                }
            }
        
        default: break
        }
    }
    
    @inlinable
    func getVideoFormat(from formats: [AVCaptureDevice.Format], for resolution: Int, frameRate: Int) -> (AVCaptureDevice.Format?, AVFrameRateRange?){
        
        var result: (AVCaptureDevice.Format?, AVFrameRateRange?) = (nil, nil)
        
        for format in formats {
            
            let height = format.formatDescription.dimensions.height
            let width = format.formatDescription.dimensions.width
            
            var needWidth: Int32 = 1280
            
            if resolution == 1080 { needWidth = 1920 }
            else if resolution == 2160 { needWidth = 3840 }
            
            for range in format.videoSupportedFrameRateRanges {
                if height == resolution && width == needWidth {
                    if range.maxFrameRate >= Float64(frameRate) { return (format, range) }
                    else { result = (format, range) }
                }
            }
        }
        
        return result
    }
    
    @inlinable
    func getSupportedTorchModes(for device: AVCaptureDevice) -> [AVCaptureDevice.TorchMode]{
        var supportedModes: [AVCaptureDevice.TorchMode] = []
        
        if device.isTorchModeSupported(.off) { supportedModes.append(.off)}
        if device.isTorchModeSupported(.on) { supportedModes.append(.on)}
        if device.isTorchModeSupported(.auto) { supportedModes.append(.auto)}
        
        return supportedModes
    }
    
    @inlinable
    func load(lut: String) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            
            guard let url = Bundle.main.url(forResource: lut, withExtension: "data"),
                  let data = try? Data(contentsOf: url)
            else {
                await MainActor.run { self.cubeBuffer = nil }
                return
            }
            
            guard data.count % 4 == 0, !data.isEmpty
            else {
                await MainActor.run { self.cubeBuffer = nil }
                return
            }
            
            let size = Int(cbrtf(Float(data.count/16)))
            let sizeBuffer = self.hardware.device.makeBuffer(bytes: [size], length: MemoryLayout<Int>.size)!
            
            var bytes = [UInt8]()
            bytes.append(contentsOf: data)
            
            let buffer = self.hardware.device.makeBuffer(bytes: bytes, length: data.count/4 * MemoryLayout<Float>.stride, options: [])!
            
            await MainActor.run { self.cubeBuffer = (sizeBuffer, buffer) }
        }
    }
     
    @inlinable
    func setupWriter(for range: VideoDynamicRange, with format: VideoFormat) {
        
        guard let activeDevice = self.activeDevice else { return }

        var format = format
        
        guard let width = hardware.videoOut.videoSettings["Width"] as? Int else { return }
        guard let height = hardware.videoOut.videoSettings["Height"] as? Int else { return }
        let frameRate = Int(1/activeDevice.activeVideoMinFrameDuration.seconds)
        
        if height > 2100 && frameRate > 30 { format = .hevc }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let date = dateFormatter.string(from: Date())
        let fileName = "video_\(date)"
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(fileName).\(format == .mp4 ? "MP4" : "MOV")")
        
        guard var vSettings = self.hardware.videoOut.recommendedVideoSettingsForAssetWriter(writingTo: format == .mp4 ? .mp4 : .mov) else { return }
    
        var compressionSettings: [String: Any] = vSettings["AVVideoCompressionPropertiesKey"] as! [String: Any]
        compressionSettings["ExpectedFrameRate"] = frameRate
        
        compressionSettings["AverageBitRate"] = Int(0.125/activeDevice.activeVideoMinFrameDuration.seconds)*width*height
        
        switch range {
        case .sdr:
            compressionSettings["ProfileLevel"] = kVTProfileLevel_HEVC_Main_AutoLevel
            vSettings[AVVideoColorPropertiesKey] = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                                  AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                                       AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]
        case .hdr10:
            compressionSettings["ProfileLevel"] = kVTProfileLevel_HEVC_Main10_AutoLevel
            vSettings[AVVideoColorPropertiesKey] = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                                                  AVVideoTransferFunctionKey: AVVideoTransferFunction_SMPTE_ST_2084_PQ,
                                                       AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020]
        case .dolbyVision:
            compressionSettings["ProfileLevel"] = kVTProfileLevel_HEVC_Main10_AutoLevel
            vSettings[AVVideoColorPropertiesKey] = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                                                  AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                                                       AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020]
        }
        
        vSettings["AVVideoCompressionPropertiesKey"] = compressionSettings
        
        
        do {
            self.assetWriter = try AVAssetWriter(url: url, fileType: format == .mp4 ?  AVFileType.mp4 : AVFileType.mov)
            self.vInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: vSettings)
            self.vInput?.expectsMediaDataInRealTime = true
            self.vInput?.mediaTimeScale = CMTimeScale(600)
            vInput?.transform = CGAffineTransform(rotationAngle: 0)
            
            guard vInput != nil else { return }
            
            let sourcePixelBufferAttributes:[String:AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey as String:NSNumber(value: Int32(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)),
                kCVPixelBufferWidthKey as String:NSNumber(value: width),
                kCVPixelBufferHeightKey as String:NSNumber(value: height)
            ]
            
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
            if self.assetWriter?.canAdd(vInput!) == true { assetWriter?.add(vInput!) }
            
            if let aSettings = self.hardware.audioOut.recommendedAudioSettingsForAssetWriter(writingTo: format == .mp4 ? .mp4 : .mov) {
                self.aInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: aSettings)
                self.aInput?.expectsMediaDataInRealTime = true
                guard aInput != nil else { return }
                if self.assetWriter?.canAdd(aInput!) == true { assetWriter?.add(aInput!) }
            }

            self.assetWriter?.startWriting()
            
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    @inlinable
    func canWrite() -> Bool {
        return isWriting && assetWriter != nil && assetWriter?.status == .writing
    }
    
    @inlinable
    func startWriting() {
        hardware.writeQueue.async {
            self.setupWriter(for: .sdr, with: .mp4)
            guard !self.isWriting else { return }
            AudioServicesPlaySystemSound(self.beginCapture)
            DispatchQueue.main.async { self.isWriting = true }
            self.sessionAtSourceTime = nil
            
        }
    }
    
    @inlinable
    func stopWriting() {
        guard isWriting else { return }
        isWriting = false
        AudioServicesPlaySystemSound(endCapture)
        self.vInput?.markAsFinished()
        self.aInput?.markAsFinished()
        
        Task {
            await self.assetWriter?.finishWriting()
            self.sessionAtSourceTime = nil
            guard let url = self.assetWriter?.outputURL else { return }
            
            let asset = AVAsset(url: url)
            
            if let thumbnail = generateThumbnail(from: url) {
                VideoStorageManager.shared.addThumbnail(thumbnail)
            }
            
            let fileName = url.deletingPathExtension().lastPathComponent
            
            VideoStorageManager.shared.addVideo(url: url, name: fileName)
            
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    try FileManager.default.removeItem(at: url)
                    return
                }
            } catch {
                print(error.localizedDescription)
                return
            }
            
            self.assetWriter = nil
            self.adaptor = nil
            self.vInput = nil
            self.aInput = nil
        }
    }
        
    func generateThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)

        let time = CMTimeMake(value: 1, timescale: 60)
        do {
            let cgImage = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}

enum VideoDynamicRange: String {
    case sdr = "SDR"
    case hdr10 = "HDR10"
    case dolbyVision = "Dolby Vision"
}

enum VideoFormat: String {
    case mp4 = "H.264"
    case hevc = "HEVC"
}




