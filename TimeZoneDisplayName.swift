import Foundation

struct TimeZoneDisplayNameProvider {
    static let locationNames: [String: (country: String, city: String)] = [
        // Entries from SettingsView's TimeZoneOption.locationNames with Japanese strings
        "Asia/Tokyo": ("日本", "東京"),
        "Europe/London": ("イギリス", "ロンドン"),
        "America/New_York": ("アメリカ合衆国", "ニューヨーク"),
        "America/Los_Angeles": ("アメリカ合衆国", "ロサンゼルス"),
        "Asia/Seoul": ("韓国", "ソウル"),
        "Asia/Shanghai": ("中国", "上海"),
        "Europe/Paris": ("フランス", "パリ"),
        "Europe/Berlin": ("ドイツ", "ベルリン"),
        "Australia/Sydney": ("オーストラリア", "シドニー"),
        "Asia/Amman": ("ヨルダン", "アンマン"),
        // Additional entries copied exactly from SettingsView's locationNames map
        "Asia/Hong_Kong": ("香港", "香港"),
        "Europe/Moscow": ("ロシア", "モスクワ"),
        "Asia/Singapore": ("シンガポール", "シンガポール"),
        "Asia/Kolkata": ("インド", "コルカタ"),
        "Asia/Dubai": ("アラブ首長国連邦", "ドバイ"),
        "Europe/Rome": ("イタリア", "ローマ"),
        "Europe/Madrid": ("スペイン", "マドリード"),
        "America/Chicago": ("アメリカ合衆国", "シカゴ"),
        "America/Denver": ("アメリカ合衆国", "デンバー"),
        "America/Toronto": ("カナダ", "トロント"),
        "America/Vancouver": ("カナダ", "バンクーバー"),
        "Pacific/Auckland": ("ニュージーランド", "オークランド"),
        "Asia/Jakarta": ("インドネシア", "ジャカルタ"),
        "Asia/Bangkok": ("タイ", "バンコク"),
        "Europe/Amsterdam": ("オランダ", "アムステルダム"),
        "Europe/Zurich": ("スイス", "チューリッヒ"),
        "America/Sao_Paulo": ("ブラジル", "サンパウロ"),
        "Africa/Cairo": ("エジプト", "カイロ"),
        "Africa/Johannesburg": ("南アフリカ", "ヨハネスブルグ"),
        "Europe/Istanbul": ("トルコ", "イスタンブール")
    ]
    
    static func displayName(for timeZone: TimeZone) -> String {
        if let names = locationNames[timeZone.identifier] {
            return "\(names.country)／\(names.city)"
        } else {
            let replaced = timeZone.identifier
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "/", with: "／")
            return replaced
        }
    }
    
    static func displayName(forIdentifier identifier: String) -> String {
        if let timeZone = TimeZone(identifier: identifier) {
            return displayName(for: timeZone)
        } else {
            let replaced = identifier
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "/", with: "／")
            return replaced
        }
    }
}
