////
////  BLEManager.swift
////  MusicLightSync
////
////  Created by Rahul Srivastava on 06/04/25.
////
//
//import Foundation
//import CoreBluetooth
//
//enum LEDPattern {
//    case fade, flash
//}
//
//class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
//    private var centralManager: CBCentralManager!
//    private var ledPeripheral: CBPeripheral?
//    private var ledCharacteristic: CBCharacteristic?
//
//    override init() {
//        super.init()
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//    }
//
//    func scanForDevices() {
//        guard centralManager.state == .poweredOn else {
//            print("Bluetooth is not ready")
//            return
//        }
//        centralManager.scanForPeripherals(withServices: nil, options: nil)
//    }
//
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        if central.state == .poweredOn {
//            scanForDevices() // or allow scan button to work now
//        } else {
//            print("Bluetooth not available")
//        }
//    }
//
//
//
//
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        if let name = peripheral.name, name.contains("BLE") || name.contains("SP") {
//            centralManager.stopScan()
//            ledPeripheral = peripheral
//            ledPeripheral?.delegate = self
//            centralManager.connect(peripheral, options: nil)
//        }
//    }
//
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        peripheral.discoverServices(nil)
//    }
//
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//        for service in peripheral.services ?? [] {
//            peripheral.discoverCharacteristics(nil, for: service)
//        }
//    }
//
////    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
////        for characteristic in service.characteristics ?? [] {
////            if characteristic.properties.contains(.write) {
////                ledCharacteristic = characteristic
////                print("Found writable characteristic: \(characteristic.uuid)")
////            }
////        }
////    }
//    
//    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//        for characteristic in service.characteristics ?? [] {
//            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
//                writeCharacteristic = characteristic
//                print("Writable characteristic found: \(characteristic.uuid)")
//            }
//        }
//    }
//
//
//    func sendRGB(red: UInt8, green: UInt8, blue: UInt8) {
//        guard let peripheral = ledPeripheral, let characteristic = ledCharacteristic else { return }
//        let data: [UInt8] = [0x7E, 0x07, 0x05, red, green, blue, 0xEF]
//        let packet = Data(data)
//        peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
//    }
//
//    func sendPatternCommand(pattern: LEDPattern, brightness: Double) {
//        guard let peripheral = ledPeripheral, let characteristic = ledCharacteristic else { return }
//        let command: [UInt8]
//        switch pattern {
//        case .fade:
//            command = [0x7E, 0x03, 0x00, 0x01, UInt8(255 * brightness), 0xEF]
//        case .flash:
//            command = [0x7E, 0x03, 0x00, 0x02, UInt8(255 * brightness), 0xEF]
//        }
//        let packet = Data(command)
//        peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
//    }
//    
//    func sendDuoCoColorPacket(red: UInt8, green: UInt8, blue: UInt8, brightness: UInt8 = 0x10) {
//        let packet: [UInt8] = [0x7E, 0x07, 0x05, 0x03, red, green, blue, brightness, 0xEF]
//        let data = Data(packet)
//        sendRawPacket(data)
//    }
//    
//    func sendRawPacket(_ data: Data) {
//        if let peripheral = connectedPeripheral,
//           let characteristic = targetWriteCharacteristic {
//            peripheral.writeValue(data, for: characteristic, type: .withResponse)
//        }
//    }
//
//}

import CoreBluetooth
import SwiftUI
import os.log

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let logger = Logger(subsystem: "com.musiclightsync.ble", category: "BLEManager")

    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?

    @Published var isConnected = false
    @Published var isReconnecting = false
    @Published var discoveredPeripherals = [String: CBPeripheral]()
    @Published var connectedDeviceName = ""

    private var isIntentionalDisconnect = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.musiclightsync.ble.central"]
        )
    }

    func scanForDevices() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Central state updated: \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        logger.info("Restoring central manager state")
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let peripheral = peripherals.first else { return }

        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectedDeviceName = peripheral.name ?? ""

        if peripheral.state == .connected {
            isConnected = true
            peripheral.discoverServices(nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        discoveredPeripherals[name] = peripheral
    }

    func connectToDevice(named name: String) {
        guard let peripheral = discoveredPeripherals[name] else { return }
        isIntentionalDisconnect = false
        reconnectAttempts = 0
        centralManager.connect(peripheral)
        peripheral.delegate = self
        connectedDeviceName = name
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.name ?? "unknown")")
        isConnected = true
        isReconnecting = false
        reconnectAttempts = 0
        connectedPeripheral = peripheral
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to peripheral: \(error?.localizedDescription ?? "unknown error")")
        attemptReconnect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral: \(peripheral.name ?? "unknown"), error: \(error?.localizedDescription ?? "none")")
        isConnected = false
        writeCharacteristic = nil

        if isIntentionalDisconnect {
            isIntentionalDisconnect = false
            connectedPeripheral = nil
            connectedDeviceName = ""
            return
        }

        attemptReconnect(to: peripheral)
    }

    private func attemptReconnect(to peripheral: CBPeripheral) {
        guard reconnectAttempts < maxReconnectAttempts else {
            logger.error("Max reconnect attempts reached, giving up")
            reconnectAttempts = 0
            isReconnecting = false
            connectedPeripheral = nil
            connectedDeviceName = ""
            return
        }

        reconnectAttempts += 1
        isReconnecting = true
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        logger.info("Attempting reconnect #\(self.reconnectAttempts) in \(delay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            self.centralManager.connect(peripheral, options: nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
                break
            }
        }
    }

    func sendRawCommand(_ command: [UInt8]) {
        guard let peripheral = connectedPeripheral, let writeChar = writeCharacteristic else { return }
        let data = Data(command)
        peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
    }

    func sendRGB(red: UInt8, green: UInt8, blue: UInt8) {
        let command: [UInt8] = [0x7e, 0x07, 0x05, 0x03, red, green, blue, 0x10, 0xef]
        sendRawCommand(command)
    }

    func sendPatternCommand(pattern: PatternType, brightness: Double, speed: Double) {
        var command: [UInt8] = [0x7e, 0x04, 0x04, 0x00, 0x00, 0x01, 0xff, 0x00, 0xef]

        switch pattern {
        case .fade:
            command[3] = 0x03
        case .flash:
            command[3] = 0x04
        case .colorWheel:
            command[3] = 0x05
        case .staticColor:
            command[3] = 0x01
        }

        command[4] = UInt8(brightness * 255)
        command[5] = UInt8(speed * 10)

        sendRawCommand(command)
    }

    func disconnectDevice() {
        guard let peripheral = connectedPeripheral else { return }
        isIntentionalDisconnect = true
        centralManager.cancelPeripheralConnection(peripheral)
        isConnected = false
        connectedDeviceName = ""
    }
}
