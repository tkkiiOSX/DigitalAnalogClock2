import SwiftUI
import Combine
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
    private let keyPrefix: String

    @Published var frameStyle: ClockFrameStyle {
        didSet {
            UserDefaults.standard.set(
                frameStyle.rawValue,
                forKey: full(Keys.frameStyle)
            )
        }
    }

    @Published var frameColor: Color {
        didSet {
            saveColor(frameColor, key: full(Keys.frameColor))
        }
    }

    @Published var hourHandColor: Color {
        didSet {
            saveColor(hourHandColor, key: full(Keys.hourHandColor))
        }
    }

    @Published var minuteHandColor: Color {
        didSet {
            saveColor(minuteHandColor, key: full(Keys.minuteHandColor))
        }
    }

    @Published var secondHandColor: Color {
        didSet {
            saveColor(secondHandColor, key: full(Keys.secondHandColor))
        }
    }

    @Published var backgroundColor: Color {
        didSet {
            saveColor(backgroundColor, key: full(Keys.backgroundColor))
        }
    }

    @Published var backgroundImageData: Data? {
        didSet {
            if let backgroundImageData {
                UserDefaults.standard.set(
                    backgroundImageData,
                    forKey: full(Keys.backgroundImage)
                )
            } else {
                UserDefaults.standard.removeObject(
                    forKey: full(Keys.backgroundImage)
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

    init(keyPrefix: String = "clockDesign.") {
        self.keyPrefix = keyPrefix
        let k: (String) -> String = { keyPrefix + $0 }
        let defaults = UserDefaults.standard

        if let rawValue = defaults.string(
            forKey: k(Keys.frameStyle)
        ),
           let savedFrameStyle = ClockFrameStyle(
               rawValue: rawValue
           ) {
            frameStyle = savedFrameStyle
        } else {
            frameStyle = .circle
        }

        frameColor = Self.loadColor(
            key: k(Keys.frameColor),
            defaultColor: .cyan
        )

        hourHandColor = Self.loadColor(
            key: k(Keys.hourHandColor),
            defaultColor: .blue
        )

        minuteHandColor = Self.loadColor(
            key: k(Keys.minuteHandColor),
            defaultColor: .green
        )

        secondHandColor = Self.loadColor(
            key: k(Keys.secondHandColor),
            defaultColor: .red
        )

        backgroundColor = Self.loadColor(
            key: k(Keys.backgroundColor),
            defaultColor: Color(
                .sRGB,
                red: 0.7,
                green: 0.85,
                blue: 0.98
            )
        )

        backgroundImageData = defaults.data(
            forKey: k(Keys.backgroundImage)
        )
    }

    func deleteBackgroundImage() {
        backgroundImageData = nil
    }

    /// 全てのデザイン設定（このkeyPrefixのもの）をUserDefaultsから削除
    func removeAllStoredSettings() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: full(Keys.frameStyle))
        defaults.removeObject(forKey: full(Keys.frameColor))
        defaults.removeObject(forKey: full(Keys.hourHandColor))
        defaults.removeObject(forKey: full(Keys.minuteHandColor))
        defaults.removeObject(forKey: full(Keys.secondHandColor))
        defaults.removeObject(forKey: full(Keys.backgroundColor))
        defaults.removeObject(forKey: full(Keys.backgroundImage))
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

    private func full(_ key: String) -> String { keyPrefix + key }

    private enum Keys {
        static let frameStyle = "frameStyle"
        static let frameColor = "frameColor"
        static let hourHandColor = "hourHandColor"
        static let minuteHandColor = "minuteHandColor"
        static let secondHandColor = "secondHandColor"
        static let backgroundColor = "backgroundColor"
        static let backgroundImage = "backgroundImage"
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
    }
}

