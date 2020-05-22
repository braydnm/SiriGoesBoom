//
//  BluetoothManager.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-04-30.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

// General / UI libraries
import Foundation
import Combine
// Bluetooth Libraries
import CoreBluetooth
import ExternalAccessory
// Utilities
import Disk

// extend data to be able to print hex for debugging purposes
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

// filename where the known speakers are stored
let SPEAKER_FILENAME = "speakers.json"

// delegate for the static
protocol EAAccessoryManagerDelegate{
    func accessoryDidConnectNotification(_ notification: NSNotification)
    func accessoryDidDisconnectNotification(_ notification: NSNotification)
}

// static class to receive the messages from the ExternalAccessory framework and transmit them to the delegate class
class AccessoryMsgHandler : EAAccessoryManager{
    public static var delegate: EAAccessoryManagerDelegate?
    
    static func start(){
        // add observers for connections and disconnections
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryDidConnectNotification), name: NSNotification.Name.EAAccessoryDidConnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(accessoryDidDisconnectNotification), name: NSNotification.Name.EAAccessoryDidDisconnect, object: nil)
    }
    
    @objc static func accessoryDidConnectNotification(_ notification: NSNotification) {
        if delegate != nil{
            delegate!.accessoryDidConnectNotification(notification)
        }
    }
    
    @objc static func accessoryDidDisconnectNotification(_ notification: NSNotification) {
        if delegate != nil{
            delegate!.accessoryDidDisconnectNotification(notification)
        }
    }
}

//Background queue to synchronize data access
fileprivate let globalBackgroundSyncronizeDataQueue = DispatchQueue(label: "globalBackgroundSyncronizeSharedData")

// Our main bluetooth manager class to handle BLE messaging and Core Bluetooth messages
open class BluetoothManager: NSObject, CBCentralManagerDelegate, ObservableObject, CBPeripheralDelegate, EAAccessoryManagerDelegate {
    
    // the source address variable is used to determine the iPhone bluetooth MAC address used to power the speaker on using BLE, this is discovered and rechecked every time a speaker connects over Core Bluetooth by querying the speaker
    // the public facing variable is a thread-safe getter and setter to prevent thread corruptions or race conditions between speaker threads
    private static var _sourceAddress: Data?
    public static var sourceAddress: Data? {
        set(newVal){
            globalBackgroundSyncronizeDataQueue.sync {
                self._sourceAddress = newVal
            }
        }
        get{
            globalBackgroundSyncronizeDataQueue.sync {
                self._sourceAddress
            }
        }
    }
    
    // Central Bluetooth Manager
    var centralManager: CBCentralManager!
    // List of known speakers, published to the main view to get a card for each known speaker
    @Published var knownSpeakers: [Int:Speaker]
    // A list of cancellables to keep references so don't go out of scope and the ObservedObject events propogate
    var cancellables = [AnyCancellable]()
    
