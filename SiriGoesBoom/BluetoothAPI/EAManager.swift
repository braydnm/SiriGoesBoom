//
//  EAManager.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-03.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import ExternalAccessory


// External Accessory Manager provided as a read and write stream to the delegate

class EAManager: NSObject, EAAccessoryDelegate, StreamDelegate{
    var _accessory: EAAccessory?
    var _session: EASession?
    var _protocolString: String?
    var _writeData: Data
    var _readData: Data
    var delegate: EADelegate?
    
    // MARK: Init
    override init() {
        _writeData = Data()
        _readData = Data()
        super.init()
    }
    
    // MARK: Controller Setup
    func setupController(forAccessory accessory: EAAccessory, withProtocolString protocolString: String) {
        _accessory = accessory
        _protocolString = protocolString
    }
    
    // MARK: Opening & Closing Sessions
    func openSession() -> Bool {
        _accessory?.delegate = self
        _session = EASession(accessory: _accessory!, forProtocol: _protocolString!)
        
        // open a stream for reading and writing individually and start a thread for each
        if _session != nil {
            _session?.inputStream?.delegate = self
            _session?.inputStream?.schedule(in: RunLoop.current, forMode: .default)
            _session?.inputStream?.open()
            
            _session?.outputStream?.delegate = self
            _session?.outputStream?.schedule(in: RunLoop.current, forMode: .default)
            _session?.outputStream?.open()
        } else {
            print("Failed to create session")
        }
        
        return _session != nil
    }
    
    // clean up the stream / threads
    func closeSession() {
        _session?.inputStream?.close()
        _session?.inputStream?.remove(from: RunLoop.current, forMode: .default)
        _session?.inputStream?.delegate = nil
        
        _session?.outputStream?.close()
        _session?.outputStream?.remove(from: RunLoop.current, forMode: .default)
        _session?.outputStream?.delegate = nil
        
        _session = nil
    }
    
    // MARK: - Helpers
    func updateReadData() {
        let bufferSize = 128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        // read all the bytes in the buffer
        while _session?.inputStream?.hasBytesAvailable == true {
            let bytesRead = _session?.inputStream?.read(&buffer, maxLength: bufferSize)
            _readData.append(buffer, count: bytesRead!)
        }
        
        // read all the complete messages received and publish them to the delegate
        while _readData.count >= 3{
            // create a copy of the data to prevent concurrent accesses, because I'm like 99% sure this is the problem
            let copyData = Data(_readData)
            let msgSize = Int(copyData[0])+1
            if msgSize > copyData.count{
                break
            }
            
            if delegate != nil{
                delegate?.handleNewMessage(Message(Data(copyData.subdata(in: 0..<msgSize))))
                _readData = _readData.dropFirst(msgSize)
            }
        }
    }
    
    // write data over the stream
    private func writeData() {
        while (_session?.outputStream?.hasSpaceAvailable)! == true && _writeData.count > 0 {
            var buffer = [UInt8](_writeData)
            let bytesWritten = _session?.outputStream?.write(&buffer, maxLength: _writeData.count)
            if bytesWritten == -1 || bytesWritten == nil{
                print("Write Error")
                return
            } else{
                _writeData = _writeData.dropFirst(bytesWritten!)
            }
        }
    }
    
    func writeData(data: Data) {
        print("Sending \(data.hexEncodedString())")
        _writeData.append(data)
        self.writeData()
    }
    
    // MARK: - NSStreamDelegateEventExtensions
    // stream function implementation
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            break
        case Stream.Event.hasBytesAvailable:
            // Read Data
            updateReadData()
            break
        case Stream.Event.hasSpaceAvailable:
            // Write Data
            self.writeData()
            break
        case Stream.Event.errorOccurred:
            break
        case Stream.Event.endEncountered:
            break
            
        default:
            break
        }
    }
}
