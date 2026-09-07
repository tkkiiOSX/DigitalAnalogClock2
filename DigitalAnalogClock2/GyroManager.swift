// GyroManager.swift (必要に応じてContentView.swiftから分離)
import CoreMotion
import Foundation
import Combine

final class GyroManager: ObservableObject {
    @Published var gravityAngle: Double = 0 // ラジアン値
    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            let angle = atan2(g.x, -g.y) // 画面に対する重力方向
            self?.gravityAngle = angle
        }
    }
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
