
import AVFoundation
import CoreBluetooth
import Photos
import UIKit

enum CameraControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
}

class ViewController: UIViewController {
    
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoConnection : AVCaptureConnection?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    var bluetoothManager: BluetoothManager!
    
    @IBOutlet weak var sendTextField: UITextField!
    @IBOutlet weak var connect: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bluetoothManager = BluetoothManager(bluetoothName: "Revo")
        
        bluetoothManager.completion = { [self] in
            captureImage { image, error in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    return
                }
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        }
        setupSession()
        session?.startRunning()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        view.addGestureRecognizer(tap)
    }
    
    @objc private func viewTapped() {
        view.endEditing(true)
    }
    
    func setupSession() {
        session = AVCaptureSession()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front), let session = session else {
            fatalError("No front video camera available")
        }
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspect
        previewLayer?.frame = view.bounds
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        photoOutput = AVCapturePhotoOutput()
        photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
        
        if session.canAddOutput(photoOutput!) {
            session.addOutput(photoOutput!)
        }
        session.startRunning()
    }

    @IBAction func sendData(_ sender: Any) {
        if let text = sendTextField.text {
            bluetoothManager.writeValue(data: text)
        }
    }
    
    @IBAction func connectBluetooth(_ sender: Any) {
        bluetoothManager.switchBluetooth()
        
        if bluetoothManager.isConnected {
            connect.setTitle("Disconnect", for: .normal)
        } else {
            connect.setTitle("Connect", for: .normal)
        }
    }
    
    private func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let session = session, session.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing)
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
     
        photoOutput?.capturePhoto(with: settings, delegate: self)
        photoCaptureCompletionBlock = completion
    }
    
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let imageData = photo.fileDataRepresentation()
        
        if let data = imageData, let image = UIImage(data: data) {
            photoCaptureCompletionBlock?(image, nil)
        } else {
            photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
}
