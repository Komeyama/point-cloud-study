//
//  ViewController.swift
//  point-cloud-study
//
//  Created by YoneyamaShunpei on 2021/08/09.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    private var avSession: AVCaptureSession = AVCaptureSession()
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
        setUpDepthOutput()
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
        
    private func setUpDepthOutput() {
        depthOutput.isFilteringEnabled = true
        if avSession.canAddOutput(depthOutput) {
            avSession.addOutput(depthOutput)
        }
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [depthOutput])
        outputSynchronizer!.setDelegate(self, queue: captureQueue)
    }
}

extension ViewController: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData else {
            return
        }

        let depthData = syncedDepthData.depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthDataMap = depthData.depthDataMap
       
        let ciImage = CIImage(cvPixelBuffer: depthDataMap).oriented(.leftMirrored)
        let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: .leftMirrored)
        
        upDateImageView(uiImage)
    }
    
    private func upDateImageView(_ image: UIImage) {
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
}
