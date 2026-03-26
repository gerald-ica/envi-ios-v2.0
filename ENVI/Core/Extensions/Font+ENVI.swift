import SwiftUI
import UIKit

extension Font {
    // MARK: - Inter Weights
    static func interRegular(_ size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }

    static func interMedium(_ size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }

    static func interSemiBold(_ size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }

    static func interBold(_ size: CGFloat) -> Font {
        .custom("Inter-Bold", size: size)
    }

    static func interExtraBold(_ size: CGFloat) -> Font {
        .custom("Inter-ExtraBold", size: size)
    }

    static func interBlack(_ size: CGFloat) -> Font {
        .custom("Inter-Black", size: size)
    }

    // MARK: - Space Mono Weights
    static func spaceMono(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Regular", size: size)
    }

    static func spaceMonoBold(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Bold", size: size)
    }
}

extension UIFont {
    static func interRegular(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-Regular", size: size) ?? .systemFont(ofSize: size, weight: .regular)
    }

    static func interMedium(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    static func interSemiBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-SemiBold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }

    static func interBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }

    static func interExtraBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-ExtraBold", size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    }

    static func interBlack(_ size: CGFloat) -> UIFont {
        UIFont(name: "Inter-Black", size: size) ?? .systemFont(ofSize: size, weight: .black)
    }

    static func spaceMono(_ size: CGFloat) -> UIFont {
        UIFont(name: "SpaceMono-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func spaceMonoBold(_ size: CGFloat) -> UIFont {
        UIFont(name: "SpaceMono-Bold", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
