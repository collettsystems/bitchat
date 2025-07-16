import Foundation

protocol MeshServiceProtocol: AnyObject {
    var delegate: BitchatDelegate? { get set }
    var myPeerID: String { get }
    func startServices()
    func sendBroadcastAnnounce()
    func sendMessage(_ content: String, mentions: [String], channel: String?)
    func sendPrivateMessage(_ content: String, to peerID: String, recipientNickname: String, messageID: String?)
    func sendEncryptedChannelMessage(_ content: String, mentions: [String], channel: String, channelKey: SymmetricKey, messageID: String?, timestamp: Date?)
    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: String)
    func sendChannelMetadata(_ metadata: ChannelMetadata)
    func sendChannelLeaveNotification(_ channel: String)
    func announcePasswordProtectedChannel(_ channel: String, creatorID: String?, keyCommitment: String?)
    func sendChannelRetentionAnnouncement(_ channel: String, enabled: Bool)
    func sendChannelPasswordUpdate(_ password: String, channel: String, newCommitment: String, to peerID: String)
    func sendChannelKeyVerifyRequest(_ request: ChannelKeyVerifyRequest, to peers: [String])
    func sendChannelKeyVerifyResponse(_ response: ChannelKeyVerifyResponse, to peerID: String)
    func emergencyDisconnectAll()
    func getNoiseService() -> NoiseEncryptionService
    func getPeerFingerprint(_ peerID: String) -> String?
    func getPeerNicknames() -> [String: String]
    func getPeerRSSI() -> [String: NSNumber]
    func getFingerprint(for peerID: String) -> String?
}
