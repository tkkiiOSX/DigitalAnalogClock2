import SwiftUI

struct ClockView: View {
    let date: Date
    let timeZone: TimeZone
    let designSettings: ClockDesignSettings

    @Binding var showSettings: Bool
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Double
    @Binding var showOuterRing: Bool

    let onSettings: () -> Void
    let onUpdateTimeZone: (TimeZone) -> Void
    let onTickVolumeChanged: (Float) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = min(
                geometry.size.width,
                geometry.size.height
            )

            clockFace(
                size: size,
                timeZone: timeZone
            )
            .overlay(alignment: .bottomTrailing) {
                timeZoneLabel(
                    size: size,
                    timeZone: timeZone
                )
            }
            .overlay(alignment: .topTrailing) {
                settingsButton(
                    size: size
                )
            }
            .background {
                ZStack {
                    designSettings.backgroundColor

                    clockFaceBackgroundMasked(
                        size: size
                    )
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * 0.02
                )
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                keepLabelsUpright: $keepLabelsUpright,
                sweepSecondHand: $sweepSecondHand,
                tickVolume: Binding(
                    get: {
                        Float(tickVolume)
                    },
                    set: { value in
                        tickVolume = Double(value)
                        onTickVolumeChanged(value)
                    }
                ),
                showOuterRing: $showOuterRing,
                timeZone: Binding(
                    get: {
                        timeZone
                    },
                    set: { newTimeZone in
                        onUpdateTimeZone(newTimeZone)
                    }
                ),
                designSettings: designSettings
            ) {
                showSettings = false
            }
        }
    }

    private func clockFace(
        size: CGFloat,
        timeZone: TimeZone
    ) -> some View {
        let clockRadius = size * 0.45
        let secondHandWidth = size * 0.04
        let hourHandWidth = size * 0.09

        return ZStack {
            outerRing(size: size)

            ClockHand(
                angle: hourAngle(timeZone: timeZone),
                length: clockRadius * 0.55,
                color: designSettings.hourHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: hourString(timeZone: timeZone),
                labelColor: designSettings.hourHandColor,
                keepLabelsUpright: keepLabelsUpright,
                numeralStyle: designSettings.numeralStyle
            )

            ClockHand(
                angle: minuteAngle(timeZone: timeZone),
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString(timeZone: timeZone),
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: keepLabelsUpright,
                numeralStyle: designSettings.numeralStyle
            )

            ClockHand(
                angle: secondAngle(timeZone: timeZone),
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString(timeZone: timeZone),
                labelColor: designSettings.secondHandColor,
                keepLabelsUpright: keepLabelsUpright,
                numeralStyle: designSettings.numeralStyle
            )
            .animation(
                sweepSecondHand
                    ? .linear(duration: 1.0 / 30.0)
                    : nil,
                value: secondAngle(timeZone: timeZone)
            )

            Circle()
                .fill(.yellow)
                .frame(
                    width: size * 0.1,
                    height: size * 0.1
                )
                .shadow(radius: 2)
        }
        .frame(
            width: size,
            height: size
        )
    }

    @ViewBuilder
    private func clockFaceBackgroundMasked(
        size: CGFloat
    ) -> some View {
        if let image = designSettings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: size,
                    height: size
                )
                .clipped()
                .mask {
                    innerMask(size: size)
                }
        }
    }

    @ViewBuilder
    private func innerMask(size: CGFloat) -> some View {
        let lineWidth = size * 0.03
        let inset = lineWidth / 2

        switch designSettings.frameStyle {
        case .circle:
            Circle()
                .inset(by: inset)

        case .rectangle:
            Rectangle()
                .inset(by: inset)

        case .roundedRectangle:
            RoundedRectangle(
                cornerRadius: size * 0.12
            )
            .inset(by: inset)
        }
    }

    @ViewBuilder
    private func outerRing(size: CGFloat) -> some View {
        if showOuterRing {
            let lineWidth = size * 0.03
            let insetAmount = lineWidth / 2

            switch designSettings.frameStyle {
            case .circle:
                Circle()
                    .inset(by: insetAmount)
                    .stroke(
                        designSettings.frameColor,
                        lineWidth: lineWidth
                    )
                    .frame(
                        width: size,
                        height: size
                    )
                    .shadow(radius: 8)

            case .rectangle:
                Rectangle()
                    .inset(by: insetAmount)
                    .stroke(
                        designSettings.frameColor,
                        lineWidth: lineWidth
                    )
                    .frame(
                        width: size,
                        height: size
                    )
                    .shadow(radius: 8)

            case .roundedRectangle:
                RoundedRectangle(
                    cornerRadius: size * 0.12
                )
                .inset(by: insetAmount)
                .stroke(
                    designSettings.frameColor,
                    lineWidth: lineWidth
                )
                .frame(
                    width: size,
                    height: size
                )
                .shadow(radius: 8)
            }
        }
    }

    private func timeZoneLabel(
        size: CGFloat,
        timeZone: TimeZone
    ) -> some View {
        Text(timeZoneDisplayName(timeZone))
            .font(
                .system(
                    size: max(11, size * 0.035),
                    weight: .medium
                )
            )
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .padding(8)
    }

    private func settingsButton(size: CGFloat) -> some View {
        Button {
            onSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(
                    .system(
                        size: max(18, size * 0.05)
                    )
                )
                .foregroundStyle(.primary)
                .padding(12)
                .background(
                    .ultraThinMaterial,
                    in: Circle()
                )
                .shadow(radius: 2)
        }
        .padding(8)
    }

    private func calendar(
        timeZone: TimeZone
    ) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private func hour(
        timeZone: TimeZone
    ) -> Int {
        calendar(timeZone: timeZone)
            .component(.hour, from: date)
    }

    private func minute(
        timeZone: TimeZone
    ) -> Int {
        calendar(timeZone: timeZone)
            .component(.minute, from: date)
    }

    private func second(
        timeZone: TimeZone
    ) -> Int {
        calendar(timeZone: timeZone)
            .component(.second, from: date)
    }

    private func nanosecond(
        timeZone: TimeZone
    ) -> Int {
        calendar(timeZone: timeZone)
            .component(.nanosecond, from: date)
    }

    private func hourAngle(
        timeZone: TimeZone
    ) -> Angle {
        let hourValue = Double(
            hour(timeZone: timeZone) % 12
        ) + Double(
            minute(timeZone: timeZone)
        ) / 60

        return .degrees(
            hourValue / 12 * 360
        )
    }

    private func minuteAngle(
        timeZone: TimeZone
    ) -> Angle {
        let minuteValue = Double(
            minute(timeZone: timeZone)
        ) + Double(
            second(timeZone: timeZone)
        ) / 60

        return .degrees(
            minuteValue / 60 * 360
        )
    }

    private func secondAngle(
        timeZone: TimeZone
    ) -> Angle {
        let secondValue: Double

        if sweepSecondHand {
            secondValue = Double(
                second(timeZone: timeZone)
            ) + Double(
                nanosecond(timeZone: timeZone)
            ) / 1_000_000_000
        } else {
            secondValue = Double(
                second(timeZone: timeZone)
            )
        }

        return .degrees(
            secondValue / 60 * 360
        )
    }

    private func hourString(
        timeZone: TimeZone
    ) -> String {
        formatDigits(
            String(
                format: "%02d",
                hour(timeZone: timeZone)
            )
        )
    }

    private func minuteString(
        timeZone: TimeZone
    ) -> String {
        formatDigits(
            String(
                format: "%02d",
                minute(timeZone: timeZone)
            )
        )
    }

    private func secondString(
        timeZone: TimeZone
    ) -> String {
        formatDigits(
            String(
                format: "%02d",
                second(timeZone: timeZone)
            )
        )
    }

    private func formatDigits(_ input: String) -> String {
        let digitsOnly = input
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard let value = Int(digitsOnly),
              value >= 0,
              value <= 99 else {
            return input
        }

        let normalized = value < 10
            ? String(value)
            : String(format: "%02d", value)

        switch designSettings.numeralStyle {
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

        let symbols: [(value: Int, symbol: String)] = [
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

        for item in symbols {
            while remaining >= item.value {
                result += item.symbol
                remaining -= item.value
            }
        }

        return result
    }

    private func timeZoneDisplayName(
        _ timeZone: TimeZone
    ) -> String {
        switch timeZone.identifier {
        case "Asia/Tokyo", "Japan":
            return "日本／東京"

        case "Europe/London":
            return "イギリス／ロンドン"

        case "America/New_York":
            return "アメリカ／ロンドン"

        case "America/Los_Angeles":
            return "アメリカ／ロサンゼルス"

        case "Asia/Seoul":
            return "韓国／ソウル"

        case "Asia/Shanghai":
            return "中国／上海"

        case "Europe/Paris":
            return "フランス／パリ"

        case "Europe/Berlin":
            return "ドイツ／ベルリン"

        case "Australia/Sydney":
            return "オーストラリア／シドニー"

        case "Asia/Amman":
            return "ヨルダン／アンマン"

        default:
            return timeZone.identifier
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
                .replacingOccurrences(
                    of: "/",
                    with: "／"
                )
        }
    }
}

struct ClockHand: View {
    let angle: Angle
    let length: CGFloat
    let color: Color
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let label: String
    let labelColor: Color
    let keepLabelsUpright: Bool
    let numeralStyle: NumeralStyle

    private var labelCircleSize: CGFloat {
        maxWidth * 1.4
    }

    private var labelContentSize: CGFloat {
        maxWidth * 1.14
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(
                    width: minWidth,
                    height: length
                )
                .cornerRadius(minWidth / 2)
                .offset(y: -length / 2)
                .rotationEffect(angle)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: labelCircleSize,
                        height: labelCircleSize
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                labelColor,
                                lineWidth: maxWidth * 0.1
                            )
                    }
                    .shadow(radius: 1)

                labelView()
                    .font(
                        .system(
                            size: maxWidth,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(labelColor)
                    .shadow(radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .allowsTightening(true)
                    .frame(
                        width: labelContentSize,
                        height: labelContentSize
                    )
                    .clipped()
                    .rotationEffect(
                        keepLabelsUpright
                            ? -angle
                            : .zero
                    )
            }
            .frame(
                width: labelCircleSize,
                height: labelCircleSize
            )
            .offset(
                y: -length + maxWidth * 0.2
            )
            .rotationEffect(angle)
        }
    }

    @ViewBuilder
    private func labelView() -> some View {
        if numeralStyle == .kanji && label.count == 2 {
            let characters = Array(label)

            VStack(spacing: -maxWidth * 0.12) {
                ForEach(
                    characters.indices,
                    id: \.self
                ) { index in
                    Text(String(characters[index]))
                }
            }
        } else {
            Text(label)
        }
    }
}

