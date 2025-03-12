import UIKit
import ARKit
import simd
import UniformTypeIdentifiers

struct Point3D: Hashable {
    let x: Float
    let y: Float
    let z: Float
}

class ViewController: UIViewController, ARSessionDelegate, UIDocumentPickerDelegate {
    
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var depthImageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!

    let arSession = ARSession()
    var pointCloud: Set<Point3D> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        guard arView != nil, stopButton != nil, saveButton != nil else {
            fatalError("❌ UI elements not connected in Storyboard")
        }

        setupARSession()
        setupUI()
    }

    func setupARSession() {
        let config = ARWorldTrackingConfiguration()

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = .sceneDepth
        }

        arSession.run(config)
        arView.session = arSession
        arSession.delegate = self
    }

    func setupUI() {
        stopButton.layer.cornerRadius = 10
        stopButton.backgroundColor = .red
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.isUserInteractionEnabled = true

        saveButton.layer.cornerRadius = 10
        saveButton.backgroundColor = .blue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.isUserInteractionEnabled = true
    }
    
    
    @IBAction func stopScanning(_ sender: UIButton) {
        print("🚨 stopScanning function called!") // Debugging
        stopButton.isHidden = true
        arSession.pause()
        print("✅ Scanning stopped.")
    }
    
    @IBAction func saveAndShare(_ sender: UIButton) {
        print("💾 saveAndShare function called!") // Debugging
        exportPointCloudWithPicker()
    }


    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        let camera = frame.camera
        let interfaceTransform = camera.viewMatrix(for: .landscapeRight).inverse

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!.assumingMemoryBound(to: Float32.self)
        
        var newPoints: Set<Point3D> = []

        for y in stride(from: 0, to: height, by: 3) {
            for x in stride(from: 0, to: width, by: 3) {
                let depth = baseAddress[y * width + x]

                if depth > 0 {
                    // Convert (x, y) pixel coordinates to normalized device coordinates (NDC)
                    let ndcX = (Float(x) / Float(width)) * 2.0 - 1.0
                    let ndcY = (Float(y) / Float(height)) * 2.0 - 1.0

                    // Transform depth into world coordinates
                    let ndcPoint = simd_float4(ndcX, ndcY, depth, 1.0)
                    let worldPoint = interfaceTransform * ndcPoint
                    
                    newPoints.insert(Point3D(x: worldPoint.x, y: worldPoint.y, z: worldPoint.z))
                }
            }
        }

        pointCloud.formUnion(newPoints)
    }

    func exportPointCloudWithPicker() {
        guard !pointCloud.isEmpty else {
            print("❌ No points to save!")
            return
        }

        let fileName = "pointcloud.ply"
        var plyData = "ply\nformat ascii 1.0\nelement vertex \(pointCloud.count)\nproperty float x\nproperty float y\nproperty float z\nend_header"

        for point in pointCloud {
            plyData += "\n\(point.x) \(point.y) \(point.z)"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try plyData.write(to: tempURL, atomically: true, encoding: .utf8)
            print("📂 File saved successfully at: \(tempURL.path)")

            let picker = UIDocumentPickerViewController(forExporting: [tempURL])
            picker.delegate = self
            picker.modalPresentationStyle = .formSheet
            DispatchQueue.main.async {
                self.present(picker, animated: true, completion: nil)
            }
        } catch {
            print("❌ Failed to write PLY file: \(error.localizedDescription)")
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let fileURL = urls.first {
            print("✅ File saved at: \(fileURL.path)")
        } else {
            print("❌ Failed to save file")
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("❌ User cancelled file selection.")
    }
}
