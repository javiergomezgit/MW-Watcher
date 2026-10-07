//
//  AVAudioPlayer+Extension.swift
//  Bullish Square
//
//  Created by Javier Gomez on 8/11/25.
//
import AVFoundation


extension AVAudioPlayer {
    ///The key is a byte whose address is the identity. It was a String, and taking the
    ///address of a String is not guaranteed stable - the compiler warns that it exposes the
    ///string's internal storage - so the stored value could fail to be found again.
    private struct AssociatedKeys {
        static var numberOfHeadlines: UInt8 = 0
    }
    
    var numberOfHeadlines: Int? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.numberOfHeadlines) as? Int }
        set { objc_setAssociatedObject(self, &AssociatedKeys.numberOfHeadlines, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
