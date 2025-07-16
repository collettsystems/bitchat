#if os(Windows)
import Foundation
import WinSDK
import WindowsDevicesBluetooth
import WindowsDevicesBluetoothAdvertisement
import WindowsStorageStreams

class WindowsBluetoothMeshService: NSObject, MeshServiceProtocol {
    weak var delegate: BitchatDelegate?
    var myPeerID: String = UUID().uuidString

    private var watcher: Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher?
    private var publisher: Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementPublisher?
    private let manufacturerId: UInt16 = 0xB1C7 // 'bitchat' magic

    // MARK: - Service Control
    func startServices() {
        setupScanning()
        startAdvertising()
    }

    private func setupScanning() {
        watcher = Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher()
        watcher?.scanningMode = .active

        _ = watcher?.addReceived { [weak self] sender, args in
            guard let self = self else { return }
            for md in args.advertisement.manufacturerData {
                if md.companyId == self.manufacturerId,
                   let buffer = Data(from: md.data),
                   let text = String(data: buffer, encoding: .utf8) {
                    self.handleAdvertisement(text)
                }
            }
        }

        watcher?.start()
    }

    private func startAdvertising() {
        let adv = Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisement()
        let md = Windows.Devices.Bluetooth.Advertisement.BluetoothLEManufacturerData()
        md.companyId = manufacturerId
        let hello = "HELLO:\(myPeerID)"
        md.data = hello.data(using: .utf8)?.toBuffer() ?? IBuffer()
        _ = adv.manufacturerData.append(md)
        publisher = Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementPublisher(advertisement: adv)
        publisher?.start()
    }

    private func handleAdvertisement(_ text: String) {
        if text.hasPrefix("HELLO:" ) {
            let peer = String(text.dropFirst(6))
            if peer != myPeerID {
                delegate?.didConnectToPeer(peer)
            }
        } else if text.hasPrefix("MSG:" ) {
            let content = String(text.dropFirst(4))
            let message = BitchatMessage(sender: peerIDFromString(text), content: content, timestamp: Date(), isRelay: false)
            delegate?.didReceiveMessage(message)
        }
    }

    private func peerIDFromString(_ string: String) -> String {
        // naive extraction of peer id
        if let range = string.range(of: "|") {
            return String(string[..<range.lowerBound])
        }
        return "unknown"
    }

    // MARK: - Messaging
    func sendBroadcastAnnounce() {
        // Windows implementation pending
    }

    func sendMessage(_ content: String, mentions: [String], channel: String?) {
        // Windows implementation pending
    }

    func sendPrivateMessage(_ content: String, to peerID: String, recipientNickname: String, messageID: String?) {
    }

    func sendEncryptedChannelMessage(_ content: String, mentions: [String], channel: String, channelKey: SymmetricKey, messageID: String?, timestamp: Date?) {
    }

    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: String) {
    }

    func sendChannelMetadata(_ metadata: ChannelMetadata) {
    }

    func sendChannelLeaveNotification(_ channel: String) {
    }

    func announcePasswordProtectedChannel(_ channel: String, creatorID: String?, keyCommitment: String?) {
    }

    func sendChannelRetentionAnnouncement(_ channel: String, enabled: Bool) {
    }

    func sendChannelPasswordUpdate(_ password: String, channel: String, newCommitment: String, to peerID: String) {
    }

    func sendChannelKeyVerifyRequest(_ request: ChannelKeyVerifyRequest, to peers: [String]) {
    }

    func sendChannelKeyVerifyResponse(_ response: ChannelKeyVerifyResponse, to peerID: String) {
    }

    func emergencyDisconnectAll() {
    }

    func getNoiseService() -> NoiseEncryptionService {
        return NoiseEncryptionService()
    }

    func getPeerFingerprint(_ peerID: String) -> String? { nil }

    func getPeerNicknames() -> [String : String] { [:] }

    func getPeerRSSI() -> [String : NSNumber] { [:] }

func getFingerprint(for peerID: String) -> String? { nil }
}

// MARK: - IBuffer helpers
fileprivate extension Data {
    init?(from buffer: Windows.Storage.Streams.IBuffer?) {
        guard let buffer = buffer else { return nil }
        let length = Int(buffer.Length)
        self.init(count: length)
        _ = self.withUnsafeMutableBytes { ptr in
            memcpy(ptr.baseAddress, buffer.bufferPointer, length)
        }
    }

    func toBuffer() -> Windows.Storage.Streams.IBuffer {
        var data = self
        return data.withUnsafeMutableBytes { ptr in
            Windows.Storage.Streams.Buffer(bytes: ptr.baseAddress!, capacity: UInt32(count))
        }
    }
}
#endif
