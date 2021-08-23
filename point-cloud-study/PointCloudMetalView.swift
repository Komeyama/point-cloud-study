//
//  PointCloudMetalView.swift
//  point-cloud-study
//
//  Created by YoneyamaShunpei on 2021/08/14.
//

import Foundation
import Metal
import MetalKit
import AVFoundation

class PointCloudMetalView: MTKView {
    
    var syncQueue: DispatchQueue = DispatchQueue(label: "queue", qos: .default)
    var depthTextureCache: CVMetalTextureCache? = nil
    var colorTextureCache: CVMetalTextureCache? = nil
    var middle: simd_float3 = simd_float3.init()
    var eye: simd_float3 = simd_float3.init()
    var up: simd_float3 = simd_float3.init()
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    var currentFarValue: Float = Utils().initFarValue
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        setUp()
    }
    
    func update(_ depthData: AVDepthData, withTexture unormTexture: CVPixelBuffer) {
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
        
        let depthFrame = depthData.depthDataMap
        
        var cvDepthTexture: CVMetalTexture? = nil
        if (kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                          depthTextureCache!,
                                                                          depthFrame,
                                                                          nil,
                                                                          .r16Float,
                                                                          CVPixelBufferGetWidth(depthFrame),
                                                                          CVPixelBufferGetHeight(depthFrame),
                                                                          0,
                                                                          &cvDepthTexture)) {
            return
        }
        let depthTexture = CVMetalTextureGetTexture(cvDepthTexture!)!
        
        var cvColorTexture: CVMetalTexture? = nil
        if (kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                          colorTextureCache!,
                                                                          unormTexture,
                                                                          nil,
                                                                          .bgra8Unorm,
                                                                          CVPixelBufferGetWidth(unormTexture),
                                                                          CVPixelBufferGetHeight(unormTexture),
                                                                          0,
                                                                          &cvColorTexture)){
            return
        }
        let colorTexture: MTLTexture = CVMetalTextureGetTexture(cvColorTexture!)!
        
        var intrinsics: matrix_float3x3 = depthData.cameraCalibrationData!.intrinsicMatrix
        let referenceDimensions: CGSize = depthData.cameraCalibrationData!.intrinsicMatrixReferenceDimensions
        
        let ratio: CGFloat = referenceDimensions.width / CGFloat(CVPixelBufferGetWidth(depthFrame))
        intrinsics.columns.0[0] /= Float(ratio)
        intrinsics.columns.1[1] /= Float(ratio)
        intrinsics.columns.2[0] /= Float(ratio)
        intrinsics.columns.2[1] /= Float(ratio)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = currentRenderPassDescriptor
        
        if (renderPassDescriptor != nil) {
            let depthTextureDescriptor = MTLTextureDescriptor()
            depthTextureDescriptor.width = Int(drawableSize.width)
            depthTextureDescriptor.height = Int(drawableSize.height)
            depthTextureDescriptor.pixelFormat = self.depthStencilPixelFormat
            depthTextureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
            
            let depthTestTexture = device?.makeTexture(descriptor: depthTextureDescriptor)
            renderPassDescriptor?.depthAttachment.loadAction = MTLLoadAction.clear
            renderPassDescriptor?.depthAttachment.storeAction = MTLStoreAction.store
            renderPassDescriptor?.depthAttachment.clearDepth = 1.0
            renderPassDescriptor?.depthAttachment.texture = depthTestTexture
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
            renderEncoder?.setDepthStencilState(depthStencilState)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setVertexTexture(depthTexture, index: 0)
            
            var finalViewMatrix: simd_float4x4 = getFinalViewMatrix()
            renderEncoder?.setVertexBytes(&finalViewMatrix, length: MemoryLayout<matrix_float4x4>.stride, index: 0)
            renderEncoder?.setVertexBytes(&intrinsics, length: MemoryLayout<matrix_float3x3>.stride, index: 1)
            renderEncoder?.setFragmentTexture(colorTexture, index: 0)
            renderEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: CVPixelBufferGetWidth(depthFrame) * CVPixelBufferGetHeight(depthFrame))
            renderEncoder?.endEncoding()
            commandBuffer.present(currentDrawable!)
        }
        
        commandBuffer.commit()
    }
    
    func yawAroundCenter(_ angle: Float) {
        syncQueue.sync {
            let rotMat = Utils.rotate(angle: angle, r: self.up)

            self.eye -= self.middle
            self.eye = matrix4_mul_vector3(m: rotMat, v: self.eye)
            self.eye += self.middle

            self.up = matrix4_mul_vector3(m: rotMat, v: self.up)
        }
    }
    
    func pitchAroundCenter(_ angle: Float) {
        syncQueue.sync {
            let viewDirection = simd_normalize(self.middle - self.eye)
            let rightVector = simd_cross(self.up, viewDirection)
            let rotMat = Utils.rotate(angle: angle, r: rightVector)
            
            self.eye -= self.middle;
            self.eye = matrix4_mul_vector3(m: rotMat, v: self.eye)
            self.eye += self.middle;
            self.up = matrix4_mul_vector3(m: rotMat, v: self.up);
        }
    }

    private func setUp() {
        configureMetal()
        resetView()
        createMetalTextureCache()
    }
    
    private func createMetalTextureCache() {
        CVMetalTextureCacheCreate(nil, nil, device!, nil, &colorTextureCache)
        CVMetalTextureCacheCreate(nil, nil, device!, nil, &depthTextureCache)
    }
    
    private func resetView() {
        middle = [0, 0, 500]
        eye = [0, 0, 0]
        up = [-1, 0, 0]
    }
    
    private func configureMetal() {
        let defaultLibrary = device?.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShaderPoints")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShaderPoints")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat
        renderPipelineState = try! device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        let depthPipelineDescriptor = MTLDepthStencilDescriptor()
        depthPipelineDescriptor.isDepthWriteEnabled = true
        depthPipelineDescriptor.depthCompareFunction = .less
        depthStencilState = device!.makeDepthStencilState(descriptor: depthPipelineDescriptor)
        
        commandQueue = device!.makeCommandQueue()!
    }
    
    private func getFinalViewMatrix() -> simd_float4x4 {
        let aspect: Float = Float(drawableSize.width / drawableSize.height)
        
        let appleProjMat: simd_float4x4 = Utils.perspectiveProjectionConversion(fovy: 70, aspect: aspect, near: 0.01, far: currentFarValue)
        let appleViewMat: simd_float4x4 = Utils.lookAt(eye: eye, middle: middle, up: up)
        
        return appleProjMat * appleViewMat
    }
    
    private func matrix4_mul_vector3(m: simd_float4x4, v: SIMD3<Float>) -> SIMD3<Float> {
        var temp: SIMD4<Float> = [v.x, v.y, v.z, 0.0]
        temp = simd_mul(m, temp)
        return [temp.x, temp.y, temp.z]
    }
}
