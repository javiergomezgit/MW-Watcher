//
//  AVAudioPlayer+Extension.swift
//  Bullish Square
//
//  Created by Javier Gomez on 8/11/25.
//
import AVFoundation


extension AVAudioPlayer {
    private struct AssociatedKeys {
        static var numberOfHeadlines = "numberOfHeadlines"
    }
    
    var numberOfHeadlines: Int? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.numberOfHeadlines) as? Int }
        set { objc_setAssociatedObject(self, &AssociatedKeys.numberOfHeadlines, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
