//
//  PreviewSessionManager.swift
//  Orbit
//
//  Created by Cyril Zakka on 3/17/25.
//

import AccessorySetupKit
import Foundation
import SwiftUI

class MockASAccessory: ASAccessory, @unchecked Sendable {
    private var _displayName: String
    private var _state: ASAccessory.AccessoryState
    private var _descriptor: ASDiscoveryDescriptor

    override var displayName: String {
        return _displayName
    }

    override var state: ASAccessory.AccessoryState {
        return _state
    }

    override var descriptor: ASDiscoveryDescriptor {
        return _descriptor
    }

    init(displayName: String) {
        let descriptor = ASDiscoveryDescriptor()

        _displayName = displayName
        _state = .authorized
        _descriptor = descriptor

        super.init()
    }

    static var previewRing: MockASAccessory {
        return MockASAccessory(displayName: "Preview Ring")
    }
}

class PreviewRingSessionManager: RingSessionManager {
    override init() {
        super.init()
        pickerDismissed = true
        currentRing = MockASAccessory.previewRing
    }
}
