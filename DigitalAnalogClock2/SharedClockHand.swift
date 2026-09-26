//
//  SharedClockHand.swift
//  DigitalAnalogClock2
//
//  Created by Xcode2021 on 2026/09/23.
//

import SwiftUI

enum NumeralStyle: String, CaseIterable, Identifiable {
    case latin
    case kanji
    case hangul
    case roman
    case arabicIndic
    case persian
    case devanagari
    case thai

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .latin: return "25"
        case .kanji: return "二五"
        case .hangul: return "이오"
        case .roman: return "XXV"
        case .arabicIndic: return "٢٥"
        case .persian: return "۲۵"
        case .devanagari: return "२५"
        case .thai: return "๒๕"
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
                .frame(width: minWidth, height: length)
                .cornerRadius(minWidth / 2)
                .offset(y: -length / 2)
                .rotationEffect(angle)

            ZStack {
                Circle()
                    .fill(.white)
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
                    .unredacted()
                    .font(
                        .system(
                            size: maxWidth,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .allowsTightening(true)
                    .frame(
                        width: labelContentSize,
                        height: labelContentSize
                    )
                    .rotationEffect(
                        keepLabelsUpright ? -angle : .zero
                    )
            }
            .frame(
                width: labelCircleSize,
                height: labelCircleSize
            )
            .offset(y: -length + maxWidth * 0.2)
            .rotationEffect(angle)
        }
    }

    @ViewBuilder
    private func labelView() -> some View {
        if numeralStyle == .kanji && label.count == 2 {
            let characters = Array(label)

            VStack(
                spacing: -maxWidth * 0.12
            ) {
                ForEach(
                    characters.indices,
                    id: \.self
                ) { index in
                    Text(
                        verbatim: String(
                            characters[index]
                        )
                    )
                }
            }
        } else {
            Text(verbatim: label)
        }
    }
}
