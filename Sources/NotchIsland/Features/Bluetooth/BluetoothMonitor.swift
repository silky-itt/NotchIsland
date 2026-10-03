import Foundation
import IOBluetooth

/// Reports when headphones / AirPods... connect or disconnect (IOBluetooth calls back, no polling).
/// macOS asks for Bluetooth permission on first use.
@MainActor
final class BluetoothMonitor: NSObject {
    private let hud: HUDModel
    private var notification: IOBluetoothUserNotification?
    private let launchedAt = Date()

    init(hud: HUDModel) {
        self.hud = hud
        super.init()
        notification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(deviceConnected(_:device:)))
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        // May also fire for devices already connected at launch -> ignore the first few seconds
        guard Date().timeIntervalSince(launchedAt) > 3 else { return }
        hud.show(.device(name: device.name ?? "Bluetooth device", connected: true))
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        hud.show(.device(name: device.name ?? "Bluetooth device", connected: false))
    }
}