    // MARK: Initialization / Deinit
    public override init() {
        knownSpeakers = [:]
        super.init()
        
        // attempt to read all known speakers in from the stored file
        do{
            let speakerInfo = try Disk.retrieve(SPEAKER_FILENAME, from: .documents, as: [SpeakerPersistantInformation].self)
            for i in 0..<speakerInfo.count{
                let speaker = Speaker(info: speakerInfo[i])
                // sink our objectWillChange with all the items in the array so when they change their data
                // it signals from the BLE manager that something has changed and the ContentView should update
                // this allows for easier signalling than passing multiple values
                cancellables.append(speaker.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }))
                knownSpeakers[speakerInfo[i].address] = speaker
            }
        }
        catch {}
        
        // start the accessory handler
        AccessoryMsgHandler.delegate = self
        AccessoryMsgHandler.start()
        
        // check for any speakers which are already connected before the app started and add them to our list
        var new_speaker = false
        let accessoryManager = EAAccessoryManager.shared()
        for i in 0..<accessoryManager.connectedAccessories.count{
            let bt_address = Speaker.mac_address_to_int(macAddress: accessoryManager.connectedAccessories[i].value(forKey: "macAddress") as? String ?? "0")!
            if knownSpeakers[bt_address] == nil{
                print("Found new speaker connected")
                new_speaker = true
                let speaker = Speaker(accessoryManager.connectedAccessories[i])
                cancellables.append(speaker.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }))
                knownSpeakers[bt_address] = speaker
            }
            else{
                print("Found known speaker already connected")
                knownSpeakers[bt_address]?.connected = true
                knownSpeakers[bt_address]?.openAccessory(accessoryManager.connectedAccessories[i])
            }
        }
        
        // if we find a new speaker make sure to save our new list
        if new_speaker{
            if !self.saveSpeakers(){
                print("[x] Warning: Failed to save the new speakers")
            }
        }
        
        print("Have \(knownSpeakers.keys.count) known speakers")
        
        // Attempt to retrieve the device bluetooth MAC address from the stored file if it is already known
        do{
            BluetoothManager.sourceAddress = try Disk.retrieve("sourceaddress.json", from: .caches, as: Data?.self)
        }catch{
            print("Unable to read my source address from file")
        }
        
        print("My bluetooth mac address is: \(BluetoothManager.sourceAddress?.hexEncodedString())")
    }
    
    // when we want to exit save all the known speakers to the file for next time
    public func closeBluetooth(){
        let _ = self.saveSpeakers()
        do{
            print("Saving source address \(BluetoothManager.sourceAddress?.hexEncodedString())")
            try Disk.save(BluetoothManager.sourceAddress, to: .caches, as: "sourceaddress.json")
        }catch{
            print("Unable to save the source address")
        }
    }
    
    // on start register our central managers
    public func start() {
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        EAAccessoryManager.shared().registerForLocalNotifications()
        print("Registered")
    }
    
    // save all known speakers
    private func saveSpeakers() -> Bool {
        do{
            var speakerPersistantInfo: [SpeakerPersistantInformation] = []
            for speaker in knownSpeakers.values{
                speakerPersistantInfo.append(speaker.getPeristantInformation())
            }
            try Disk.save(speakerPersistantInfo, to: .documents, as: SPEAKER_FILENAME)
        } catch {
            return false
        }
        
        return true
    }
    
    // MARK: Bluetooth Low Energy
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            print("[*] Powered on")
        case .poweredOff:
            central.stopScan()
        case .unsupported: fatalError("Unsupported BLE module")
        default: break
        }
    }
    
    // if a peripheral disconnected on BLE and it is not connected try to reconnect over BLE to make sure it is still in range
    // FIXME: I think this can be handled more efficiently but I don't really know how
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[*] Disconnected from \(peripheral.identifier)")
        let del = peripheral.delegate as? Speaker
        if del != nil && !del!.connected{
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    // if we failed to connect then the device is out of range and set the required variable accordingly
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[*] Failed to connect to \(peripheral.identifier)")
        let del = (peripheral.delegate as? Speaker)
        if del != nil{
            del!.connected_ble = false
        }
    }
    
    // if we did connect try to discover the known services
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[*] Got BLE connection with \(peripheral.identifier)")
        let del = (peripheral.delegate as? Speaker)
        if del != nil{
            print("[*] Discovering services")
            del!.discoverServices()
        }
    }
    
    // if we discover a new BLE peripheral
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // first identify if it is a valid UE Boom by the advertiser information
        let bt_address: Data? = Speaker.is_valid_ueboom(advertisementData)
        
        // if it is a valid speaker
        if bt_address != nil{
            // turn the returned data into the integer key representative to store in the hashmap of known devices
            let high16_id = bt_address?.withUnsafeBytes{$0.load(as: UInt16.self)}
            let low32_id = bt_address?.advanced(by: 2).withUnsafeBytes{$0.load(as: UInt32.self)}
            let id: Int = Int(high16_id!.bigEndian) << 32 + Int(low32_id!.bigEndian)
            // if we have previously connected to this device over Core Bluetooth then procceed and attempt to connect over BLE
            let speaker = knownSpeakers[id]
            if speaker != nil && !speaker!.connected_ble{
                speaker!.connected_ble = true
                speaker!.addPeripheral(peripheral: peripheral, myAddr: bt_address!)
                centralManager.connect(peripheral, options: nil)
            }
        }
    }
    
    // MARK: Bluetooth Connection
    // if a UE Boom speaker connects
    @objc func accessoryDidConnectNotification(_ notification: NSNotification) {
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            // convert the mac address to the key and check if it is a known speaker
            let bt_address = Speaker.mac_address_to_int(macAddress: accessory.value(forKey: "macAddress") as? String ?? "0")!
            if let speaker = knownSpeakers[bt_address]{
                print("Known speaker just connected")
                // stop the connection over BLE
                speaker.connected = true
                // open the accessory
                speaker.openAccessory(accessory)
            }
            else{
                // if we have a new speaker then add it to the known speakers and save our new configuration
                print("New speaker just connected")
                knownSpeakers[bt_address] = Speaker(accessory)
                if self.saveSpeakers(){
                    print("Saved new speaker")
                }
            }
        }
    }
    
    // if a known device disconnects then try to start connecting over BLE to ensure the device is in range
    @objc func accessoryDidDisconnectNotification(_ notification: NSNotification) {
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory{
            let bt_address = Speaker.mac_address_to_int(macAddress: accessory.value(forKey: "macAddress") as? String ?? "0")!
            if let speaker = knownSpeakers[bt_address]{
                print("\(bt_address) disconnected")
                speaker.closeAccessory()
                speaker.connected = false
            }
        }
    }
}
