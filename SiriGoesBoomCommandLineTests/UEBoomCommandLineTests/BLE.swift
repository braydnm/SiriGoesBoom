//
//  BLE.swift
//  UEBoomCommandLineTests
//
//  Created by Braydn Moore on 2020-04-30.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//


import Foundation
import CoreBluetooth

let VALID_BYTES: [Data] = [
Data([0x00, 0x0D, 0x44] as [UInt8]),
Data([0x88, 0xC6, 0x26] as [UInt8]),
Data([0x00, 0x02, 0x5B] as [UInt8]),
Data([0xC0, 0x28, 0x8D] as [UInt8]),
Data([0xEC, 0x81, 0x43] as [UInt8]),
]

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

open class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    
    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: nil)
            print("Powered on")
        case .poweredOff:
            central.stopScan()
        case .unsupported: fatalError("Unsupported BLE module")
        default: break
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    private func is_valid_bt_address(_ addr: Data) -> Bool{
        for i in 0..<VALID_BYTES.count{
            if addr.subdata(in: 0..<3) == VALID_BYTES[i]{
                return true
            }
        }
        
        return false
    }
    
    private func is_valid_ueboom(_ advertisementData: [String : Any]) -> Data? {
        let data = advertisementData["kCBAdvDataManufacturerData"] as? Data
        
        if data == nil{
            return nil
        }
        
        let manufacturer_data = data!
        let beginning_test = UInt16(manufacturer_data[0])<<8 + UInt16(manufacturer_data[1])
        if manufacturer_data.count >= 0x14 && beginning_test == 768 {
            if is_valid_bt_address(manufacturer_data.subdata(in: 14..<20)){
                return manufacturer_data.subdata(in: 14..<20)
            }
            else if (manufacturer_data.count >= 0x21 && is_valid_bt_address(manufacturer_data.subdata(in: 27..<33))){
                return manufacturer_data.subdata(in: 27..<33)
            }
        }
        
        else if manufacturer_data.count >= 0x6 && is_valid_bt_address(manufacturer_data.subdata(in: 0..<6)){
            return manufacturer_data.subdata(in: 0..<6)
        }
        
        return nil
        
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[*] Disconnected")
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[*] Failed to connect")
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[*] Got connection")
        print(peripheral.discoverServices([CBUUID(string: "757ED3E4-1828-4A0C-8362-C229C3A6DA72"), CBUUID(string: "000061FE-0000-1000-8000-00805F9B34FB")]))
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let bt_address: Data? = is_valid_ueboom(advertisementData)
        
        if bt_address != nil {
            print(bt_address!.hexEncodedString())
            targetPeripheral = peripheral
            targetPeripheral?.delegate = self
            print("[*] Connecting")
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
    }
    
}
