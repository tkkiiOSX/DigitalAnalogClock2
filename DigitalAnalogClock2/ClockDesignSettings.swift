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
            return "丸枠(Circle)"

        case .rectangle:
            return "角枠(Rectangle)"

        case .roundedRectangle:
            return "角丸枠(Rounded Rectangle)"
        }
    }
}

@MainActor
final class ClockDesignSettings: ObservableObject {
    private let keyPrefix: String

    private var sharedDefaults: UserDefaults {
        SharedClockStorage.defaults
    }

    @Published var frameStyle: ClockFrameStyle {
        didSet {
            sharedDefaults.set(
                frameStyle.rawValue,
                forKey: full(Keys.frameStyle)
            )
            notifyWidget()
        }
    }

    @Published var frameColor: Color {
        didSet {
            saveColor(
                frameColor,
                key: full(Keys.frameColor)
            )
            notifyWidget()
        }
    }

    @Published var hourHandColor: Color {
        didSet {
            saveColor(
                hourHandColor,
                key: full(Keys.hourHandColor)
            )
            notifyWidget()
        }
    }

    @Published var minuteHandColor: Color {
        didSet {
            saveColor(
                minuteHandColor,
                key: full(Keys.minuteHandColor)
            )
            notifyWidget()
        }
    }

    @Published var secondHandColor: Color {
        didSet {
            saveColor(
                secondHandColor,
                key: full(Keys.secondHandColor)
            )
            notifyWidget()
        }
    }

    @Published var backgroundColor: Color {
        didSet {
            saveColor(
                backgroundColor,
                key: full(Keys.backgroundColor)
            )
            notifyWidget()
        }
    }

    @Published var backgroundImageData: Data? {
        didSet {
            let imageKey = full(Keys.backgroundImage)

            if let backgroundImageData {
                _ = SharedClockStorage.saveBackgroundImage(
                    backgroundImageData,
                    forKey: imageKey
                )

                // 写真本体は共有フォルダへ保存するため、
                // UserDefaultsには残しません。
                sharedDefaults.removeObject(
                    forKey: imageKey
                )
            } else {
                SharedClockStorage.removeBackgroundImage(
                    forKey: imageKey
                )

                sharedDefaults.removeObject(
                    forKey: imageKey
                )
            }

            notifyWidget()
        }
    }

    @Published var numeralStyle: NumeralStyle {
        didSet {
            sharedDefaults.set(
                numeralStyle.rawValue,
                forKey: full(Keys.numeralStyle)
            )
            notifyWidget()
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

        let key: (String) -> String = { name in
            keyPrefix + name
        }

        let defaults = SharedClockStorage.defaults

        if let rawValue = defaults.string(
            forKey: key(Keys.frameStyle)
        ),
        let savedFrameStyle = ClockFrameStyle(
            rawValue: rawValue
        ) {
            frameStyle = savedFrameStyle
        } else {
            frameStyle = .circle
        }

        frameColor = Self.loadColor(
            key: key(Keys.frameColor),
            defaultColor: .cyan
        )

        hourHandColor = Self.loadColor(
            key: key(Keys.hourHandColor),
            defaultColor: .blue
        )

        minuteHandColor = Self.loadColor(
            key: key(Keys.minuteHandColor),
            defaultColor: .green
        )

        secondHandColor = Self.loadColor(
            key: key(Keys.secondHandColor),
            defaultColor: .red
        )

        backgroundColor = Self.loadColor(
            key: key(Keys.backgroundColor),
            defaultColor: Color(
                .sRGB,
                red: 0.7,
                green: 0.85,
                blue: 0.98
            )
        )

        let imageKey = key(Keys.backgroundImage)

        if let sharedImageData = SharedClockStorage
            .loadBackgroundImage(forKey: imageKey) {
            backgroundImageData = sharedImageData
        } else if let legacyImageData = defaults.data(
            forKey: imageKey
        ) {
            // 旧UserDefaults保存データを共有ファイルへ移行
            backgroundImageData = legacyImageData

            _ = SharedClockStorage.saveBackgroundImage(
                legacyImageData,
                forKey: imageKey
            )

            defaults.removeObject(
                forKey: imageKey
            )
        } else {
            backgroundImageData = nil
        }

        if let rawValue = defaults.string(
            forKey: key(Keys.numeralStyle)
        ),
        let savedNumeralStyle = NumeralStyle(
            rawValue: rawValue
        ) {
            numeralStyle = savedNumeralStyle
        } else {
            numeralStyle = .latin
        }
    }

    func deleteBackgroundImage() {
        backgroundImageData = nil
    }

    func removeAllStoredSettings() {
        let defaults = SharedClockStorage.defaults

        defaults.removeObject(
            forKey: full(Keys.frameStyle)
        )
        defaults.removeObject(
            forKey: full(Keys.frameColor)
        )
        defaults.removeObject(
            forKey: full(Keys.hourHandColor)
        )
        defaults.removeObject(
            forKey: full(Keys.minuteHandColor)
        )
        defaults.removeObject(
            forKey: full(Keys.secondHandColor)
        )
        defaults.removeObject(
            forKey: full(Keys.backgroundColor)
        )
        defaults.removeObject(
            forKey: full(Keys.numeralStyle)
        )

        SharedClockStorage.removeBackgroundImage(
            forKey: full(Keys.backgroundImage)
        )

        defaults.removeObject(
            forKey: full(Keys.backgroundImage)
        )

        notifyWidget()
    }

    private func saveColor(
        _ color: Color,
        key: String
    ) {
        guard let components = color.rgbaComponents else {
            return
        }

        sharedDefaults.set(
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
        guard let values = SharedClockStorage.defaults.array(
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

    private func notifyWidget() {
        SharedClockStorage.reloadWidget()
    }

    private func full(_ key: String) -> String {
        keyPrefix + key
    }

    private enum Keys {
        static let frameStyle = "frameStyle"
        static let frameColor = "frameColor"
        static let hourHandColor = "hourHandColor"
        static let minuteHandColor = "minuteHandColor"
        static let secondHandColor = "secondHandColor"
        static let backgroundColor = "backgroundColor"
        static let backgroundImage = "backgroundImage"
        static let numeralStyle = "numeralStyle"
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
