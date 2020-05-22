//
//  UEBLE.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-02.
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


var CHARACTERISTICS = BiDictionary([CBUUID(string: "c6d6dc0d-07f5-47ef-9b59-630622b01fd3") : "power", CBUUID(string: "16e005bb-3862-43c7-8f5c-6f654a4ffdd2") : "alarm", CBUUID(string: "2A19") : "battery", CBUUID(string: "2A00") : "name", CBUUID(string: "2A24") : "colour", CBUUID(string: "2A25") : "serial" , CBUUID(string: "2A28") : "firmware", CBUUID(string: "69c0f621-1354-4cf8-98a6-328b8faa1897") : "broadcaster", CBUUID(string: "2A1A") : "powerState"
])

let SERVICES = [CBUUID(string: "757ED3E4-1828-4A0C-8362-C229C3A6DA72"), CBUUID(string: "000061FE-0000-1000-8000-00805F9B34FB")]

open class Speaker : NSObject, CBPeripheralDelegate, ObservableObject, EADelegate{
    private static func is_valid_bt_address(_ addr: Data) -> Bool{
        for i in 0..<VALID_BYTES.count{
            if addr.subdata(in: 0..<3) == VALID_BYTES[i]{
                return true
            }
        }
        
        return false
    }
    
    static func is_valid_ueboom(_ advertisementData: [String : Any]) -> Data? {
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
    
    
    var peripheral: CBPeripheral
    private var lastAnnounce: TimeInterval
    private var sourceAddr: Data
    var haveInformation: Bool
    var connected: Bool
    
    @Published var _firmware: Data?
    @Published var _serial: Data?
    @Published var _name: Data?
    @Published var _battery: Data?
    
    var firmware: String? {get{
        if _firmware != nil{
            return String(format: "%d.%d.%d", UInt8(_firmware![0]), UInt8(_firmware![1]), UInt8(_firmware![2]))
        }
        return nil
    }}
    var serial: String? {get {
        if _serial != nil{
            return String(decoding: _serial!, as: UTF8.self)
        }
        return nil
    }}
    var name: String? {get {
        if _name != nil{
            return String(decoding: _name!, as: UTF8.self)
        }
        return nil
    }}
    var battery: UInt8? {get {
        if _battery != nil{
            return UInt8(_battery![0])
        }
        
        return nil
    }}
    
    private var power_on_descriptor: CBCharacteristic?
    
    var identifier: UUID {get {peripheral.identifier}}
    var expired: Bool {get {self.lastAnnounce + 30 <= NSDate().timeIntervalSince1970}}
    
    public init(peripheral: CBPeripheral, my_addr: Data) {
        self.peripheral = peripheral
        lastAnnounce = NSDate().timeIntervalSince1970
        haveInformation = false
        connected = false
        sourceAddr = my_addr
        super.init()
        peripheral.delegate = self
    }
    
    public func updateAnnounce(){
        self.lastAnnounce = NSDate().timeIntervalSince1970
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let property = CHARACTERISTICS[characteristic.uuid]
        if property == "serial"{
            self._serial = characteristic.value
        }
        else if property == "name"{
            self._name = characteristic.value
        }
        else if property == "firmware"{
            self._firmware = characteristic.value
        }
        else if property == "battery"{
            self._battery = characteristic.value
        }
        else if property == "power"{
            self.power_on_descriptor = characteristic
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics!{
            peripheral.readValue(for: char)
        }
        haveInformation = true
        print("[*] Read all characteristics for \(peripheral.identifier)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.discoverCharacteristics(Array(CHARACTERISTICS.forward.keys), for: peripheral.services![0])
    }
    
    public func discoverServices(){
        peripheral.discoverServices(SERVICES)
    }
    
    public func turn_on(_ centralDelegate: BLE){
        var power_on_command = Data(sourceAddr)
        power_on_command.append(0x01)
        print(power_on_command.hexEncodedString())
        print(self.power_on_descriptor!)
        peripheral.writeValue(power_on_command, for: self.power_on_descriptor!, type: .withResponse)
    }
    
    
}

extension Speaker: PropertyReflectable{}
