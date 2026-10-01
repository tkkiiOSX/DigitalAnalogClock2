import Foundation

struct ClockInfo: Codable, Identifiable {
    let id: UUID
    let timeZoneIdentifier: String
    let showOuterRing: Bool
}
