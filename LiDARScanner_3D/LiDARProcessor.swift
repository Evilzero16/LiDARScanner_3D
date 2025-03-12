import ARKit

class LiDARProcessor {
    static func extractPointCloud(from frame: ARFrame) -> [(Float, Float, Float)]? {
        guard let sceneDepth = frame.sceneDepth else { return nil }
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        var pointCloud: [(Float, Float, Float)] = []

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!.assumingMemoryBound(to: Float32.self)

        for y in 0..<height {
            for x in 0..<width {
                let depth = baseAddress[y * width + x]
                let worldPoint = simd_make_float3(Float(x), Float(y), depth)
                pointCloud.append((worldPoint.x, worldPoint.y, worldPoint.z))
            }
        }

        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

        return pointCloud
    }
}
