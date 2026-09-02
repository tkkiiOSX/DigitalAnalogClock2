//
//  ContentView.swift
//  DigitalAnalogClock2
//
//  Created by Xcode2021 on 2026/08/28.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentDate = Date()
    @State private var showSettings = false

    @AppStorage("keepLabelsUpright")
    private var keepLabelsUpright = false

    @AppStorage("sweepSecondHand")
    private var sweepSecondHand = true

    // AppStorageはFloatに対応していないためDoubleを使用する
    @AppStorage("tickVolume")
    private var tickVolume: Double = 0.8

    @AppStorage("showOuterRing")
    private var showOuterRing = true

    @AppStorage("timeZoneIdentifier")
    private var timeZoneIdentifier = TimeZone.current.identifier

    @AppStorage("gpsSyncEnabled")
    private var gpsSyncEnabled = true

    @StateObject private var designSettings =
        ClockDesignSettings()

    @StateObject private var locationTimeZoneManager =
        LocationTimeZoneManager()

    @State private var tickPlayer: AVAudioPlayer?
    @State private var lastSecondPlayed = -1
    @State private var audioIsPrepared = false

    private let timer = Timer.publish(
        every: 1 / 30,
        on: .main,
        in: .common
    ).autoconnect()

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier)
            ?? .current
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(
                geometry.size.width,
                geometry.size.height
            )

            clockContainer(size: size)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .onAppear {
            prepareAudioPlayer()
            locationTimeZoneManager.setEnabled(gpsSyncEnabled)
        }
        .onChange(of: gpsSyncEnabled) { _, enabled in
            locationTimeZoneManager.setEnabled(enabled)

            if enabled {
                locationTimeZoneManager.refresh()
            }
        }
        .onChange(of: locationTimeZoneManager.timeZone) { _, newTimeZone in
            guard gpsSyncEnabled,
                  let newTimeZone else {
                return
            }

            timeZoneIdentifier = newTimeZone.identifier
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            prepareAudioPlayer()

            if gpsSyncEnabled {
                locationTimeZoneManager.refresh()
            }
        }
    }

    private func prepareAudioPlayer() {
        guard !audioIsPrepared else {
            return
        }

        guard let soundURL = Bundle.main.url(
            forResource: "CLOCK01",
            withExtension: "mp3"
        ) else {
            print("CLOCK01.mp3がアプリのBundleに見つかりません")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()

            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )

            try audioSession.setActive(true)

            let player = try AVAudioPlayer(
                contentsOf: soundURL
            )

            player.volume = Float(tickVolume)
            player.numberOfLoops = 0
            player.prepareToPlay()

            tickPlayer = player
            audioIsPrepared = true

            print("CLOCK01.mp3の準備が完了しました")
        } catch {
            tickPlayer = nil
            audioIsPrepared = false

            print("CLOCK01.mp3の準備に失敗しました: \(error)")
        }
    }

    private func playTickSound() {
        if !audioIsPrepared || tickPlayer == nil {
            prepareAudioPlayer()
        }

        guard let tickPlayer else {
            print("再生できる音声プレイヤーがありません")
            return
        }

        tickPlayer.stop()
        tickPlayer.currentTime = 0
        tickPlayer.volume = Float(tickVolume)

        let didPlay = tickPlayer.play()

        if !didPlay {
            print("CLOCK01.mp3の再生に失敗しました")
        }
    }

    private func clockContainer(size: CGFloat) -> some View {
        let clockRadius = size * 0.45
        let secondHandWidth = size * 0.04
        let hourHandWidth = size * 0.09

        return clockFace(
            size: size,
            clockRadius: clockRadius,
            secondHandWidth: secondHandWidth,
            hourHandWidth: hourHandWidth
        )
        .overlay(alignment: .bottomTrailing) {
            timeZoneLabel(size: size)
        }
        .overlay(alignment: .topTrailing) {
            settingsButton(size: size)
        }
        .background {
            ZStack {
                // Base background behind the clock (outside the frame remains visible)
                designSettings.backgroundColor
                // Photo only fills the inner face of the frame (outside stays transparent to base)
                clockFaceBackgroundMasked(size: size)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: size * 0.02)
        )
        .sheet(isPresented: $showSettings) {
            settingsView
        }
        .onReceive(timer) { newDate in
            handleTimer(newDate)
        }
    }

    private func clockFace(
        size: CGFloat,
        clockRadius: CGFloat,
        secondHandWidth: CGFloat,
        hourHandWidth: CGFloat
    ) -> some View {
        ZStack {
            outerRing(size: size)

            ClockHand(
                angle: hourAngle,
                length: clockRadius * 0.55,
                color: designSettings.hourHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: hourString,
                labelColor: designSettings.hourHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: minuteAngle,
                length: clockRadius * 0.80,
                color: designSettings.minuteHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString,
                labelColor: designSettings.minuteHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: secondAngle,
                length: clockRadius * 0.92,
                color: designSettings.secondHandColor,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString,
                labelColor: designSettings.secondHandColor,
                keepLabelsUpright: keepLabelsUpright
            )

            centerCircle(size: size)
        }
        .frame(
            width: size,
            height: size
        )
    }

    @ViewBuilder
    private func clockFaceBackgroundMasked(size: CGFloat) -> some View {
        if let image = designSettings.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .mask(innerMask(size: size))
        }
    }

    @ViewBuilder
    private func innerMask(size: CGFloat) -> some View {
        // Match the visible inner edge of the stroked frame in outerRing():
        let lineWidth = size * 0.03
        let inset = lineWidth / 2
        switch designSettings.frameStyle {
        case .circle:
            Circle().inset(by: inset)
        case .rectangle:
            Rectangle().inset(by: inset)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: size * 0.12).inset(by: inset)
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

    private func centerCircle(size: CGFloat) -> some View {
        Circle()
            .fill(.yellow)
            .frame(
                width: size * 0.1,
                height: size * 0.1
            )
            .shadow(radius: 2)
    }

    private func timeZoneLabel(size: CGFloat) -> some View {
        Text(timeZoneDisplayName)
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
            showSettings = true
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

    private var settingsView: some View {
        SettingsView(
            keepLabelsUpright: Binding(
                get: {
                    keepLabelsUpright
                },
                set: { value in
                    keepLabelsUpright = value
                }
            ),
            sweepSecondHand: Binding(
                get: {
                    sweepSecondHand
                },
                set: { value in
                    sweepSecondHand = value
                }
            ),
            tickVolume: Binding(
                get: {
                    Float(tickVolume)
                },
                set: { value in
                    tickVolume = Double(value)

                    if let tickPlayer {
                        tickPlayer.volume = value
                    }
                }
            ),
            showOuterRing: Binding(
                get: {
                    showOuterRing
                },
                set: { value in
                    showOuterRing = value
                }
            ),
            timeZone: Binding(
                get: {
                    timeZone
                },
                set: { newTimeZone in
                    timeZoneIdentifier = newTimeZone.identifier
                }
            ),
            gpsSyncEnabled: $gpsSyncEnabled,
            designSettings: designSettings
        ) {
            showSettings = false
        }
    }

    private func handleTimer(_ newDate: Date) {
        currentDate = newDate

        guard !sweepSecondHand else {
            lastSecondPlayed = -1
            return
        }

        let currentSecond = calendar.component(
            .second,
            from: newDate
        )

        guard currentSecond != lastSecondPlayed else {
            return
        }

        playTickSound()
        lastSecondPlayed = currentSecond
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private var hour: Int {
        calendar.component(
            .hour,
            from: currentDate
        )
    }

    private var minute: Int {
        calendar.component(
            .minute,
            from: currentDate
        )
    }

    private var second: Int {
        calendar.component(
            .second,
            from: currentDate
        )
    }

    private var nanosecond: Int {
        calendar.component(
            .nanosecond,
            from: currentDate
        )
    }

    private var hourAngle: Angle {
        let hourValue = Double(hour % 12)
            + Double(minute) / 60

        return Angle.degrees(
            (hourValue / 12) * 360
        )
    }

    private var minuteAngle: Angle {
        let minuteValue = Double(minute)
            + Double(second) / 60

        return Angle.degrees(
            (minuteValue / 60) * 360
        )
    }

    private var secondAngle: Angle {
        let secondValue: Double

        if sweepSecondHand {
            secondValue = Double(second)
                + Double(nanosecond) / 1_000_000_000
        } else {
            secondValue = Double(second)
        }

        return Angle.degrees(
            (secondValue / 60) * 360
        )
    }

    private var hourString: String {
        String(format: "%d", hour)
    }

    private var minuteString: String {
        String(format: "%02d", minute)
    }

    private var secondString: String {
        String(format: "%02d", second)
    }

    private var timeZoneDisplayName: String {
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

#Preview {
    ContentView()
}
