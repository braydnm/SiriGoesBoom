//
//  UEBLE.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-02.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import CoreBluetooth
import ExternalAccessory

// valid bytes to identify spakers
let VALID_BYTES: [Data] = [
Data([0x00, 0x0D, 0x44] as [UInt8]),
Data([0x88, 0xC6, 0x26] as [UInt8]),
Data([0x00, 0x02, 0x5B] as [UInt8]),
Data([0xC0, 0x28, 0x8D] as [UInt8]),
Data([0xEC, 0x81, 0x43] as [UInt8]),
]

// A 2 way dictionary between the UUID of a characteristic and what it is used for
var CHARACTERISTICS = BiDictionary([CBUUID(string: "c6d6dc0d-07f5-47ef-9b59-630622b01fd3") : "power", CBUUID(string: "16e005bb-3862-43c7-8f5c-6f654a4ffdd2") : "alarm", CBUUID(string: "2A19") : "battery", CBUUID(string: "2A00") : "name", CBUUID(string: "2A24") : "colour", CBUUID(string: "2A25") : "serial" , CBUUID(string: "2A28") : "firmware", CBUUID(string: "69c0f621-1354-4cf8-98a6-328b8faa1897") : "broadcaster", CBUUID(string: "2A1A") : "powerState"
])

// 2 main service IDs
let SERVICES = [CBUUID(string: "757ED3E4-1828-4A0C-8362-C229C3A6DA72"), CBUUID(string: "000061FE-0000-1000-8000-00805F9B34FB")]

// Timeout for toggling the device power
let CONNECT_TIMEOUT = 20

// Serializable information for storing the speaker
public struct SpeakerPersistantInformation : Codable{
    var name: Data?
    var serial: Data?
    var model: Data?
    var firmware: Data?
    var address: Int
}

// Speaker Delegate class
open class Speaker : NSObject, CBPeripheralDelegate, ObservableObject, EADelegate{
    
    // MARK: Static Helper Functions
    // check if it is a valid UE Boom address
    private static func is_valid_bt_address(_ addr: Data) -> Bool{
        for i in 0..<VALID_BYTES.count{
            if addr.subdata(in: 0..<3) == VALID_BYTES[i]{
                return true
            }
        }
        
        return false
    }
    
    // check if it is a valid UE Boom device
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
    
    // convert a MAC address string to an integer
    static func mac_address_to_int(macAddress: String) -> Int?{
        return Int(macAddress.replacingOccurrences(of: ":", with: ""), radix: 16)
    }
    
    
    // MARK: Bluetooth properties
    // BLE and Core Bluetooth managers
    var peripheral: CBPeripheral?
    var externalAccessoryManager: EAManager?
    
    // device bluetooth MAC address
    var bt_address: Int
    
    // array of known characteristics
    var characteristics: [CBCharacteristic]?
    // timer to timeout the toggling of the power
    var changingConnectionTimer: Timer?
    
    // MARK: Published values
    // Connected BLE is for when the speaker is connected via bluetooth low energy mode
    // Connected is for when the speaker is connected via regular bluetooth, it is marked with published to change the power on power off button view
    @Published var connected_ble: Bool
    @Published var connected: Bool
    // used to show the loading indicator in the views
    @Published var isChangingConnection: Bool
    // used for alerts of timeouts
    @Published var failed_to_change_connection: Bool
    
    // general information published in a view
    @Published var _firmware: Data?
    @Published var _serial: Data?
    @Published var _name: Data?
    @Published var _battery: Data?
    @Published var _model: Data?
    
    
    // MARK: Getters
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
    
    var model: String? {get {
        if _model != nil{
            return String(decoding: _model!, as: UTF8.self)
        }
        
        return nil
    }}
    
    var identifier: UUID? {get {peripheral?.identifier}}
    var isPresent: Bool {get {self.connected || self.connected_ble}}
    
    // MARK: Init
    public init(info: SpeakerPersistantInformation) {
        connected_ble = false
        connected = false
        isChangingConnection = false
        failed_to_change_connection = false
        _model = info.model
        _name = info.name
        _serial = info.serial
        _firmware = info.firmware
        bt_address = info.address
        
        super.init()
    }
    
    public init(_ accessory: EAAccessory){
        connected_ble = false
        connected = true
        isChangingConnection = false
        failed_to_change_connection = false
        _model = accessory.modelNumber.data(using: .utf8)
        _name = accessory.name.data(using: .utf8)
        _serial = accessory.serialNumber.data(using: .utf8)
        _firmware = accessory.firmwareRevision.data(using: .utf8)
        bt_address = Speaker.mac_address_to_int(macAddress: accessory.value(forKey: "macAddress") as? String ?? "0")!
        print("Connected Speaker ADDR: \(String(format: "%llX", bt_address))")
        
        super.init()
        self.openAccessory(accessory)
    }
    
    // MARK: Persistantce Information
    // information stored for the speaker
    public func getPeristantInformation() -> SpeakerPersistantInformation{
        return SpeakerPersistantInformation.init(name: self._name, serial: self._serial, model: self._model, firmware: self._firmware, address: self.bt_address)
    }
    
    // MARK: BLE Peripheral Functions
    public func addPeripheral(peripheral: CBPeripheral, myAddr: Data){
        self.peripheral = peripheral
        peripheral.delegate = self
    }
    
