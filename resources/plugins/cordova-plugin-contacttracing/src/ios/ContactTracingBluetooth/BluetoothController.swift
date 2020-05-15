//
//  Created by Zsombor Szabo on 11/03/2020.
//
//

import Foundation
import CoreBluetooth
#if canImport(UIKit) && !os(watchOS)
import UIKit.UIApplication
#endif
import os.log

extension TimeInterval {
    
    public static let peripheralConnectingTimeout: TimeInterval = 8
}

/// The controller responsible for the Bluetooth communication.
class BluetoothController: NSObject {
    
    weak var service: ContactTracingBluetoothService?
    
    public let label = UUID().uuidString
    
    @available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    lazy var log = OSLog(subsystem: "contact-tracing", category: "Bluetooth")
    
    lazy private var dispatchQueue: DispatchQueue = DispatchQueue(label: label)
    
    private var centralManager: CBCentralManager?
    
    private var restoredPeripherals: [CBPeripheral]?
    
    private var discoveredPeripherals = Set<CBPeripheral>()
    
    private var connectingTimeoutTimersForPeripheralIdentifiers =
        [UUID : Timer]()
    
    private var connectingPeripheralIdentifiers = Set<UUID>() {
        didSet {
            self.configureBackgroundTaskIfNeeded()
        }
    }
    
    private var connectedPeripheralIdentifiers = Set<UUID>() {
        didSet {
            self.configureBackgroundTaskIfNeeded()
        }
    }
    
    private var connectingConnectedPeripheralIdentifiers: Set<UUID> {
        self.connectingPeripheralIdentifiers.union(
            self.connectedPeripheralIdentifiers
        )
    }
    
    private var discoveringServicesPeripheralIdentifiers = Set<UUID>()
    
    private var readingConfigurationCharacteristics = Set<CBCharacteristic>()
    
    private var writingConfigurationCharacteristics = Set<CBCharacteristic>()
    
    #if os(watchOS) || os(tvOS)
    private static let maxNumberOfConcurrentPeripheralConnections = 2
    #else
    private static let maxNumberOfConcurrentPeripheralConnections = 5
    #endif
    
    private var peripheralManager: CBPeripheralManager?
    
    private var peripheralsToReadContactEventNumberFrom = Set<CBPeripheral>()
    
    private var peripheralsToWriteContactEventNumberTo = Set<CBPeripheral>()
    
    private var peripheralsToConnect: Set<CBPeripheral> {
        return Set(peripheralsToReadContactEventNumberFrom)
            .union(Set(peripheralsToWriteContactEventNumberTo))
    }
    
