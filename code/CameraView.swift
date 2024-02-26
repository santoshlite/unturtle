import SwiftUI
import SceneKit

struct BodyLandmarks3D {
    var topHead: SCNVector3?
    var centerHead: SCNVector3?
    var centerShoulder: SCNVector3?
    var rightShoulder: SCNVector3?
    var leftShoulder: SCNVector3?
}


struct CameraView: UIViewControllerRepresentable {
    var onLandmarksDetected: (BodyLandmarks3D) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.pointsProcessorHandler = { landmarks in
            self.onLandmarksDetected(landmarks) 
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}



