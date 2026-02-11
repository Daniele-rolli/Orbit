//
//  BluetoothManager.swift
//  Orbit
//
//  Created by Daniele Rolli on 1/31/26.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    
    weak var sessionManager: RingSessionManager?
    var centralManager: CBCentralManager?
    
    var uartRxCharacteristic: CBCharacteristic?
    var uartTxCharacteristic: CBCharacteristic?
    var deviceInfoHardwareCharacteristic: CBCharacteristic?
    var deviceInfoFirmwareCharacteristic: CBCharacteristic?
    
    init(sessionManager: RingSessionManager) {
        self.sessionManager = sessionManager
        super.init()
    }
    
    func connect() {
        guard let sessionManager = sessionManager,
              let manager = centralManager,
              manager.state == .poweredOn,
              let peripheral = sessionManager.peripheral
        else {
            return
        }
        
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionStartDelayKey: 1
        ]
        
        manager.connect(peripheral, options: options)
    }
    
    func disconnect() {
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral,
              let manager = centralManager
        else {
            return
        }
        
        sessionManager.realtimeManager?.stopRealtimeSteps()
        manager.cancelPeripheralConnection(peripheral)
    }
    
    func sendCommand(_ command: UInt8, subData: [UInt8] = [], characteristic: CBCharacteristic? = nil) {
        guard let sessionManager = sessionManager,
              let peripheral = sessionManager.peripheral
        else {
            print("Cannot send command. Peripheral not ready.")
            return
        }
        
        let targetCharacteristic = characteristic ?? uartRxCharacteristic
        guard let char = targetCharacteristic else {
            print("Cannot send command. Characteristic not ready.")
            return
        }
        
        do {
            let packet = try makePacket(command: command, subData: subData)
            let data = Data(packet)
            print("Sending command 0x\(String(format: "%02X", command)): \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
            peripheral.writeValue(data, for: char, type: .withResponse)
        } catch {
            print("Failed to create packet: \(error)")
        }
    }
    
    private func makePacket(command: UInt8, subData: [UInt8] = []) throws -> [UInt8] {
        let contents = [command] + subData
        
        guard contents.count <= 15 else {
            throw NSError(domain: "BluetoothManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Packet content too long"])
        }
        
        var packet = [UInt8](repeating: 0, count: 16)
        for (index, byte) in contents.enumerated() {
            packet[index] = byte
        }
        
        // Calculate checksum
        var checksum: UInt8 = 0
        for byte in contents {
            checksum = checksum &+ byte
        }
        packet[15] = checksum
        
        return packet
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central manager state: \(central.state)")
        
        guard let sessionManager = sessionManager else { return }
        
        switch central.state {
        case .poweredOn:
            if let peripheralUUID = sessionManager.currentRing?.bluetoothIdentifier {
                if let knownPeripheral = central.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {
                    print("Found previously connected peripheral")
                    sessionManager.peripheral = knownPeripheral
                    sessionManager.peripheral?.delegate = self
                    connect()
                } else {
                    print("Known peripheral not found, starting scan")
                }
            }
        default:
            sessionManager.peripheral = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral)")
        
        guard let sessionManager = sessionManager else { return }
        
        peripheral.delegate = self
        peripheral.discoverServices([
            CBUUID(string: RingConstants.ringServiceUUID),
            CBUUID(string: RingConstants.deviceInfoServiceUUID),
            CBUUID(string: RingConstants.mainServiceUUID)
        ])
        
        sessionManager.peripheralConnected = true
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("Disconnected from peripheral: \(peripheral)")
        
        guard let sessionManager = sessionManager else { return }
        
        sessionManager.peripheralConnected = false
        sessionManager.peripheralReady = false
        sessionManager.realtimeManager?.stopRealtimeSteps()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("Failed to connect to peripheral: \(peripheral), error: \(error.debugDescription)")
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard error == nil, let services = peripheral.services else {
            print("No services found or error occurred: \(String(describing: error))")
            return
        }
        
        print("Found \(services.count) services")
        for service in services {
            switch service.uuid {
            case CBUUID(string: RingConstants.ringServiceUUID):
                print("Found ring service, discovering characteristics...")
                peripheral.discoverCharacteristics([
                    CBUUID(string: RingConstants.uartRxCharacteristicUUID),
                    CBUUID(string: RingConstants.uartTxCharacteristicUUID)
                ], for: service)
                
            case CBUUID(string: RingConstants.deviceInfoServiceUUID):
                print("Found device info service, discovering characteristics...")
                peripheral.discoverCharacteristics([
                    CBUUID(string: RingConstants.deviceHardwareUUID),
                    CBUUID(string: RingConstants.deviceFirmwareUUID)
                ], for: service)
                
            case CBUUID(string: RingConstants.mainServiceUUID):
                print("Found main service")
                
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            print("No characteristics found or error occurred: \(String(describing: error))")
            return
        }
        
        guard let sessionManager = sessionManager else { return }
        
        print("Found \(characteristics.count) characteristics for service \(service.uuid)")
        for characteristic in characteristics {
            switch characteristic.uuid {
            case CBUUID(string: RingConstants.uartRxCharacteristicUUID):
                print("Found UART RX characteristic")
                self.uartRxCharacteristic = characteristic
                
            case CBUUID(string: RingConstants.uartTxCharacteristicUUID):
                print("Found UART TX characteristic")
                self.uartTxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
            case CBUUID(string: RingConstants.deviceHardwareUUID):
                print("Found hardware version characteristic")
                self.deviceInfoHardwareCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                
            case CBUUID(string: RingConstants.deviceFirmwareUUID):
                print("Found firmware version characteristic")
                self.deviceInfoFirmwareCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                
            default:
                print("Found other characteristic: \(characteristic.uuid)")
            }
        }
        
        // Check if we're ready
        if uartRxCharacteristic != nil && uartTxCharacteristic != nil && !sessionManager.peripheralReady {
            sessionManager.peripheralReady = true
            print("Peripheral ready for communication")
            sessionManager.postConnectInitialization()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else {
            print("Failed to read characteristic value: \(String(describing: error))")
            return
        }
        
        guard let sessionManager = sessionManager else { return }
        
        let packet = [UInt8](value)
        
        // Handle device info characteristics
        if characteristic.uuid == CBUUID(string: RingConstants.deviceHardwareUUID) {
            if let version = String(data: value, encoding: .utf8) {
                sessionManager.deviceInfo.hardwareVersion = version
                print("Hardware version: \(version)")
            }
            return
        }
        
        if characteristic.uuid == CBUUID(string: RingConstants.deviceFirmwareUUID) {
            if let version = String(data: value, encoding: .utf8) {
                sessionManager.deviceInfo.firmwareVersion = version
                print("Firmware version: \(version)")
            }
            return
        }
        
        // Handle UART TX notifications
        if characteristic.uuid == CBUUID(string: RingConstants.uartTxCharacteristicUUID) {
            print("Received packet: \(packet.map { String(format: "%02X", $0) }.joined(separator: " "))")
            sessionManager.syncManager?.handlePacket(packet)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write to characteristic failed: \(error.localizedDescription)")
        } else {
            print("Write to characteristic successful")
        }
    }
}
