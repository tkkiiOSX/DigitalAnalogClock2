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
                    label: "10",
                    labelColor: settings.hourHandColor,
                    keepLabelsUpright: keepLabelsUpright
                )

                ClockHand(
                    angle: .degrees(145),
                    length: radius * 0.78,
                    color: settings.minuteHandColor,
                    minWidth: handWidth,
                    maxWidth: labelSize,
                    label: "25",
                    labelColor: settings.minuteHandColor,
                    keepLabelsUpright: keepLabelsUpright
                )

                ClockHand(
                    angle: .degrees(270),
                    length: radius * 0.90,
                    color: settings.secondHandColor,
                    minWidth: handWidth,
                    maxWidth: labelSize,
                    label: "45",
                    labelColor: settings.secondHandColor,
                    keepLabelsUpright: keepLabelsUpright
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
        // Match the visible inner edge of the stroked frame:
        // frame uses: lineWidth = size*0.07, padding = size*0.035
        let lineWidth = size * 0.07
        let padding = size * 0.035
        let inset = padding + lineWidth / 2
        switch settings.frameStyle {
        case .circle:
            Circle().padding(inset)
        case .rectangle:
            Rectangle().padding(inset)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: max(0, size * 0.12 - inset)).padding(inset)
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
                lineWidth: size * 0.07
            )
            .padding(size * 0.035)
        }
    }
}

