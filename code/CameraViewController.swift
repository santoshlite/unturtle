import AVFoundation
import UIKit
import Vision
import SceneKit

enum errors: Error{
    case CameraError
}

final class CameraViewController : UIViewController{
    
    private var cameraFeedSession: AVCaptureSession?
    
    private let bodyPoseRequest: VNDetectHumanBodyPose3DRequest = VNDetectHumanBodyPose3DRequest()
    
    
    override func loadView() {
        view = CameraPreview()
    }
    
    private var cameraView: CameraPreview{ view as! CameraPreview}
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do{
            
            if cameraFeedSession == nil{
                try setupAVSession()
                
                cameraView.previewLayer.session = cameraFeedSession
                cameraView.previewLayer.videoGravity = .resizeAspectFill
            }
            
            DispatchQueue.global(qos: .userInteractive).async {
                self.cameraFeedSession?.startRunning()
            }
            
        }catch{
            print(error.localizedDescription)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewDidDisappear(animated)
    }
    
    private let videoDataOutputQueue =
    DispatchQueue(label: "CameraFeedOutput", qos: .userInteractive)
    
    
    func setupAVSession() throws {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw errors.CameraError
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else{
            throw errors.CameraError
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        guard session.canAddInput(deviceInput) else{
            throw errors.CameraError
        }
        
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput){
            session.addOutput(dataOutput)
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        }else{
            throw errors.CameraError
        }
        
        session.commitConfiguration()
        cameraFeedSession = session
    }
    
    var pointsProcessorHandler: ((BodyLandmarks3D) -> Void)?
}



extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyPoseRequest])
            
            guard let observation = bodyPoseRequest.results?.first as? VNHumanBodyPose3DObservation else { return }
            
            let bodyLandmarks = processObservation(observation)            
            DispatchQueue.main.async {
                self.pointsProcessorHandler?(bodyLandmarks)
            }
        } catch {
            print("Failed to perform body pose request: \(error.localizedDescription)")
        }
    }
    
    func processObservation(_ observation: VNHumanBodyPose3DObservation) -> BodyLandmarks3D {
        
        var landmarks = BodyLandmarks3D()
        
        func convert2Vector(_ name: VNHumanBodyPose3DObservation.JointName) -> SCNVector3? {
            do {
                let positionMatrix = try observation.cameraRelativePosition(name)
                return SCNVector3(
                    positionMatrix.columns.3.x, 
                    positionMatrix.columns.3.y, 
                    positionMatrix.columns.3.z
                )
            } catch {
                print("Error getting cameraRelativePosition for \(name): \(error)")
                return nil
            }
        }
        landmarks.topHead = convert2Vector(.topHead)
        landmarks.centerHead = convert2Vector(.centerHead)
        landmarks.rightShoulder = convert2Vector(.rightShoulder)
        landmarks.leftShoulder = convert2Vector(.leftShoulder)
        landmarks.centerShoulder = convert2Vector(.centerShoulder)
        
        return landmarks
    }
}
