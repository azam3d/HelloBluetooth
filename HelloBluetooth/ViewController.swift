
import AVFoundation
import CoreBluetooth
import Photos
import UIKit

class ViewController: UIViewController {
    
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoConnection : AVCaptureConnection?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }

    private var centralManager: CBCentralManager!
    private var myPeripheral: CBPeripheral!
    var targetService: CBService?
    var writableCharacteristic: CBCharacteristic?
    var isConnected = false
    
    @IBOutlet weak var sendTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
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
        previewLayer?.videoGravity = .resizeAspectFill
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
            writeValue(data: text)
        }
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
    
    @IBAction func connectBluetooth(_ sender: Any) {
        if isConnected {
            centralManager.cancelPeripheralConnection(myPeripheral)
            print("Disconnected")
        } else {
            centralManager.connect(myPeripheral, options: nil)
            print("Connected")
        }
        isConnected = !isConnected
    }
    
    private func writeValue(data: String){
        let data = data.data(using: .utf8)
        
        guard let characteristic = writableCharacteristic else {
            return
        }
        myPeripheral.writeValue(data!, for: characteristic, type: .withoutResponse)
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

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth ON")
            central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth switched off or not initialized")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let pname = peripheral.name {
            if pname == "Revo" {
                centralManager.stopScan()
                
                myPeripheral = peripheral
                myPeripheral.delegate = self
                centralManager.connect(peripheral, options: nil)
                
                print("Bluetooth connected \(pname)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        myPeripheral.discoverServices(nil)
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        targetService = services.first
        if let service = services.first {
            targetService = service
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writableCharacteristic = characteristic
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let dataString = String(data: characteristic.value!, encoding: String.Encoding.utf8)
        
        if let dataString = dataString?.trimmingCharacters(in: .whitespacesAndNewlines)  {
            print("dataString: \(dataString)")
            
            if dataString == "shoot" {
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
        }
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
