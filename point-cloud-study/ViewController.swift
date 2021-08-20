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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setUpVideo()
    }

    private func setUpVideo() {
        setUpVideoInput()
        setUpVideoAndDepthOutput()
        
        avSession.sessionPreset = .vga640x480
        avSession.startRunning()
    }

    private func setUpVideoInput() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        ).devices
        let videoInput = try! AVCaptureDeviceInput(device: devices.first!)
        if avSession.canAddInput(videoInput) {
            avSession.addInput(videoInput)
        }
    }

    private func setUpVideoAndDepthOutput() {
        if avSession.canAddOutput(videoDataOutput) {
            avSession.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        }

        depthOutput.isFilteringEnabled = true
        if avSession.canAddOutput(depthOutput) {
            avSession.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = false
        }
                
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthOutput])
        outputSynchronizer!.setDelegate(self, queue: captureQueue)
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
