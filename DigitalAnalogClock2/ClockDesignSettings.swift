import SwiftUI
import UIKit

enum ClockFrameStyle: String, CaseIterable, Identifiable {
    case circle
    case rectangle
    case roundedRectangle

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .circle:
            return "丸枠"
        case .rectangle:
            return "角枠"
        case .roundedRectangle:
            return "角丸枠"
        }
    }
}

@MainActor
final class ClockDesignSettings: ObservableObject {
    @Published var frameStyle: ClockFrameStyle {
        didSet {
            UserDefaults.standard.set(
                frameStyle.rawValue,
                forKey: Keys.frameStyle
            )
        }
    }

    @Published var frameColor: Color {
        didSet {
            saveColor(frameColor, key: Keys.frameColor)
        }
    }

    @Published var hourHandColor: Color {
        didSet {
            saveColor(hourHandColor, key: Keys.hourHandColor)
        }
    }

    @Published var minuteHandColor: Color {
        didSet {
            saveColor(minuteHandColor, key: Keys.minuteHandColor)
        }
    }

    @Published var secondHandColor: Color {
        didSet {
            saveColor(secondHandColor, key: Keys.secondHandColor)
        }
    }

    @Published var backgroundColor: Color {
        didSet {
            saveColor(backgroundColor, key: Keys.backgroundColor)
        }
    }

    @Published var backgroundImageData: Data? {
        didSet {
            if let backgroundImageData {
                UserDefaults.standard.set(
                    backgroundImageData,
                    forKey: Keys.backgroundImage
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: Keys.backgroundImage
                )
            }
        }
    }

    var backgroundImage: UIImage? {
        guard let backgroundImageData else {
            return nil
        }

        return UIImage(data: backgroundImageData)
    }

    init() {
        let defaults = UserDefaults.standard

        if let rawValue = defaults.string(
            forKey: Keys.frameStyle
        ),
           let savedFrameStyle = ClockFrameStyle(
            rawValue: rawValue
           ) {
            frameStyle = savedFrameStyle
        } else {
            frameStyle = .circle
        }

        frameColor = Self.loadColor(
            key: Keys.frameColor,
            defaultColor: .cyan
        )

        hourHandColor = Self.loadColor(
            key: Keys.hourHandColor,
            defaultColor: .blue
        )

        minuteHandColor = Self.loadColor(
            key: Keys.minuteHandColor,
            defaultColor: .green
        )

        secondHandColor = Self.loadColor(
            key: Keys.secondHandColor,
            defaultColor: .red
        )

        backgroundColor = Self.loadColor(
            key: Keys.backgroundColor,
            defaultColor: Color(
                .sRGB,
                red: 0.7,
                green: 0.85,
                blue: 0.98
            )
        )

        backgroundImageData = defaults.data(
            forKey: Keys.backgroundImage
        )
    }

    func deleteBackgroundImage() {
        backgroundImageData = nil
    }

    private func saveColor(
        _ color: Color,
        key: String
    ) {
        guard let components = color.rgbaComponents else {
            return
        }

        UserDefaults.standard.set(
            [
                components.red,
                components.green,
                components.blue,
                components.opacity
            ],
            forKey: key
        )
    }

    private static func loadColor(
        key: String,
        defaultColor: Color
    ) -> Color {
        guard let values = UserDefaults.standard.array(
            forKey: key
        ) as? [Double],
              values.count == 4 else {
            return defaultColor
        }

        return Color(
            .sRGB,
            red: values[0],
            green: values[1],
            blue: values[2],
            opacity: values[3]
        )
    }

    private enum Keys {
        static let frameStyle = "clockDesign.frameStyle"
        static let frameColor = "clockDesign.frameColor"
        static let hourHandColor = "clockDesign.hourHandColor"
        static let minuteHandColor = "clockDesign.minuteHandColor"
        static let secondHandColor = "clockDesign.secondHandColor"
        static let backgroundColor = "clockDesign.backgroundColor"
        static let backgroundImage = "clockDesign.backgroundImage"
    }
}

private struct RGBAComponents {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

private extension Color {
    var rgbaComponents: RGBAComponents? {
        #if os(iOS)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard UIColor(self).getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return nil
        }

        return RGBAComponents(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(alpha)
        )
        #else
        return nil
        #endif
    }
}
