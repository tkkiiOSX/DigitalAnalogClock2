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
    @State private var currentDate = Date()
    @State private var showSettings = false
    @State private var keepLabelsUpright = false
    @State private var sweepSecondHand = true
    @State private var tickVolume: Float = 0.8
    @State private var showOuterRing: Bool = true
    @State private var timeZone: TimeZone = .current
    private var tickPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "CLOCK01", withExtension: "mp3") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }()
    @State private var lastSecondPlayed: Int = -1
    
    private let timer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width/2, y: geometry.size.height/2)
            let clockRadius = size * 0.45
            
            // 秒針幅と時針幅を定義
            let secWidth = size * 0.04
            let hourWidth = size * 0.09
            
            ZStack {
                // Clock face (circle)
                if showOuterRing {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), .white],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: size * 0.07
                        )
                        .frame(width: size, height: size)
                        .shadow(radius: 8)
                }

                // Hands
                ClockHand(
                    angle: hourAngle,
                    length: clockRadius * 0.55,
                    color: .blue,
                    minWidth: secWidth,
                    maxWidth: hourWidth,
                    label: hourString,
                    labelColor: .blue,
                    keepLabelsUpright: keepLabelsUpright
                )
                ClockHand(
                    angle: minuteAngle,
                    length: clockRadius * 0.80,
                    color: .green,
                    minWidth: secWidth,
                    maxWidth: hourWidth,
                    label: minuteString,
                    labelColor: .green,
                    keepLabelsUpright: keepLabelsUpright
                )
                ClockHand(
                    angle: secondAngle,
                    length: clockRadius * 0.92,
                    color: .red,
                    minWidth: secWidth,
                    maxWidth: hourWidth,
                    label: secondString,
                    labelColor: .red,
                    keepLabelsUpright: keepLabelsUpright
                )

                // Center circle (pivot)
                Circle()
                    .fill(.yellow)
                    .frame(width: size * 0.1, height: size * 0.1)
                    .shadow(radius: 2)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: max(18, size * 0.05)))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(radius: 2)
                }
                .padding(8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(
                LinearGradient(
                    colors: [Color(.sRGB, red: 0.7, green: 0.85, blue: 0.98, opacity: 1), .green.opacity(0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .sheet(isPresented: $showSettings) {
                SettingsView(keepLabelsUpright: $keepLabelsUpright, sweepSecondHand: $sweepSecondHand, tickVolume: $tickVolume, showOuterRing: $showOuterRing, timeZone: $timeZone) {
                    showSettings = false
                }
            }
            .onReceive(timer) { newDate in
                currentDate = newDate
                if !sweepSecondHand {
                    let currentSec = Calendar.current.component(.second, from: newDate)
                    if currentSec != lastSecondPlayed {
                        if let player = tickPlayer {
                            player.currentTime = 0
                            player.volume = tickVolume
                            player.play()
                        }
                        lastSecondPlayed = currentSec
                    }
                } else {
                    // reset so次のステップ時に確実に鳴る
                    lastSecondPlayed = -1
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
    
    // MARK: - Computed properties for angles and text
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }
    private var hour: Int { calendar.component(.hour, from: currentDate) }
    private var minute: Int { calendar.component(.minute, from: currentDate) }
    private var second: Int { calendar.component(.second, from: currentDate) }
    private var nanosecond: Int { calendar.component(.nanosecond, from: currentDate) }
    
    private var hourAngle: Angle {
        let hourIn12 = Double(hour % 12) + Double(minute)/60
        return Angle.degrees((hourIn12 / 12) * 360)
    }
    private var minuteAngle: Angle {
        let min = Double(minute) + Double(second)/60
        return Angle.degrees((min / 60) * 360)
    }
    private var secondAngle: Angle {
        let secValue: Double
        if sweepSecondHand {
            secValue = Double(second) + Double(nanosecond)/1_000_000_000
        } else {
            secValue = Double(second)
        }
        return Angle.degrees((secValue / 60) * 360)
    }
    private var hourString: String { String(format: "%d", hour) }
    private var minuteString: String { String(format: "%02d", minute) }
    private var secondString: String { String(format: "%02d", second) }
}

struct ClockHand: View {
    let angle: Angle
    let length: CGFloat
    let color: Color
    let minWidth: CGFloat  // 針の幅
    let maxWidth: CGFloat  // 円と文字サイズ調整用
    let label: String
    let labelColor: Color
    let keepLabelsUpright: Bool
    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: minWidth, height: length)
                .cornerRadius(minWidth/2)
                .offset(y: -length/2)
                .rotationEffect(angle)
            // --- 針先端に白い円と数字 ---
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: maxWidth * 1.4, height: maxWidth * 1.4)
                    .overlay(
                        Circle()
                            .stroke(labelColor, lineWidth: maxWidth * 1.0 * 0.1)
                    )
                    .shadow(radius: 1)
                Text(label)
                    .font(.system(size: maxWidth * 1.0, weight: .bold, design: .rounded))
                    .foregroundColor(labelColor)
                    .shadow(radius: 1)
                    .rotationEffect(keepLabelsUpright ? -angle : .degrees(0))
            }
            .offset(y: -length - maxWidth * -0.2)
            .rotationEffect(angle)
        }
    }
}

#Preview {
    ContentView()
}