    // on a characteristic being read and the value being updated if it is a supported characteristic and if the value has changed, if so change the field
    // these changes will be propogated up to the main view
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let property = CHARACTERISTICS[characteristic.uuid]
        if property == "serial" && self._serial != characteristic.value{
            self._serial = characteristic.value
        }
        else if property == "name" && self._name != characteristic.value{
            self._name = characteristic.value
        }
        else if property == "firmware" && self._name != characteristic.value{
            self._firmware = characteristic.value
        }
        else if property == "battery" && self._battery != characteristic.value{
            self._battery = characteristic.value
        }
    }
    
    // when we discover a new characteristic check if it is one we want to read from, and if so attempt to read it
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let want_to_read = ["name", "serial", "firmware", "battery"]
        self.characteristics = service.characteristics
        for char in want_to_read{
            let to_read = self.characteristics!.first{$0.uuid == CHARACTERISTICS[char]}
            if to_read != nil{
                self.peripheral?.readValue(for: to_read!)
            }
        }
    }
    
    // if we discovered a service discover the characteristics associated with it
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.discoverCharacteristics(Array(CHARACTERISTICS.forward.keys), for: peripheral.services![0])
    }
    
    // attempt to discover the main BLE service
    public func discoverServices(){
        if peripheral != nil{
            peripheral!.discoverServices(SERVICES)
        }
    }
    
    // MARK: Regular Bluetooth Functions
    private func onConnect(){
        // check if we need to invalidate the connect timeout timer
        if self.changingConnectionTimer != nil{
            self.changingConnectionTimer!.invalidate()
        }
        
        // set our boolean values to update the view
        self.connected = true
        self.isChangingConnection = false
        
        // request our source bluetooth mac address
        self.sendMessage(Message(0x1AC, data: Data()))
        // request the battery power
        self.requestPowerLevel()
    }
    
    private func onDisconnect(){
        // check if we need to invalidate the connect timeout timer
        if self.changingConnectionTimer != nil{
            self.changingConnectionTimer!.invalidate()
        }
        
        // set our boolean values to update the view
        self.connected = false
        self.isChangingConnection = false
    }
    
    // This is our on connect function
    func openAccessory(_ accessory: EAAccessory){
        // setup our stream reader/writer
        self.externalAccessoryManager = EAManager()
        self.externalAccessoryManager?.setupController(forAccessory: accessory, withProtocolString: accessory.protocolStrings[0])
        // set ourselves as the delegate to receive the message
        self.externalAccessoryManager?.delegate = self
        let _ = self.externalAccessoryManager?.openSession()
        // call our on connect setup
        self.onConnect()
    }
    
    // clean up our read/write bluetooth stream
    func closeAccessory(){
        self.externalAccessoryManager?.closeSession()
        self.onDisconnect()
    }
    
    // right now we really only use 2 responses, the iPhone source address and the name of the speaker
    func handleNewMessage(_ msg: Message) {
        switch msg.id {
        // Get the source address for the speaker
        case 0x1AD:
            // if the source address received is different than the stored one, update
            if BluetoothManager.sourceAddress == nil || BluetoothManager.sourceAddress! != msg.processData() as? Data{
                BluetoothManager.sourceAddress = msg.processData() as? Data
            }
            break
            
        // Get the name of the speaker
        case 0x16E:
            // update the name of the speaker which will propogate to the main view
            self._name = msg.processData() as? Data
            break
        default:
            print("Unhandled message of type: \(msg.id)")
        }
    }
    
    // send a message
    func sendMessage(_ msg: Message){
        if self.connected{
            self.externalAccessoryManager!.writeData(data: msg.getMsgData())
        }
    }
    
    //MARK: Power Functions
    
    @objc func failed_to_change_connection_type(){
        print("Failed to connect")
        self.failed_to_change_connection = true
        self.isChangingConnection = false
    }
    
    func power_on(_ timeout: Int = CONNECT_TIMEOUT){
        // update our UI to say we are connecting
        self.isChangingConnection = true
        self.connected = false
        
        // start a timer to fire the timeout event
        self.changingConnectionTimer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(failed_to_change_connection_type), userInfo: nil, repeats: false)
    
        
        // send the power on message
        // wait for us to reconnect or be connected over bluetooth BLE
        while !self.connected_ble{}
        
        if BluetoothManager.sourceAddress == nil{
            print("[x] Error: Cannot power on speaker because I don't even know my own source address")
            return
        }
        
        // write the power on message to the BLE characteristic
        print("Sending power on")
        var command = Data(BluetoothManager.sourceAddress!)
        command.append(0x01)
        self.peripheral?.writeValue(command, for: self.characteristics!.first{$0.uuid == CHARACTERISTICS["power"]}!, type: .withResponse)
    }
    
    func power_off(_ timeout: Int = CONNECT_TIMEOUT){
        // notify the view of our attempt
        self.isChangingConnection = true
        self.connected = true
        
        // start our timer for timeout
        self.changingConnectionTimer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(failed_to_change_connection_type), userInfo: nil, repeats: false)
        
        // send our message
        self.sendMessage(Message(0x1B6, data: Data()))
    }
    
    func togglePower(_ timeout: Int = CONNECT_TIMEOUT){
        if self.connected{
            self.power_off(timeout)
        }
        else{
            self.power_on(timeout)
        }
        print("Done")
    }
    
    //MARK: Utils
    // rename the device and send the message
    func rename(name: String){
        var new_name = name.data(using: .utf8)!
        new_name.append(0x00)
        // change the name
        self.sendMessage(Message(0x16F, data: new_name))
        // request the new name
        self.sendMessage(Message(0x16D, data: Data()))
    }
    
    // request the device power level, this seems to be depreciated with my speaker??
    func requestPowerLevel(){
        self.sendMessage(Message(0x214, data: Data()))
    }
}
