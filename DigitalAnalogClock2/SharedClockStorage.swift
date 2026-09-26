import Foundation
import WidgetKit
import ImageIO
import UniformTypeIdentifiers

enum SharedClockStorage {
    static let appGroupIdentifier =
        "group.com.example.DigitalAnalogClock2"

    static let savedClocksKey = "savedClocks"

    private static let migrationKey =
        "sharedSettingsMigrationCompleted"

    static let defaults: UserDefaults = {
        if let defaults = UserDefaults(
            suiteName: appGroupIdentifier
        ) {
            return defaults
        }

        assertionFailure(
            "App Group UserDefaultsを作成できません: "
                + appGroupIdentifier
        )

        return UserDefaults.standard
    }()

    private static var sharedContainerURL: URL? {
        guard let containerURL = FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier:
                    appGroupIdentifier
            ) else {
            print(
                "App Group共有フォルダを取得できません: "
                    + appGroupIdentifier
            )
            return nil
        }

        let directoryURL = containerURL
            .appendingPathComponent(
                "ClockDesign",
                isDirectory: true
            )

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            print(
                "共有フォルダを作成できません: \(error)"
            )
            return nil
        }

        return directoryURL
    }

    static func clockDesignPrefix(for id: UUID) -> String {
        "clockDesign.\(id)."
    }

    static func backgroundImageURL(
        forKey key: String
    ) -> URL? {
        guard let sharedContainerURL else {
            return nil
        }

        return sharedContainerURL
            .appendingPathComponent(
                imageFileName(forKey: key),
                isDirectory: false
            )
    }

    @discardableResult
    static func saveBackgroundImage(
        _ data: Data,
        forKey key: String
    ) -> Bool {
        guard let url = backgroundImageURL(
            forKey: key
        ) else {
            print(
                "背景写真を保存できる共有URLがありません"
            )
            return false
        }

        guard let optimizedData = optimizedJPEGData(
            from: data
        ) else {
            print(
                "背景写真の縮小に失敗しました"
            )
            return false
        }

        do {
            try optimizedData.write(
                to: url,
                options: [.atomic]
            )

            return true
        } catch {
            print(
                "背景写真の保存に失敗しました: \(error)"
            )
            return false
        }
    }

    static func loadBackgroundImage(
        forKey key: String
    ) -> Data? {
        guard let url = backgroundImageURL(
            forKey: key
        ),
        let data = try? Data(contentsOf: url) else {
            return nil
        }

        // 既存の大きな画像も読み込み時に縮小する
        return optimizedJPEGData(from: data)
    }

    static func removeBackgroundImage(
        forKey key: String
    ) {
        guard let url = backgroundImageURL(
            forKey: key
        ) else {
            return
        }

        do {
            if FileManager.default.fileExists(
                atPath: url.path
            ) {
                try FileManager.default.removeItem(
                    at: url
                )
            }
        } catch {
            print(
                "背景写真の削除に失敗しました: \(error)"
            )
        }
    }

    static func migrateLegacySettingsIfNeeded() {
        let legacyDefaults = UserDefaults.standard
        let sharedDefaults = defaults

        migrateSavedClocks(
            from: legacyDefaults,
            to: sharedDefaults
        )

        migrateGlobalSettings(
            from: legacyDefaults,
            to: sharedDefaults
        )

        guard let savedClocksData = sharedDefaults.data(
            forKey: savedClocksKey
        ),
        let clockInfos = try? JSONDecoder().decode(
            [SharedClockInfo].self,
            from: savedClocksData
        ) else {
            sharedDefaults.set(
                true,
                forKey: migrationKey
            )
            return
        }

        for clockInfo in clockInfos {
            migrateClockDesignSettings(
                clockID: clockInfo.id,
                from: legacyDefaults,
                to: sharedDefaults
            )
        }

        sharedDefaults.set(
            true,
            forKey: migrationKey
        )
    }

    static func reloadWidget() {
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func optimizedJPEGData(
        from data: Data
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ),
        let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            [
                kCGImageSourceCreateThumbnailFromImageAlways:
                    true,
                kCGImageSourceCreateThumbnailWithTransform:
                    true,
                kCGImageSourceThumbnailMaxPixelSize:
                    1024
            ] as CFDictionary
        ) else {
            return nil
        }

        let outputData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            outputData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [
                kCGImageDestinationLossyCompressionQuality:
                    0.82
            ] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return outputData as Data
    }

    private static func migrateSavedClocks(
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        guard destination.data(
            forKey: savedClocksKey
        ) == nil,
        let data = source.data(
            forKey: savedClocksKey
        ) else {
            return
        }

        destination.set(
            data,
            forKey: savedClocksKey
        )
    }

    private static func migrateGlobalSettings(
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        let keys = [
            "keepLabelsUpright",
            "sweepSecondHand",
            "tickVolume",
            "hourlyChimeEnabled",
            "hourlyChimeVolume",
            "hourlyChimeIntervalMinutes"
        ]

        for key in keys {
            guard destination.object(
                forKey: key
            ) == nil,
            let value = source.object(
                forKey: key
            ) else {
                continue
            }

            destination.set(
                value,
                forKey: key
            )
        }
    }

    private static func migrateClockDesignSettings(
        clockID: UUID,
        from source: UserDefaults,
        to destination: UserDefaults
    ) {
        let prefix = clockDesignPrefix(
            for: clockID
        )

        let keys = [
            "frameStyle",
            "frameColor",
            "hourHandColor",
            "minuteHandColor",
            "secondHandColor",
            "backgroundColor",
            "backgroundImage",
            "numeralStyle"
        ]

        for key in keys {
            let fullKey = prefix + key

            guard destination.object(
                forKey: fullKey
            ) == nil,
            let value = source.object(
                forKey: fullKey
            ) else {
                continue
            }

            destination.set(
                value,
                forKey: fullKey
            )
        }

        let imageKey = prefix + "backgroundImage"

        if let imageData = destination.data(
            forKey: imageKey
        ) {
            _ = saveBackgroundImage(
                imageData,
                forKey: imageKey
            )
        }
    }

    private static func imageFileName(
        forKey key: String
    ) -> String {
        let allowedCharacters = CharacterSet(
            charactersIn:
                "abcdefghijklmnopqrstuvwxyz"
                + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                + "0123456789-_ ."
        )

        let sanitized = key
            .components(
                separatedBy: allowedCharacters.inverted
            )
            .joined()
            .replacingOccurrences(
                of: " ",
                with: ""
            )

        return sanitized + ".jpg"
    }
}

private struct SharedClockInfo: Codable {
    let id: UUID
    let timeZoneIdentifier: String
    let showOuterRing: Bool
}
