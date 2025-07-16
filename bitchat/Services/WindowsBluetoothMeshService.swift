#if os(Windows)
import Foundation
import WinSDK
import WindowsDevicesBluetooth
import WindowsDevicesBluetoothAdvertisement
import WindowsStorageStreams
import CryptoKit

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

    private func broadcastText(_ text: String, duration: TimeInterval = 1.0) {
        let adv = Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisement()
        let md = Windows.Devices.Bluetooth.Advertisement.BluetoothLEManufacturerData()
        md.companyId = manufacturerId
        md.data = text.data(using: .utf8)?.toBuffer() ?? IBuffer()
        _ = adv.manufacturerData.append(md)
        let pub = Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementPublisher(advertisement: adv)
        pub.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            pub.stop()
        }
    }

    // MARK: - Messaging
    func sendBroadcastAnnounce() {
        broadcastText("HELLO:\(myPeerID)")
    }

    func sendMessage(_ content: String, mentions: [String], channel: String?) {
        guard !content.isEmpty else { return }
        broadcastText("MSG:\(content)")
    }

    func sendPrivateMessage(_ content: String, to peerID: String, recipientNickname: String, messageID: String?) {
        guard !content.isEmpty else { return }
        broadcastText("PM:\(peerID)|\(content)")
    }

    func sendEncryptedChannelMessage(_ content: String, mentions: [String], channel: String, channelKey: SymmetricKey, messageID: String?, timestamp: Date?) {
        guard let data = content.data(using: .utf8) else { return }
        if let sealed = try? AES.GCM.seal(data, using: channelKey),
           let combined = sealed.combined {
            let encoded = combined.base64EncodedString()
            broadcastText("ENC:\(channel)|\(encoded)")
        }
    }

    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: String) {
        guard let data = receipt.encode(), let json = String(data: data, encoding: .utf8) else { return }
        broadcastText("READ:\(peerID)|\(json)")
    }

    func sendChannelMetadata(_ metadata: ChannelMetadata) {
        guard let data = metadata.encode(), let json = String(data: data, encoding: .utf8) else { return }
        broadcastText("META:\(json)")
    }

    func sendChannelLeaveNotification(_ channel: String) {
        broadcastText("LEAVE:\(channel)")
    }

    func announcePasswordProtectedChannel(_ channel: String, creatorID: String?, keyCommitment: String?) {
        let creator = creatorID ?? myPeerID
        let commitment = keyCommitment ?? ""
        broadcastText("PROT:\(channel)|\(creator)|\(commitment)")
    }

    func sendChannelRetentionAnnouncement(_ channel: String, enabled: Bool) {
        broadcastText("RETN:\(channel)|\(enabled ? "1" : "0")")
    }

    func sendChannelPasswordUpdate(_ password: String, channel: String, newCommitment: String, to peerID: String) {
        broadcastText("PWD:\(channel)|\(newCommitment)")
    }

    func sendChannelKeyVerifyRequest(_ request: ChannelKeyVerifyRequest, to peers: [String]) {
        guard let data = request.encode(), let json = String(data: data, encoding: .utf8) else { return }
        broadcastText("VREQ:\(json)")
    }

    func sendChannelKeyVerifyResponse(_ response: ChannelKeyVerifyResponse, to peerID: String) {
        guard let data = response.encode(), let json = String(data: data, encoding: .utf8) else { return }
        broadcastText("VRES:\(json)")
    }

    func emergencyDisconnectAll() {
        watcher?.stop()
        publisher?.stop()
        watcher = nil
        publisher = nil
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
