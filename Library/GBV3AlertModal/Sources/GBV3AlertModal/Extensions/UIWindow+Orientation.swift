//
//  UIWindow+Orientation.swift
//  GBV3AlertModal
//
//  Created by engineering on 15/12/23.
//

import Foundation
import UIKit

// Taken from XlPagerTabStrip
// use UIApplication.sharedApplication().statusBarOrientation instead of UIDevice.currentDevice().orientation
extension UIWindow {
    static var isLandscape: Bool {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows
                .first?
                .windowScene?
                .interfaceOrientation
                .isLandscape ?? false
        } else {
            return UIApplication.shared.statusBarOrientation.isLandscape
        }
    }
    static var isPortrait: Bool {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows
                .first?
                .windowScene?
                .interfaceOrientation
                .isPortrait ?? false
        } else {
            return UIApplication.shared.statusBarOrientation.isPortrait
        }
    }
}
