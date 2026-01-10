//
//  Fonts.swift
//  WAY_GYM
//
//  Created by soyeonsoo on 6/2/25.
//

import SwiftUI

enum FontName: String {
    case PixelRegular = "NeoDunggeunmoPro-Regular"
}

extension Font {
    static let countdown: Font = .custom(FontName.PixelRegular.rawValue, size: 128)
    
    static let largeTitle01: Font = .custom(FontName.PixelRegular.rawValue, size: 44)
    static let largeTitle02: Font = .custom(FontName.PixelRegular.rawValue, size: 40)
    
    static let title01: Font = .custom(FontName.PixelRegular.rawValue, size: 24)
    static let title02: Font = .custom(FontName.PixelRegular.rawValue, size: 20)
    static let title03: Font = .custom(FontName.PixelRegular.rawValue, size: 18)
    
    static let text01: Font = .custom(FontName.PixelRegular.rawValue, size: 16)
    static let text02: Font = .custom(FontName.PixelRegular.rawValue, size: 14)

}
