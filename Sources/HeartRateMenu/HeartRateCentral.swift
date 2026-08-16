import CoreBluetooth
import Foundation

@MainActor
final class HeartRateCentral: NSObject, ObservableObject {
    struct Device: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
    }

    enum State: Equatable {
        case unavailable
        case searching
        case chooseDevice
        case connecting(String)
        case subscribed(String)
        case unsupported
    }

    @Published private(set) var currentHeartRate: Int?
    @Published private(set) var sampleDate: Date?
    @Published private(set) var devices: [Device] = []
    @Published private(set) var state: State = .unavailable
    @Published private(set) var selectedDeviceID: UUID?

    private let heartRateService = CBUUID(string: "180D")
    private let heartRateMeasurement = CBUUID(string: "2A37")
    private let selectedPeripheralKey = "heart-rate-menu.selected-peripheral"
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var scanTimer: Timer?

    var isFresh: Bool {
        guard let sampleDate else { return false }
        return Date().timeIntervalSince(sampleDate) < 15
    }

    var displayHeartRate: String {
        guard isFresh, let currentHeartRate else { return "--" }
        return String(currentHeartRate)
    }

    var statusText: String {
        switch state {
        case .unavailable: return "蓝牙不可用"
        case .searching: return "正在扫描设备"
        case .chooseDevice: return "请选择心率设备"
        case .connecting(let name): return "正在连接 \(name)"
        case .subscribed(let name): return isFresh ? "正在读取 \(name)" : "等待 \(name) 的心率"
        case .unsupported: return "该设备未提供标准心率服务"
        }
    }

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        scanTimer?.invalidate()
        scanTimer = nil
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        central = nil
        currentHeartRate = nil
        sampleDate = nil
        state = .unavailable
    }

    func scanAgain() {
        guard central?.state == .poweredOn else { return }
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }
        devices = []
        peripherals = [:]
        selectedDeviceID = nil
        UserDefaults.standard.removeObject(forKey: selectedPeripheralKey)
        beginScan()
    }

    func selectDevice(_ identifier: UUID) {
        guard let candidate = peripherals[identifier] else { return }
        connect(candidate)
    }

    private func restoreKnownDevice() -> Bool {
        guard let text = UserDefaults.standard.string(forKey: selectedPeripheralKey),
              let identifier = UUID(uuidString: text),
              let candidate = central?.retrievePeripherals(withIdentifiers: [identifier]).first
        else { return false }
        peripherals[identifier] = candidate
        selectedDeviceID = identifier
        connect(candidate)
        return true
    }

    private func beginScan() {
        guard central?.state == .poweredOn, peripheral == nil else { return }
        scanTimer?.invalidate()
        state = .searching
        // Some devices omit 0x180D from advertisements; validate it after selection.
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishScan() }
        }
    }

    private func finishScan() {
        guard peripheral == nil else { return }
        central?.stopScan()
        state = .chooseDevice
    }

    private func connect(_ candidate: CBPeripheral) {
        scanTimer?.invalidate()
        central?.stopScan()
        peripheral = candidate
        candidate.delegate = self
        selectedDeviceID = candidate.identifier
        state = .connecting(displayName(for: candidate, advertisementData: nil))
        central?.connect(candidate)
    }

    private func register(_ candidate: CBPeripheral, advertisementData: [String: Any], rssi: Int) {
        peripherals[candidate.identifier] = candidate
        let device = Device(id: candidate.identifier, name: displayName(for: candidate, advertisementData: advertisementData), rssi: rssi)
        devices.removeAll { $0.id == device.id }
        devices.append(device)
        devices.sort { $0.rssi > $1.rssi }
    }

    private func displayName(for candidate: CBPeripheral, advertisementData: [String: Any]?) -> String {
        candidate.name ?? advertisementData?[CBAdvertisementDataLocalNameKey] as? String ?? "未命名蓝牙设备"
    }

    private func rejectCurrentPeripheral(_ candidate: CBPeripheral) {
        guard candidate.identifier == peripheral?.identifier else { return }
        central?.cancelPeripheralConnection(candidate)
        peripheral = nil
    }
}

extension HeartRateCentral: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard central.state == .poweredOn else {
                self.scanTimer?.invalidate()
                self.state = .unavailable
                return
            }
            if !self.restoreKnownDevice() {
                self.beginScan()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover candidate: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            guard self.peripheral == nil else { return }
            self.register(candidate, advertisementData: advertisementData, rssi: RSSI.intValue)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: "180D")])
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            guard peripheral.identifier == self.peripheral?.identifier else { return }
            self.peripheral = nil
            self.beginScan()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            guard peripheral.identifier == self.peripheral?.identifier else { return }
            self.peripheral = nil
            self.beginScan()
        }
    }
}

extension HeartRateCentral: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: "180D") })
        else {
            Task { @MainActor in
                self.state = .unsupported
                self.rejectCurrentPeripheral(peripheral)
            }
            return
        }
        peripheral.discoverCharacteristics([CBUUID(string: "2A37")], for: service)
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let measurement = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "2A37") })
        else {
            Task { @MainActor in
                self.state = .unsupported
                self.rejectCurrentPeripheral(peripheral)
            }
            return
        }
        peripheral.setNotifyValue(true, for: measurement)
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            guard error == nil, characteristic.isNotifying else {
                self.state = .unsupported
                self.rejectCurrentPeripheral(peripheral)
                return
            }
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: self.selectedPeripheralKey)
            self.state = .subscribed(self.displayName(for: peripheral, advertisementData: nil))
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == CBUUID(string: "2A37"),
              let value = characteristic.value,
              let heartRate = HeartRateMeasurement.parse(value)
        else { return }
        Task { @MainActor in
            self.currentHeartRate = heartRate
            self.sampleDate = Date()
        }
    }
}
