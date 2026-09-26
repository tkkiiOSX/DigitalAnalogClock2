//
//  DigitalAnalogClock2Widget.swift
//  DigitalAnalogClock2Widget
//
//  Created by Xcode2021 on 2026/09/23.
//

import WidgetKit
import SwiftUI
import UIKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            timeZoneIdentifier: "Asia/Tokyo"
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (SimpleEntry) -> Void
    ) {
        completion(
            SimpleEntry(
                date: Date(),
                timeZoneIdentifier: SharedWidgetSettings.timeZoneIdentifier()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<SimpleEntry>) -> Void
    ) {
        let currentDate = Date()
        var entries: [SimpleEntry] = []

        let calendar = Calendar.current
        let timeZoneIdentifier =
            SharedWidgetSettings.timeZoneIdentifier()

        for minuteOffset in 0..<60 {
            guard let entryDate = calendar.date(
                byAdding: .minute,
                value: minuteOffset,
                to: currentDate
            ) else {
                continue
            }

            entries.append(
                SimpleEntry(
                    date: entryDate,
                    timeZoneIdentifier: timeZoneIdentifier
                )
            )
        }

        let timeline = Timeline(
            entries: entries,
            policy: .atEnd
        )

        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let timeZoneIdentifier: String
}

private struct SharedWidgetSettings {
    private static let defaults =
        SharedClockStorage.defaults

    static func timeZoneIdentifier() -> String {
        guard let data = defaults.data(
            forKey: SharedClockStorage.savedClocksKey
        ),
        let clocks = try? JSONDecoder().decode(
            [WidgetClockInfo].self,
            from: data
        ),
        let firstClock = clocks.first else {
            return "Asia/Tokyo"
        }

        return firstClock.timeZoneIdentifier
    }

    static func firstClockInfo() -> WidgetClockInfo {
        guard let data = defaults.data(
            forKey: SharedClockStorage.savedClocksKey
        ),
        let clocks = try? JSONDecoder().decode(
            [WidgetClockInfo].self,
            from: data
        ),
        let firstClock = clocks.first else {
            return WidgetClockInfo(
                id: UUID(),
                timeZoneIdentifier: "Asia/Tokyo",
                showOuterRing: true
            )
        }

        return firstClock
    }

    static func designSettings(
        for clockID: UUID
    ) -> WidgetDesignSettings {
        let prefix =
            SharedClockStorage.clockDesignPrefix(for: clockID)

        let frameStyle = WidgetFrameStyle(
            rawValue: defaults.string(
                forKey: prefix + "frameStyle"
            ) ?? ""
        ) ?? .circle

        let frameColor = color(
            forKey: prefix + "frameColor",
            defaultColor: Color.cyan
        )

        let hourHandColor = color(
            forKey: prefix + "hourHandColor",
            defaultColor: Color.blue
        )

        let minuteHandColor = color(
            forKey: prefix + "minuteHandColor",
            defaultColor: Color.green
        )

        let secondHandColor = color(
            forKey: prefix + "secondHandColor",
            defaultColor: Color.red
        )

        let backgroundColor = color(
            forKey: prefix + "backgroundColor",
            defaultColor: Color(
                .sRGB,
                red: 0.7,
                green: 0.85,
                blue: 0.98
            )
        )

        let backgroundImageData =
            SharedClockStorage.loadBackgroundImage(
                forKey: prefix + "backgroundImage"
            )
        //let backgroundImageData: Data? = nil

        let numeralStyle = NumeralStyle(
            rawValue: defaults.string(
                forKey: prefix + "numeralStyle"
            ) ?? ""
        ) ?? .latin

        return WidgetDesignSettings(
            frameStyle: frameStyle,
            frameColor: frameColor,
            hourHandColor: hourHandColor,
            minuteHandColor: minuteHandColor,
            secondHandColor: secondHandColor,
            backgroundColor: backgroundColor,
            backgroundImageData: backgroundImageData,
            numeralStyle: numeralStyle
        )
    }

    private static func color(
        forKey key: String,
        defaultColor: Color
    ) -> Color {
        guard let values = defaults.array(
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
}

private struct WidgetClockInfo: Codable {
    let id: UUID
    let timeZoneIdentifier: String
    let showOuterRing: Bool
}

private enum WidgetFrameStyle: String {
    case circle
    case rectangle
    case roundedRectangle
}

private struct WidgetDesignSettings {
    let frameStyle: WidgetFrameStyle
    let frameColor: Color
    let hourHandColor: Color
    let minuteHandColor: Color
    let secondHandColor: Color
    let backgroundColor: Color
    let backgroundImageData: Data?
    let numeralStyle: NumeralStyle

    var backgroundImage: UIImage? {
        guard let backgroundImageData else {
            return nil
        }

        return UIImage(data: backgroundImageData)
    }
}

struct DigitalAnalogClock2WidgetEntryView: View {
    let entry: Provider.Entry

    private var clockInfo: WidgetClockInfo {
        SharedWidgetSettings.firstClockInfo()
    }

    private var designSettings: WidgetDesignSettings {
        SharedWidgetSettings.designSettings(
            for: clockInfo.id
        )
    }

    private var timeZone: TimeZone {
        TimeZone(
            identifier: entry.timeZoneIdentifier
        ) ?? .current
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(
                geometry.size.width,
                geometry.size.height
            )

            clockFace(size: size)
                .overlay(alignment: .bottomTrailing) {
                    timeZoneLabel(size: size)
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .unredacted()
    }

    private func clockFace(size: CGFloat) -> some View {
        let clockRadius = size * 0.45
        let handWidth = size * 0.04
        let labelSize = size * 0.09

        let calendar = calendar(for: timeZone)

        let hour = calendar.component(
            .hour,
            from: entry.date
        )

        let minute = calendar.component(
            .minute,
            from: entry.date
        )

        let second = calendar.component(
            .second,
            from: entry.date
        )

        let nanosecond = calendar.component(
            .nanosecond,
            from: entry.date
        )

        let hourValue =
            Double(hour % 12) + Double(minute) / 60.0

        let minuteValue =
            Double(minute) + Double(second) / 60.0

        let secondValue =
            Double(second)
            + Double(nanosecond) / 1_000_000_000.0

        let hourAngle = Angle.degrees(
            hourValue / 12.0 * 360.0
        )

        let minuteAngle = Angle.degrees(
            minuteValue / 60.0 * 360.0
        )

        let secondAngle = Angle.degrees(
            secondValue / 60.0 * 360.0
        )

        return ZStack {
            background(size: size)

            if clockInfo.showOuterRing {
                outerRing(size: size)
            }

            ClockHand(
                angle: hourAngle,
                length: clockRadius * 0.55,
                color: designSettings.hourHandColor,
                minWidth: handWidth,
                maxWidth: labelSize,
                label: hourLabel(hour),
                labelColor: designSettings.hourHandColor,
                keepLabelsUpright: true,
                numeralStyle: designSettings.numeralStyle
            )

            ClockHand(
                angle: minuteAngle,
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: handWidth,
                maxWidth: labelSize,
                label: numberLabel(minute),
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: true,
                numeralStyle: designSettings.numeralStyle
            )

            ClockHand(
                angle: secondAngle,
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: handWidth,
                maxWidth: labelSize,
                label: numberLabel(second),
                labelColor: designSettings.secondHandColor,
                keepLabelsUpright: true,
                numeralStyle: designSettings.numeralStyle
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
            width: size,
            height: size
        )
        .clipShape(
            frameShape(size: size)
        )
    }

    @ViewBuilder
    private func background(size: CGFloat) -> some View {
        if let image = designSettings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: size,
                    height: size
                )
        } else {
            designSettings.backgroundColor
        }
    }

    @ViewBuilder
    private func outerRing(size: CGFloat) -> some View {
        switch designSettings.frameStyle {
        case .circle:
            Circle()
                .stroke(
                    designSettings.frameColor,
                    lineWidth: size * 0.06
                )
                .shadow(radius: 8)

        case .rectangle:
            Rectangle()
                .stroke(
                    designSettings.frameColor,
                    lineWidth: size * 0.06
                )
                .shadow(radius: 8)

        case .roundedRectangle:
            RoundedRectangle(
                cornerRadius: size * 0.12
            )
            .stroke(
                designSettings.frameColor,
                lineWidth: size * 0.06
            )
            .shadow(radius: 8)
        }
    }

    private func frameShape(
        size: CGFloat
    ) -> some Shape {
        switch designSettings.frameStyle {
        case .circle:
            return AnyShape(Circle())

        case .rectangle:
            return AnyShape(Rectangle())

        case .roundedRectangle:
            return AnyShape(
                RoundedRectangle(
                    cornerRadius: size * 0.12
                )
            )
        }
    }

    private func timeZoneLabel(size: CGFloat) -> some View {
        Text(verbatim: timeZoneDisplayName)
            .unredacted()
            .font(
                .system(
                    size: max(10, size * 0.035),
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

    private var timeZoneDisplayName: String {
        switch timeZone.identifier {
        case "Asia/Tokyo", "Japan":
            return "日本／東京"

        case "Asia/Seoul":
            return "韓国／ソウル"

        case "Europe/London":
            return "イギリス／ロンドン"

        case "America/New_York":
            return "アメリカ／ニューヨーク"

        case "America/Los_Angeles":
            return "アメリカ／ロサンゼルス"

        case "Asia/Shanghai":
            return "中国／上海"

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

    private func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private func hourLabel(_ hour: Int) -> String {
        let value = hour % 12

        return numberLabel(
            value == 0 ? 12 : value
        )
    }

    private func numberLabel(_ value: Int) -> String {
        let normalized = String(value)

        switch designSettings.numeralStyle {
        case .latin:
            return normalized

        case .kanji:
            return convertDigits(
                normalized,
                using: [
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
            )

        case .hangul:
            return convertDigits(
                normalized,
                using: [
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
            )

        case .roman:
            return romanNumeral(for: value)

        case .arabicIndic:
            return convertDigits(
                normalized,
                using: [
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
            )

        case .persian:
            return convertDigits(
                normalized,
                using: [
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
            )

        case .devanagari:
            return convertDigits(
                normalized,
                using: [
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
            )

        case .thai:
            return convertDigits(
                normalized,
                using: [
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
            )
        }
    }

    private func convertDigits(
        _ value: String,
        using map: [Character: String]
    ) -> String {
        let converted = value.map { character in
            map[character] ?? String(character)
        }

        let result = converted.joined()

        return result.isEmpty ? value : result
    }

    private func romanNumeral(for value: Int) -> String {
        guard value > 0 else {
            return "0"
        }

        let symbols: [(Int, String)] = [
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

        for symbol in symbols {
            while remaining >= symbol.0 {
                result += symbol.1
                remaining -= symbol.0
            }
        }

        return result
    }
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

struct DigitalAnalogClock2Widget: Widget {
    let kind: String = "DigitalAnalogClock2Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            if #available(iOS 17.0, *) {
                DigitalAnalogClock2WidgetEntryView(entry: entry)
                    .containerBackground(
                        .fill.tertiary,
                        for: .widget
                    )
            } else {
                DigitalAnalogClock2WidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("アナログ時計")
        .description(
            "アプリの一つ目の時計のデザインを表示します。"
        )
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

#Preview(as: .systemSmall) {
    DigitalAnalogClock2Widget()
} timeline: {
    SimpleEntry(
        date: Date(),
        timeZoneIdentifier: "Asia/Tokyo"
    )

    SimpleEntry(
        date: Date().addingTimeInterval(60),
        timeZoneIdentifier: "Asia/Tokyo"
    )
}
