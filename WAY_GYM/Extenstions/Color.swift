//
//  Colors.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//
//
//import UIKit
//
//extension UIColor {
//    static let gang_bg_profile = UIColor(named: "gang_bg_profile")
//    static let gang_black = UIColor(named: "gang_black")
//    static let gang_yellow = UIColor(named: "gang_yellow")
//    static let gang_btn_primary = UIColor(named: "gang_btn_primary")
//    static let gang_highlight = UIColor(named: "gang_highlight")
//}

import SwiftUI

extension Color {
    static let gang_bg_profile = Color("gang_bg_profile")
    static let gang_btn_primary = Color("gang_btn_primary")
    
    static let text_primary = Color("text_primary")
    static let text_secondary = Color("text_secondary")
    
    static let gang_highlight_2 = Color("gang_highlight_2")
    static let gang_highlight_3 = Color("gang_highlight_3")
    
    static let gang_black = Color("gang_black")
    static let gang_black_opacity = Color("gang_black_opacity")
    
    static let gang_bg = Color("gang_bg")
    static let gang_bg_w_opacity = Color("gang_bg_w_opacity")
    
    static let gang_sheet_bg = Color("gang_sheet_bg")
    static let gang_sheet_bg_opacity = Color("gang_sheet_bg_opacity")
    
    static let gang_bg_primary_1 = Color("gang_bg_primary_1")
    static let gang_bg_primary_4 = Color("gang_bg_primary_4")
    static let gang_bg_primary_5 = Color("gang_bg_primary_5")
    static let gang_bg_secondary_2 = Color("gang_bg_secondary_2")
    
    static let gang_text_1 = Color("gang_text_1")
    static let gang_text_2 = Color("gang_text_2")
    
    static let gang_area = Color("gang_area")
    static let success_color = Color("success")
    
    static let gang_start_bg = Color("gang_start_bg")
    
}

extension UIColor {
    static var successColor: UIColor {
        return UIColor(hex: "#4CAF50")
    }
    
    static var gang_area: UIColor {
        return UIColor(hex: "#34C759")
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexFormatted.hasPrefix("#") {
            hexFormatted.remove(at: hexFormatted.startIndex)
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
