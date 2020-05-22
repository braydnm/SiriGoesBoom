//
//  Message.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-03.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation

// Message protocol when the device is connected over core bluetooth
// follows the following format

/*
 | UInt8 - Message Size (2 + Data.length) |
 | UInt16 - Message ID*                   |
 | [UInt8] - Message Data                 |
 */
public class Message: NSObject{
    
    var id: UInt16
    var length: UInt8
    private var data: Data
    
    var rawData: Data {get{data}}
    
    public init(_ msgData: Data) {
        length = msgData[0]
        id = (UInt16(msgData[1]) << 8) + UInt16(msgData[2])
        data = msgData.advanced(by: 3)
    }
    
    public init(_ commandID: UInt16, data: Data){
        self.id = commandID
        self.data = data
        self.length = UInt8(2 + data.count)
    }
    
    public func processData() -> Any?{
        return data
    }
    
    public func getMsgData() -> Data{
        var ret = Data()
        ret.append(length)
        ret.append(withUnsafeBytes(of: self.id.bigEndian) { Data($0) })
        ret.append(self.data)
        return ret
    }
    
}