    private func configureBackgroundTaskIfNeeded() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        if self.connectingPeripheralIdentifiers.isEmpty &&
            self.connectedPeripheralIdentifiers.isEmpty {
            self.endBackgroundTaskIfNeeded()
        }
        else {
            self.beginBackgroundTaskIfNeeded()
        }
        #endif
    }
    
    // macCatalyst apps do not need background tasks.
    // watchOS apps do not have background tasks.
    #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private func beginBackgroundTaskIfNeeded() {
        guard self.backgroundTaskIdentifier == nil else { return }
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Did expire background task=%d",
                    log: self.log,
                    self.backgroundTaskIdentifier?.rawValue ?? 0
                )
            }
            self.endBackgroundTaskIfNeeded()
        }
        if let task = self.backgroundTaskIdentifier {
            if task == .invalid {
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Begin background task failed",
                        log: self.log,
                        type: .error
                    )
                }
            }
            else {
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Begin background task=%d",
                        log: self.log,
                        task.rawValue
                    )
                }
            }
        }
    }
    
    private func endBackgroundTaskIfNeeded() {
        if let identifier = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(identifier)
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "End background task=%d",
                    log: self.log,
                    self.backgroundTaskIdentifier?.rawValue ??
                        UIBackgroundTaskIdentifier.invalid.rawValue
                )
            }
            self.backgroundTaskIdentifier = nil
        }
    }
    #endif
    
    override init() {
        super.init()
        // macCatalyst apps do not need background support.
        // watchOS apps do not have background tasks.
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForegroundNotification(_:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(watchOS)
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    // MARK: - Notifications
    
    @objc func applicationWillEnterForegroundNotification(
        _ notification: Notification
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log("Application will enter foreground", log: self.log)
        }
        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            // Bug workaround: If Bluetooth was toggled while the app was in the
            // background then scanning fails when the app becomes active.
            // Restart scanning now.
            if self.centralManager?.isScanning ?? false {
                self.centralManager?.stopScan()
                self._startScan()
            }
        }
    }
    
    // MARK: -
    
    /// Returns true if the service is started.
    var isStarted: Bool {
        return self.centralManager != nil
    }
    
    /// Starts the service.
    func start() {
        self.dispatchQueue.async {
            guard self.centralManager == nil else {
                return
            }
            self.centralManager = CBCentralManager(
                delegate: self,
                queue: self.dispatchQueue,
                options: [
                    CBCentralManagerOptionRestoreIdentifierKey:
                    "contact-tracing-central"
                ]
            )
            self.peripheralManager = CBPeripheralManager(
                delegate: self,
                queue: self.dispatchQueue,
                options: [
                    CBPeripheralManagerOptionRestoreIdentifierKey:
                    "contact-tracing-peripheral"
                ]
            )
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Service started",
                    log: self.log
                )
            }
        }
    }
    
    /// Stops the service.
    func stop() {
        self.dispatchQueue.async {
            self.stopCentralManager()
            self.centralManager?.delegate = nil
            self.centralManager = nil
            self.stopPeripheralManager()
            self.peripheralManager?.delegate = nil
            self.peripheralManager = nil
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Service stopped",
                    log: self.log
                )
            }
        }
    }
    
    private func stopCentralManager() {
        self.connectingTimeoutTimersForPeripheralIdentifiers.values.forEach {
            $0.invalidate()
        }
        self.connectingTimeoutTimersForPeripheralIdentifiers.removeAll()
        self.discoveredPeripherals.forEach { self.flushPeripheral($0) }
        self.discoveredPeripherals.removeAll()
        self.connectingPeripheralIdentifiers.removeAll()
        self.connectedPeripheralIdentifiers.removeAll()
        self.discoveringServicesPeripheralIdentifiers.removeAll()
        self.readingConfigurationCharacteristics.removeAll()
        self.writingConfigurationCharacteristics.removeAll()
        self.peripheralsToReadContactEventNumberFrom.removeAll()
        self.peripheralsToWriteContactEventNumberTo.removeAll()
        if self.centralManager?.isScanning ?? false {
            self.centralManager?.stopScan()
        }
    }
    
    private func stopPeripheralManager() {
        if self.peripheralManager?.isAdvertising ?? false {
            self.peripheralManager?.stopAdvertising()
        }
        if self.peripheralManager?.state == .poweredOn {
            self.peripheralManager?.removeAllServices()
        }
    }
    
    private func connectPeripheralsIfNeeded() {
        guard self.peripheralsToConnect.count > 0 else {
            return
        }
        guard self.connectingConnectedPeripheralIdentifiers.count <
            BluetoothController.maxNumberOfConcurrentPeripheralConnections else {
                return
        }
        let disconnectedPeripherals = self.peripheralsToConnect.filter {
            $0.state == .disconnected || $0.state == .disconnecting
        }
        disconnectedPeripherals.prefix(
            BluetoothController.maxNumberOfConcurrentPeripheralConnections -
                self.connectingConnectedPeripheralIdentifiers.count
        ).forEach {
            self.connectIfNeeded(peripheral: $0)
        }
    }
    
    private func connectIfNeeded(peripheral: CBPeripheral) {
        guard let centralManager = centralManager else {
            return
        }
        if peripheral.state != .connected {
            if peripheral.state != .connecting {
                self.centralManager?.connect(peripheral, options: nil)
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Central manager connecting peripheral (uuid=%@ name='%@')",
                        log: self.log,
                        peripheral.identifier.description,
                        peripheral.name ?? ""
                    )
                }
                self.setupConnectingTimeoutTimer(for: peripheral)
                self.connectingPeripheralIdentifiers.insert(peripheral.identifier)
            }
        }
        else {
            self._centralManager(centralManager, didConnect: peripheral)
        }
    }
    
    private func setupConnectingTimeoutTimer(for peripheral: CBPeripheral) {
        let timer = Timer.init(
            timeInterval: .peripheralConnectingTimeout,
            target: self,
            selector: #selector(_connectingTimeoutTimerFired(timer:)),
            userInfo: ["peripheral" : peripheral],
            repeats: false
        )
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = timer
    }
    
    @objc private func _connectingTimeoutTimerFired(timer: Timer) {
        let userInfo = timer.userInfo
        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard let dict = userInfo as? [AnyHashable : Any],
                let peripheral = dict["peripheral"] as? CBPeripheral else {
                    return
            }
            if peripheral.state != .connected {
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Connecting did time out for peripheral (uuid=%@ name='%@')",
                        log: self.log,
                        peripheral.identifier.description,
                        peripheral.name ?? ""
                    )
                }
                self.flushPeripheral(peripheral)
            }
        }
    }
    
    private func flushPeripheral(_ peripheral: CBPeripheral) {
        self.peripheralsToReadContactEventNumberFrom.remove(peripheral)
        self.peripheralsToWriteContactEventNumberTo.remove(peripheral)
        self.discoveredPeripherals.remove(peripheral)
        self.cancelConnectionIfNeeded(for: peripheral)
    }
    
    private func cancelConnectionIfNeeded(for peripheral: CBPeripheral) {
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = nil
        if peripheral.state == .connecting || peripheral.state == .connected {
            self.centralManager?.cancelPeripheralConnection(peripheral)
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Central manager cancelled peripheral (uuid=%@ name='%@') connection",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? ""
                )
            }
        }
        peripheral.delegate = nil
        self.connectingPeripheralIdentifiers.remove(peripheral.identifier)
        self.connectedPeripheralIdentifiers.remove(peripheral.identifier)
        self.discoveringServicesPeripheralIdentifiers.remove(peripheral.identifier)
        peripheral.services?.forEach {
            $0.characteristics?.forEach {
                self.readingConfigurationCharacteristics.remove($0)
                self.writingConfigurationCharacteristics.remove($0)
            }
        }
        self.connectPeripheralsIfNeeded()
    }
}

