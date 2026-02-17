//
//  Packet.swift
//  Orbit
//
//  Created by Cyril Zakka on 3/17/25.
//

import Foundation

func makePacket(command: UInt8, subData: [UInt8]? = nil) throws -> [UInt8] {
    guard command <= 255 else {
        throw PacketError.invalidCommand
    }

    var packet = [UInt8](repeating: 0, count: 16)
    packet[0] = command

    if let subData = subData {
        guard subData.count <= 14 else {
            throw PacketError.invalidSubDataLength
        }
        for (index, byte) in subData.enumerated() {
            packet[index + 1] = byte
        }
    }

    packet[15] = checksum(packet: packet)

    return packet
}

func checksum(packet: [UInt8]) -> UInt8 {
    let sum = packet.reduce(0) { result, byte in
        result + UInt(byte)
    }
    return UInt8(sum % 255)
}

enum PacketError: Error {
    case invalidCommand
    case invalidSubDataLength
}
