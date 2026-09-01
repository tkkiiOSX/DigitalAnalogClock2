//
//  ContentView.swift
//  DigitalAnalogClock2
//
//  Created by Xcode2021 on 2026/08/28.
//

import SwiftUI
import Combine
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentDate = Date()
    @State private var showSettings = false
    @State private var keepLabelsUpright = false
    @State private var sweepSecondHand = true
    @State private var tickVolume: Float = 0.8
    @State private var showOuterRing = true
    @State private var timeZone: TimeZone = .current

    @AppStorage("gpsSyncEnabled")
    private var gpsSyncEnabled = true

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

            timeZone = newTimeZone
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

            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = tickVolume
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
        tickPlayer.volume = tickVolume

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
        .background(clockBackground)
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
                color: .blue,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: hourString,
                labelColor: .blue,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: minuteAngle,
                length: clockRadius * 0.80,
                color: .green,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: minuteString,
                labelColor: .green,
                keepLabelsUpright: keepLabelsUpright
            )

            ClockHand(
                angle: secondAngle,
                length: clockRadius * 0.92,
                color: .red,
                minWidth: secondHandWidth,
                maxWidth: hourHandWidth,
                label: secondString,
                labelColor: .red,
                keepLabelsUpright: keepLabelsUpright
            )

            centerCircle(size: size)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func outerRing(size: CGFloat) -> some View {
        if showOuterRing {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.8),
                            .white
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.07
                )
                .frame(width: size, height: size)
                .shadow(radius: 8)
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

    private var clockBackground: some View {
        LinearGradient(
            colors: [
                Color(
                    .sRGB,
                    red: 0.7,
                    green: 0.85,
                    blue: 0.98,
                    opacity: 1
                ),
                .green.opacity(0.14)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var settingsView: some View {
        SettingsView(
            keepLabelsUpright: $keepLabelsUpright,
            sweepSecondHand: $sweepSecondHand,
            tickVolume: $tickVolume,
            showOuterRing: $showOuterRing,
            timeZone: $timeZone,
            gpsSyncEnabled: $gpsSyncEnabled
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
        calendar.component(.hour, from: currentDate)
    }

    private var minute: Int {
        calendar.component(.minute, from: currentDate)
    }

    private var second: Int {
        calendar.component(.second, from: currentDate)
    }

    private var nanosecond: Int {
        calendar.component(.nanosecond, from: currentDate)
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
            .offset(y: -length + maxWidth * 0.2)
            .rotationEffect(angle)
        }
    }
}

#Preview {
    ContentView()
}