extension BluetoothController: CBCentralManagerDelegate {
    
    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String : Any]
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager will restore state=%@",
                log: self.log,
                dict.description
            )
        }
        // Store the peripherals so we can cancel the connections to them when
        // the central manager's state changes to `.poweredOn`.
        self.restoredPeripherals =
            dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager did update state=%@",
                log: self.log,
                String(describing: central.state.rawValue)
            )
        }
        self.stopCentralManager()
        switch central.state {
            case .poweredOn:
                self.restoredPeripherals?.forEach({
                    central.cancelPeripheralConnection($0)
                })
                self.restoredPeripherals = nil
                self._startScan()
            default:
                ()
        }
    }
    
    private func _startScan() {
        guard let central = self.centralManager else { return }
        #if targetEnvironment(macCatalyst)
        // CoreBluetooth on macCatalyst doesn't discover services of iOS apps
        // running in the background. Therefore we scan for everything.
        let services: [CBUUID]? = nil
        #else
        let services = [
            CBUUID(string: BluetoothService.UUIDPeripheralServiceString)
        ]
        #endif
        let options: [String : Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey :
                NSNumber(booleanLiteral: true)
        ]
        central.scanForPeripherals(
            withServices: services,
            options: options
        )
        #if targetEnvironment(macCatalyst)
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager scanning for peripherals with services=%@ options=%@",
                log: self.log,
                services ?? "",
                options.description
            )
        }
        #else
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager scanning for peripherals with services=%@ options=%@",
                log: self.log,
                services,
                options.description
            )
        }
        #endif
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let isNewlyDiscovered = !self.discoveredPeripherals.contains(where: ({
            $0.identifier == peripheral.identifier })
        )
        
        let estimatedDistanceMeters = getEstimatedDistanceMeters(
            RSSI: RSSI.doubleValue,
            measuredRSSIAtOneMeter: getMeasuredRSSIAtOneMeter(advertisementData: advertisementData)
        )

        if isNewlyDiscovered {
            
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Central manager did discover peripheral (new=%d uuid=%@ name='%@') RSSI=%d (estimatedDistance=%.2f) advertisementData=%@",
                    log: self.log,
                    isNewlyDiscovered,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    RSSI.intValue,
                    estimatedDistanceMeters,
                    advertisementData.description
                )
            }
            
            self.discoveredPeripherals.insert(peripheral)
            
            let isConnectable = (advertisementData[
                CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false

            // Check if we can extract CEN from service data
            if let advertisementDataServiceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data],
                let serviceData = advertisementDataServiceData[CBUUID(string: BluetoothService.UUIDPeripheralServiceString)] {
                
                // TODO: extract other stuff from service data
                let cen = serviceData
                
                self.didFindContactEventNumber(cen)
                
                // Remote device is an Android device. Write CEN, because it can not see the iOS device.
                // To avoid using GATT client code on Anroid, for an Android device to receive a CEN from an iOS device, the iOS device connects as central and writes the value of the characteristic.
                if isConnectable {
                    self.peripheralsToWriteContactEventNumberTo.insert(peripheral)
                    self.connectPeripheralsIfNeeded()
                }
            }
            else {
                if isConnectable {
                    // Central (C) connects to Peripheral (P) and reads the value of the characteristic.
                    self.peripheralsToReadContactEventNumberFrom.insert(peripheral)
                    self.connectPeripheralsIfNeeded()
                }
            }
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager did connect peripheral (uuid=%@ name='%@')",
                log: self.log,
                peripheral.identifier.description,
                peripheral.name ?? ""
            )
        }
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier]?.invalidate()
        self.connectingTimeoutTimersForPeripheralIdentifiers[
            peripheral.identifier] = nil
        self.connectingPeripheralIdentifiers.remove(peripheral.identifier)
        // Bug workaround: Ignore duplicate connect messages from CoreBluetooth
        guard !self.connectedPeripheralIdentifiers.contains(
            peripheral.identifier) else {
                return
        }
        self.connectedPeripheralIdentifiers.insert(peripheral.identifier)
        self._centralManager(central, didConnect: peripheral)
    }
    
    func _centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        self.discoverServices(for: peripheral)
    }
    
    private func discoverServices(for peripheral: CBPeripheral) {
        guard !self.discoveringServicesPeripheralIdentifiers.contains(
            peripheral.identifier) else {
                return
        }
        self.discoveringServicesPeripheralIdentifiers.insert(peripheral.identifier)
        peripheral.delegate = self
        if peripheral.services == nil {
            let services = [
                CBUUID(string: BluetoothService.UUIDPeripheralServiceString)
            ]
            peripheral.discoverServices(services)
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') discovering services=%@",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    services)
            }
        }
        else {
            self._peripheral(peripheral, didDiscoverServices: nil)
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Central manager did fail to connect peripheral (uuid=%@ name='%@') error=%@",
                log: self.log,
                type:.error,
                peripheral.identifier.description,
                peripheral.name ?? "",
                error as CVarArg? ?? ""
            )
        }
        if #available(iOS 12.0, macOS 10.14, macCatalyst 13.0, tvOS 12.0,
            watchOS 5.0, *) {
            if let error = error as? CBError,
                error.code == CBError.operationNotSupported {
                self.peripheralsToReadContactEventNumberFrom.remove(peripheral)
                self.peripheralsToWriteContactEventNumberTo.remove(peripheral)
            }
        }
        self.cancelConnectionIfNeeded(for: peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Central manager did disconnect peripheral (uuid=%@ name='%@') error=%@",
                    log: self.log,
                    type:.error,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Central manager did disconnect peripheral (uuid=%@ name='%@')",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? ""
                )
            }
        }
        self.cancelConnectionIfNeeded(for: peripheral)
    }
}

