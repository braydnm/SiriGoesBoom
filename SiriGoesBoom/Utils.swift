//
//  Utils.swift
//  UEBoom
//
//  Created by Braydn Moore on 2020-05-02.
//  Copyright © 2020 Braydn Moore. All rights reserved.
//

import Foundation
import Combine

// 2 way dictionary used for mapping characteristics to their usage
struct BiDictionary<F:Hashable,T:Hashable>
{
   private var _forward  : [F:T]? = nil
   private var _backward : [T:F]? = nil

   var forward:[F:T]
   {
      mutating get
      {
        _forward = _forward ?? [F:T](uniqueKeysWithValues:_backward?.lazy.map{($1,$0)} ?? [] )
        return _forward!
      }
      set { _forward = newValue; _backward = nil }
   }

   var backward:[T:F]
   {
      mutating get
      {
        _backward = _backward ?? [T:F](uniqueKeysWithValues:_forward?.lazy.map{($1,$0)} ?? [] )
        return _backward!
      }
      set { _backward = newValue; _forward = nil }
   }

   init(_ dict:[F:T] = [:])
   { forward = dict  }

   init(_ values:[(F,T)])
   { forward = [F:T](uniqueKeysWithValues:values) }

   subscript(_ key:T) -> F?
   { mutating get { return backward[key] } set{ backward[key] = newValue } }

   subscript(_ key:F) -> T?
   { mutating get { return forward[key]  } set{ forward[key]  = newValue } }

   subscript(to key:T) -> F?
   { mutating get { return backward[key] } set{ backward[key] = newValue } }

   subscript(from key:F) -> T?
   { mutating get { return forward[key]  } set{ forward[key]  = newValue } }

   var count:Int { return _forward?.count ?? _backward?.count ?? 0 }
}
