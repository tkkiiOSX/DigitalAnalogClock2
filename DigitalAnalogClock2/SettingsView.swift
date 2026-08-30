import SwiftUI

struct SettingsView: View {
    @Binding var keepLabelsUpright: Bool
    @Binding var sweepSecondHand: Bool
    @Binding var tickVolume: Float
    @Binding var showOuterRing: Bool
    @Binding var timeZone: TimeZone
    var onOK: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("文字を常に上向きにする", isOn: $keepLabelsUpright)
                }
                Section(header: Text("秒針")) {
                    Toggle("スイープ秒針", isOn: $sweepSecondHand)
                }
                Section(header: Text("表示")) {
                    Toggle("文字盤の外側の丸枠を表示", isOn: $showOuterRing)
                }
                Section(header: Text("タイムゾーン")) {
                    Picker("タイムゾーン", selection: Binding(
                        get: { timeZone.identifier },
                        set: { id in if let tz = TimeZone(identifier: id) { timeZone = tz } }
                    )) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                }
                Section(header: Text("音量"), footer: Text("ステップ秒針のときに鳴る音の音量")) {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { Double(tickVolume) },
                            set: { tickVolume = Float($0) }
                        ), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                .disabled(sweepSecondHand)
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        onOK()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            keepLabelsUpright: .constant(true),
            sweepSecondHand: .constant(true),
            tickVolume: .constant(0.8),
            showOuterRing: .constant(true),
            timeZone: .constant(.current)
        ) {}
    }
}