extension BluetoothController: CBPeripheralDelegate {
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did discover services error=%@",
                    log: self.log,
                    type:.error,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did discover services",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? ""
                )
            }
        }
        self._peripheral(peripheral, didDiscoverServices: error)
    }
    
    func _peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        self.discoveringServicesPeripheralIdentifiers.remove(peripheral.identifier)
        guard error == nil else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        guard let services = peripheral.services, services.count > 0 else {
            self.peripheralsToReadContactEventNumberFrom.remove(peripheral)
            self.peripheralsToWriteContactEventNumberTo.remove(peripheral)
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        let servicesWithCharacteristicsToDiscover = services.filter {
            $0.characteristics == nil
        }
        if servicesWithCharacteristicsToDiscover.count == 0 {
            self.startTransfers(for: peripheral)
        }
        else {
            servicesWithCharacteristicsToDiscover.forEach { service in
                let characteristics = [
                    CBUUID(string: BluetoothService.UUIDContactEventNumberCharacteristicString),
                ]
                peripheral.discoverCharacteristics(characteristics, for: service)
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Peripheral (uuid=%@ name='%@') discovering characteristics=%@ for service=%@",
                        log: self.log,
                        peripheral.identifier.description,
                        peripheral.name ?? "",
                        characteristics.description,
                        service.description
                    )
                }
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did discover characteristics for service=%@ error=%@",
                    log: self.log,
                    type:.error,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    service.description,
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did discover characteristics for service=%@",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    service.description
                )
            }
        }
        guard error == nil, let services = peripheral.services else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        let servicesWithCharacteristicsToDiscover = services.filter {
            $0.characteristics == nil
        }
        // Did we discovered the characteristics of all the services?
        if servicesWithCharacteristicsToDiscover.count == 0 {
            self.startTransfers(for: peripheral)
        }
    }
    
    private func shouldReadContactEventNumber(from peripheral: CBPeripheral) -> Bool {
        return self.peripheralsToReadContactEventNumberFrom.contains(peripheral)
    }
    
    private func shouldWriteContactEventNumber(to peripheral: CBPeripheral) -> Bool {
        return self.peripheralsToWriteContactEventNumberTo.contains(peripheral)
    }
    
    private func startTransfers(for peripheral: CBPeripheral) {
        guard let services = peripheral.services else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        services.forEach { service in
            self._peripheral(
                peripheral,
                didDiscoverCharacteristicsFor: service,
                error: nil
            )
        }
        self.peripheralsToReadContactEventNumberFrom.remove(peripheral)
        self.peripheralsToWriteContactEventNumberTo.remove(peripheral)
    }
    
    func _peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            self.cancelConnectionIfNeeded(for: peripheral)
            return
        }
        
        if let contactEventNumberCharacteristic = service.characteristics?.first(where: {
            $0.uuid == CBUUID(
                string: BluetoothService.UUIDContactEventNumberCharacteristicString
            )
        }) {
            // Read number, if needed
            if self.shouldReadContactEventNumber(from: peripheral) {
                if !self.readingConfigurationCharacteristics.contains(
                    contactEventNumberCharacteristic) {
                    self.readingConfigurationCharacteristics.insert(
                        contactEventNumberCharacteristic)
                    peripheral.readValue(for: contactEventNumberCharacteristic)
                    if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                        os_log(
                            "Peripheral (uuid=%@ name='%@') reading value for characteristic=%@ for service=%@",
                            log: self.log,
                            peripheral.identifier.description,
                            peripheral.name ?? "",
                            contactEventNumberCharacteristic.description,
                            service.description
                        )
                    }
                }
            }
                // Write number, if needed
            else if self.shouldWriteContactEventNumber(to: peripheral) {
                if !self.writingConfigurationCharacteristics.contains(
                    contactEventNumberCharacteristic) {
                    self.writingConfigurationCharacteristics.insert(
                        contactEventNumberCharacteristic)
                    
                    let cen = generateContactEventNumber()
                    let value = cen
                    
                    peripheral.writeValue(
                        value,
                        for: contactEventNumberCharacteristic,
                        type: .withResponse
                    )
                    if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                        os_log(
                            "Peripheral (uuid=%@ name='%@') writing value for characteristic=%@ for service=%@",
                            log: self.log,
                            peripheral.identifier.description,
                            peripheral.name ?? "",
                            contactEventNumberCharacteristic.description,
                            service.description
                        )
                    }
                }
                
            }
        }
        else {
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did update value for characteristic=%@ for service=%@ error=%@",
                    log: self.log,
                    type:.error,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    characteristic.description,
                    characteristic.service.description,
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did update value=%{iec-bytes}d for characteristic=%@ for service=%@",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    characteristic.value?.count ?? 0,
                    characteristic.description,
                    characteristic.service.description
                )
            }
        }
        self.readingConfigurationCharacteristics.remove(characteristic)
        do {
            guard error == nil else {
                return
            }
            guard let value = characteristic.value else {
                throw CBATTError(.invalidPdu)
            }
            let cen = value
            // Central (C) connects to Peripheral (P) and reads the value of the characteristic.
            self.didFindContactEventNumber(cen)
        }
        catch {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Processing value failed=%@",
                    log: self.log,
                    type:.error,
                    error as CVarArg
                )
            }
        }
        let allCharacteristics = peripheral.characteristics(with: CBUUID(
            string: BluetoothService.UUIDContactEventNumberCharacteristicString
        ))
        if self.readingConfigurationCharacteristics
            .intersection(allCharacteristics).isEmpty {
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did write value for characteristic=%@ for service=%@ error=%@",
                    log: self.log,
                    type:.error,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    characteristic.description,
                    characteristic.service.description,
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral (uuid=%@ name='%@') did write value for characteristic=%@ for service=%@",
                    log: self.log,
                    peripheral.identifier.description,
                    peripheral.name ?? "",
                    characteristic.description,
                    characteristic.service.description
                )
            }
        }
        self.writingConfigurationCharacteristics.remove(characteristic)
        let allCharacteristics = peripheral.characteristics(with: CBUUID(
            string: BluetoothService.UUIDContactEventNumberCharacteristicString
        ))
        if self.writingConfigurationCharacteristics
            .intersection(allCharacteristics).isEmpty {
            self.cancelConnectionIfNeeded(for: peripheral)
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral (uuid=%@ name='%@') did modify services=%@",
                log: self.log,
                peripheral.identifier.description,
                peripheral.name ?? "",
                invalidatedServices
            )
        }
        if invalidatedServices.contains(where: {
            $0.uuid == CBUUID(string: BluetoothService.UUIDPeripheralServiceString)
        }) {
            self.flushPeripheral(peripheral)
        }
    }
}

