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
    @Binding var followSystemTimeZone: Bool
    @Binding var gpsSyncEnabled: Bool

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
                followSystemTimeZone: $followSystemTimeZone,
                gpsSyncEnabled: $gpsSyncEnabled,
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
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: minuteAngle(timeZone: timeZone),
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString(timeZone: timeZone),
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: secondAngle(timeZone: timeZone),
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString(timeZone: timeZone),
                labelColor: designSettings.secondHandColor,
                keepLabelsUpright: keepLabelsUpright
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
        String(
            format: "%d",
            hour(timeZone: timeZone)
        )
    }

    private func minuteString(
        timeZone: TimeZone
    ) -> String {
        String(
            format: "%02d",
            minute(timeZone: timeZone)
        )
    }

    private func secondString(
        timeZone: TimeZone
    ) -> String {
        String(
            format: "%02d",
            second(timeZone: timeZone)
        )
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
            return "アメリカ／ニューヨーク"

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
                        width: maxWidth * 1.4,
                        height: maxWidth * 1.4
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                labelColor,
                                lineWidth: maxWidth * 0.1
                            )
                    }
                    .shadow(radius: 1)

                Text(label)
                    .font(
                        .system(
                            size: maxWidth,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(labelColor)
                    .shadow(radius: 1)
                    .rotationEffect(
                        keepLabelsUpright
                            ? -angle
                            : .zero
                    )
            }
            .offset(
                y: -length + maxWidth * 0.2
            )
            .rotationEffect(angle)
        }
    }
}
