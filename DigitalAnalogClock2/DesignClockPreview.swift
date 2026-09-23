import SwiftUI

struct DesignClockPreview: View {
    @ObservedObject var settings: ClockDesignSettings

    let keepLabelsUpright: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(
                geometry.size.width,
                geometry.size.height
            )

            let handWidth = size * 0.035
            let labelSize = size * 0.075
            let radius = size * 0.43

            ZStack {
                previewBackground(size: size)

                previewFrame(size: size)

                ClockHand(
                    angle: .degrees(35),
                    length: radius * 0.55,
                    color: settings.hourHandColor,
                    minWidth: handWidth,
                    maxWidth: labelSize,
                    label: formatPreviewLabel("10"),
                    labelColor: settings.hourHandColor,
                    keepLabelsUpright: keepLabelsUpright,
                    numeralStyle: settings.numeralStyle
                )

                ClockHand(
                    angle: .degrees(145),
                    length: radius * 0.78,
                    color: settings.minuteHandColor,
                    minWidth: handWidth,
                    maxWidth: labelSize,
                    label: formatPreviewLabel("25"),
                    labelColor: settings.minuteHandColor,
                    keepLabelsUpright: keepLabelsUpright,
                    numeralStyle: settings.numeralStyle
                )

                ClockHand(
                    angle: .degrees(270),
                    length: radius * 0.90,
                    color: settings.secondHandColor,
                    minWidth: handWidth,
                    maxWidth: labelSize,
                    label: formatPreviewLabel("45"),
                    labelColor: settings.secondHandColor,
                    keepLabelsUpright: keepLabelsUpright,
                    numeralStyle: settings.numeralStyle
                )

                Circle()
                    .fill(.yellow)
                    .frame(
                        width: size * 0.10,
                        height: size * 0.10
                    )
                    .shadow(radius: 2)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
        }
    }

    @ViewBuilder
    private func previewBackground(size: CGFloat) -> some View {
        if let image = settings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
                .mask(innerMask(size: size))
        } else {
            settings.backgroundColor
        }
    }

    @ViewBuilder
    private func innerMask(size: CGFloat) -> some View {
        let lineWidth = size * 0.07
        let padding = size * 0.035
        let inset = padding + lineWidth / 2

        switch settings.frameStyle {
        case .circle:
            Circle()
                .padding(inset)

        case .rectangle:
            Rectangle()
                .padding(inset)

        case .roundedRectangle:
            RoundedRectangle(
                cornerRadius: max(
                    0,
                    size * 0.12 - inset
                )
            )
            .padding(inset)
        }
    }

    @ViewBuilder
    func previewFrame(size: CGFloat) -> some View {
        switch settings.frameStyle {
        case .circle:
            Circle()
                .stroke(
                    settings.frameColor,
                    lineWidth: size * 0.07
                )
                .padding(size * 0.035)

        case .rectangle:
            Rectangle()
                .stroke(
                    settings.frameColor,
                    lineWidth: size * 0.07
                )
                .padding(size * 0.035)

        case .roundedRectangle:
            RoundedRectangle(
                cornerRadius: size * 0.12
            )
            .stroke(
                settings.frameColor,
                lineWidth: 0.07 * size
            )
            .padding(size * 0.035)
        }
    }

    private func formatPreviewLabel(_ input: String) -> String {
        let digits = input
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard let value = Int(digits),
              value >= 0,
              value <= 99 else {
            return input
        }

        let normalized = value < 10
            ? String(value)
            : String(format: "%02d", value)

        switch settings.numeralStyle {
        case .latin:
            return normalized

        case .kanji:
            let map: [Character: String] = [
                "0": "〇",
                "1": "一",
                "2": "二",
                "3": "三",
                "4": "四",
                "5": "五",
                "6": "六",
                "7": "七",
                "8": "八",
                "9": "九"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()

        case .hangul:
            let map: [Character: String] = [
                "0": "영",
                "1": "일",
                "2": "이",
                "3": "삼",
                "4": "사",
                "5": "오",
                "6": "육",
                "7": "칠",
                "8": "팔",
                "9": "구"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()

        case .roman:
            return romanNumeral(for: value)

        case .arabicIndic:
            let map: [Character: String] = [
                "0": "٠",
                "1": "١",
                "2": "٢",
                "3": "٣",
                "4": "٤",
                "5": "٥",
                "6": "٦",
                "7": "٧",
                "8": "٨",
                "9": "٩"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()

        case .persian:
            let map: [Character: String] = [
                "0": "۰",
                "1": "۱",
                "2": "۲",
                "3": "۳",
                "4": "۴",
                "5": "۵",
                "6": "۶",
                "7": "۷",
                "8": "۸",
                "9": "۹"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()

        case .devanagari:
            let map: [Character: String] = [
                "0": "०",
                "1": "१",
                "2": "२",
                "3": "३",
                "4": "४",
                "5": "५",
                "6": "६",
                "7": "७",
                "8": "८",
                "9": "९"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()
        case .thai:
            let map: [Character: String] = [
                "0": "๐",
                "1": "๑",
                "2": "๒",
                "3": "๓",
                "4": "๔",
                "5": "๕",
                "6": "๖",
                "7": "๗",
                "8": "๘",
                "9": "๙"
            ]

            return normalized
                .compactMap { map[$0] }
                .joined()
        }
    }

    private func romanNumeral(for value: Int) -> String {
        guard value > 0 else {
            return "0"
        }

        let values: [(value: Int, symbol: String)] = [
            (1000, "M"),
            (900, "CM"),
            (500, "D"),
            (400, "CD"),
            (100, "C"),
            (90, "XC"),
            (50, "L"),
            (40, "XL"),
            (10, "X"),
            (9, "IX"),
            (5, "V"),
            (4, "IV"),
            (1, "I")
        ]

        var remaining = value
        var result = ""

        for item in values {
            while remaining >= item.value {
                result += item.symbol
                remaining -= item.value
            }
        }

        return result
    }
}

