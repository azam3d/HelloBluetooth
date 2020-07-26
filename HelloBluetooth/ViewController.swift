
import CoreBluetooth
import UIKit

class ViewController: UIViewController {

    private var centralManager: CBCentralManager!
    private var myPeripheral: CBPeripheral!
    var targetService: CBService?
    var writableCharacteristic: CBCharacteristic?
    
    @IBOutlet weak var sendTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    @IBAction func sendData(_ sender: Any) {
        if let text = sendTextField.text {
            writeValue(data: text)
        }
    }
    
    func writeValue(data: String){
        let data = data.data(using: .utf8)
        
        guard let characteristic = writableCharacteristic else {
            return
        }
        myPeripheral.writeValue(data!, for: characteristic, type: .withoutResponse)
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
        
        if let dataString = dataString {
            navigationItem.title = dataString
            print(dataString)
        }
    }
}
