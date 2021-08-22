//
//  ViewController.swift
//  point-cloud-study
//
//  Created by YoneyamaShunpei on 2021/08/09.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var cloudView: PointCloudMetalView!
    private var avSession: AVCaptureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var depthOutput: AVCaptureDepthDataOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private var captureQueue: DispatchQueue = DispatchQueue(label: "captureQueue")
    private var defaultVideoDevice: AVCaptureDevice?
    
    private var lastXY: CGPoint = CGPoint(x: 0, y: 0)
    private var lastScale: Float = 1.0
    private var lastZoom: Float = 0.0
    private var initFarValue: Float = Utils().initFarValue
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpVideo()
        setUpGesture()
        setUpUIComponents()
    }

    @IBAction private func handlePanOneFinger(gesture: UIPanGestureRecognizer) {
        if gesture.numberOfTouches != 1 {
            return
        }

        if gesture.state == .began {
            let pnt: CGPoint = gesture.translation(in: cloudView)
            lastXY = pnt
        } else if (.failed != gesture.state) && (.cancelled != gesture.state) {
            let pnt: CGPoint = gesture.translation(in: cloudView)
            cloudView.yawAroundCenter(Float((pnt.x - lastXY.x) * 0.1))
            cloudView.pitchAroundCenter(Float((pnt.y - lastXY.y) * 0.1))
            lastXY = pnt
        }
    }
    
    @objc func onChangeSliderValue(_ sender: UISlider) {
        cloudView.currentFarValue = sender.value
    }
    
    private func setUpUIComponents() {
        let width = view.frame.width
        let height = view.frame.height
        setUpUISlider(viewWidth: width, viewHeight: height)
    }
    
    private func setUpUISlider(viewWidth: CGFloat, viewHeight: CGFloat) {
        let slider = UISlider()
        slider.minimumValue = 100
        slider.maximumValue = 30000
        slider.value = initFarValue
        slider.frame = CGRect(x: viewWidth * 0.1, y: viewHeight * 0.8, width: viewWidth * 0.8, height: viewHeight * 0.1)
        slider.addTarget(self, action: #selector(onChangeSliderValue(_:)), for: .valueChanged)
        view.addSubview(slider)
    }

    private func setUpVideo() {
        setUpVideoInput()
        setUpVideoAndDepthOutput()
        setUpActiveDepthDataFormat()
        avSession.startRunning()
    }

    private func setUpVideoInput() {
        let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        
        defaultVideoDevice = videoDeviceDiscoverySession.devices.first
        let videoInput = try! AVCaptureDeviceInput(device: videoDeviceDiscoverySession.devices.first!)
        
        avSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        if avSession.canAddInput(videoInput) {
            avSession.addInput(videoInput)
        }
    }

    private func setUpVideoAndDepthOutput() {
        
        if avSession.canAddOutput(videoDataOutput) {
            avSession.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }
        
        if avSession.canAddOutput(depthOutput) {
            avSession.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = false
        }
        
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthOutput])
        outputSynchronizer!.setDelegate(self, queue: captureQueue)
    }
    
    private func setUpActiveDepthDataFormat() {
        let depthFormats = defaultVideoDevice?.activeFormat.supportedDepthDataFormats
        let depthFloat16Formats = depthFormats?.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
        })
        let selectedFormat = depthFloat16Formats?.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        })
        
        try! defaultVideoDevice?.lockForConfiguration()
        defaultVideoDevice?.activeDepthDataFormat = selectedFormat
        defaultVideoDevice?.unlockForConfiguration()
    }
    
    private func setUpGesture() {
        let panOneFingerGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanOneFinger))
        panOneFingerGesture.maximumNumberOfTouches = 1
        panOneFingerGesture.minimumNumberOfTouches = 1
        cloudView.addGestureRecognizer(panOneFingerGesture)
    }
}

extension ViewController: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {

        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
            return
        }

        let depthData = syncedDepthData.depthData
        let sampleBuffer = syncedVideoData.sampleBuffer
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
        }
        cloudView.update(depthData, withTexture: videoPixelBuffer)
    }

}