extension BluetoothController: CBPeripheralManagerDelegate {
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        willRestoreState dict: [String : Any]
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager will restore state=%@",
                log: self.log,
                dict.description
            )
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager did update state=%@",
                log: self.log,
                String(describing: peripheral.state.rawValue)
            )
        }
        self._peripheralManagerDidUpdateState(peripheral)
    }
    
    func _peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        //    if #available(OSX 10.15, macCatalyst 13.1, iOS 13.1, tvOS 13.0, watchOS 6.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbManagerAuthorization: CBManager.authorization
        //        ) ?? .notDetermined
        //    }
        //    else if #available(OSX 10.15, macCatalyst 13.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbManagerAuthorization: peripheral.authorization
        //        ) ?? .notDetermined
        //    }
        //    else if #available(OSX 10.13, iOS 9.0, *) {
        //      self.service?.bluetoothAuthorization =
        //        BluetoothAuthorization(
        //          cbPeripheralManagerAuthorizationStatus:
        //          CBPeripheralManager.authorizationStatus()
        //        ) ?? .notDetermined
        //    }
        self.stopPeripheralManager()
        switch peripheral.state {
            case .poweredOn:
                let service = BluetoothService.peripheralService
                service.characteristics = [
                    BluetoothService.contactEventNumberCharacteristic
                ]
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Peripheral manager adding service=%@",
                        log: self.log,
                        service.description
                    )
                }
                peripheral.add(service)
            default:
                ()
        }
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral manager did add service=%@ error=%@",
                    log: self.log,
                    type:.error,
                    service.description,
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral manager did add service=%@",
                    log: self.log,
                    service.description
                )
            }
            self.startAdvertising()
        }
    }
    
    private func startAdvertising() {
        let advertisementData: [String : Any] = [
            CBAdvertisementDataServiceUUIDsKey :
                [CBUUID(string: BluetoothService.UUIDPeripheralServiceString)]
        ]
        self.peripheralManager?.startAdvertising(advertisementData)
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager starting advertising advertisementData=%@",
                log: self.log,
                advertisementData.description
            )
        }
    }
    
    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error = error {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral manager did start advertising error=%@",
                    log: self.log,
                    type:.error,
                    error as CVarArg
                )
            }
        }
        else {
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral manager did start advertising",
                    log: self.log
                )
            }
        }
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager did receive read request=%@",
                log: self.log,
                request.description
            )
        }
        
        let cen = generateContactEventNumber()
        request.value = cen
        
        peripheral.respond(to: request, withResult: .success)
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager did respond to read request with result=%d",
                log: self.log,
                CBATTError.success.rawValue
            )
        }
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            os_log(
                "Peripheral manager did receive write requests=%@",
                log: self.log,
                requests.description
            )
        }
        
        for request in requests {
            do {
                guard request.characteristic.uuid == CBUUID(
                    string: BluetoothService.UUIDContactEventNumberCharacteristicString
                    ) else {
                        throw CBATTError(.requestNotSupported)
                }
                guard let value = request.value else {
                    throw CBATTError(.invalidPdu)
                }
                
                self.didFindContactEventNumber(value)
            }
            catch {
                var result = CBATTError.invalidPdu
                if let error = error as? CBATTError {
                    result = error.code
                }
                peripheral.respond(to: request, withResult: result)
                if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                    os_log(
                        "Peripheral manager did respond to request=%@ with result=%d",
                        log: self.log,
                        request.description,
                        result.rawValue
                    )
                }
                return
            }
        }
        
        if let request = requests.first {
            peripheral.respond(to: request, withResult: .success)
            if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
                os_log(
                    "Peripheral manager did respond to request=%@ with result=%d",
                    log: self.log,
                    request.description,
                    CBATTError.success.rawValue
                )
            }
        }
    }
}
