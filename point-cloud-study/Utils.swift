//
//  Utils.swift
//  point-cloud-study
//
//  Created by YoneyamaShunpei on 2021/08/17.
//

import Foundation
import MetalKit

class Utils {
        
    static func toRadians(degree: Float) -> Float {
        return (1.0 / 180.0) * .pi * degree
    }
    
    static func perspectiveProjectionConversion(fovy: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    
        let angle: Float = toRadians(degree: 0.5 * fovy)
        let yScale: Float = 1.0 / tan(angle)
        let xScale: Float = yScale / aspect
        let zScale: Float = far / (far - near)
        
        let P: simd_float4 = simd_float4([xScale, 0.0, 0.0, 0.0])
        let Q: simd_float4 = simd_float4([0.0, yScale, 0.0, 0.0])
        let R: simd_float4 = simd_float4([0.0, 0.0, zScale, 1.0])
        let S: simd_float4 = simd_float4([0.0, 0.0, -near * zScale, 0.0])
        
        return simd_float4x4([P, Q, R, S])
    }
    
    static func lookAt(eye: simd_float3, middle: simd_float3, up: simd_float3) -> simd_float4x4 {
        
        let zAxis: simd_float3 = simd_normalize(middle - eye)
        let xAxis: simd_float3 = simd_normalize(simd_cross(up, zAxis))
        let yAxis: simd_float3 = simd_cross(zAxis, xAxis)
        
        let P: simd_float4 = simd_float4([xAxis.x, yAxis.x, zAxis.x, 0.0])
        let Q: simd_float4 = simd_float4([xAxis.y, yAxis.y, zAxis.y, 0.0])
        let R: simd_float4 = simd_float4([xAxis.z, yAxis.z, zAxis.z, 0.0])
        let S: simd_float4 = simd_float4(-simd_dot(xAxis, eye), -simd_dot(yAxis, eye), -simd_dot(zAxis, eye), 1.0)
        
        return simd_float4x4([P, Q, R, S])
    }
    
    static func rotate(angle: Float, r: simd_float3) -> simd_float4x4 {
        
        let a: Float = angle * (1.0 / 180.0) * .pi
        var c: Float = 0.0
        var s: Float = 0.0
        
        __sincospif(a, &s, &c)
        
        let k: Float = 1.0 - c
        let u: simd_float3 = simd_normalize(r)
        let v: simd_float3 = s * u
        let w: simd_float3 = k * u
        
        let P: simd_float4 = simd_float4([
            w.x * u.x + c,
            w.x * u.y + v.z,
            w.x * u.z - v.y,
            0.0
        ])
        let Q: simd_float4 = simd_float4([
            w.x * u.y - v.z,
            w.y * u.y + c,
            w.y * u.z + c,
            0.0
        ])
        let R: simd_float4 = simd_float4([
            w.x * u.z + v.y,
            w.y * u.z - v.x,
            w.z * u.z + c,
            0.0
        ])
        let S: simd_float4 = simd_float4([0.0, 0.0, 0.0, 1.0])
        
        return simd_float4x4([P, Q, R, S])
    }
    
}
