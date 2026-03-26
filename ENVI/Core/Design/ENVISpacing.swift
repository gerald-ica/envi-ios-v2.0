import SwiftUI

/// Spacing and corner radius tokens for the ENVI design system.
enum ENVISpacing {
    static let xs: CGFloat   = 4
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let lg: CGFloat   = 16
    static let xl: CGFloat   = 20
    static let xxl: CGFloat  = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 48
}

/// Corner radius tokens — 8-14px rounded rectangles, NO capsule shapes.
enum ENVIRadius {
    static let sm: CGFloat   = 8    // Chips
    static let md: CGFloat   = 10   // Input fields
    static let lg: CGFloat   = 12   // Cards, buttons
    static let xl: CGFloat   = 14   // Bottom sheets, tab bar
}
