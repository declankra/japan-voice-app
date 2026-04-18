import SwiftUI

enum AppTheme {
    static let appBackground = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.44)

    static let activePane = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let inactivePane = Color.black
    static let activePaneText = Color.black.opacity(0.88)
    static let activePaneSecondaryText = Color.black.opacity(0.56)
    static let inactivePaneText = Color.white
    static let inactivePaneSecondaryText = Color.white.opacity(0.58)

    static let divider = Color.white.opacity(0.18)
    static let controlStroke = Color.white.opacity(0.24)
    static let controlFill = Color.white
    static let statusCapsuleDark = Color.white.opacity(0.08)
    static let statusCapsuleLight = Color.black.opacity(0.08)
    static let statusBorder = Color.white.opacity(0.12)
}
