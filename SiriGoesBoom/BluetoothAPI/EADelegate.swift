//
//  EADelegate.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-03.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation

// External accessory delegate which implements a function to handle a new message
protocol EADelegate {
    func handleNewMessage(_ msg: Message)
}
