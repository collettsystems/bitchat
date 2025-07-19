#if os(Windows)
import Foundation

private var sharedViewModel: ChatViewModel?

@_cdecl("Bitchat_Initialize")
public func Bitchat_Initialize() {
    sharedViewModel = ChatViewModel()
}

@_cdecl("Bitchat_Shutdown")
public func Bitchat_Shutdown() {
    sharedViewModel?.applicationWillTerminate()
    sharedViewModel = nil
}

@_cdecl("Bitchat_SendMessage")
public func Bitchat_SendMessage(_ cString: UnsafePointer<CChar>) {
    guard let text = String(validatingUTF8: cString ?? "") else { return }
    sharedViewModel?.sendMessage(text)
}

@_cdecl("Bitchat_SetNickname")
public func Bitchat_SetNickname(_ cString: UnsafePointer<CChar>) {
    guard let text = String(validatingUTF8: cString ?? "") else { return }
    sharedViewModel?.nickname = text
}

@_cdecl("Bitchat_JoinChannel")
public func Bitchat_JoinChannel(_ cString: UnsafePointer<CChar>) {
    guard let name = String(validatingUTF8: cString ?? "") else { return }
    _ = sharedViewModel?.joinChannel(name)
}

@_cdecl("Bitchat_GetMessagesJSON")
public func Bitchat_GetMessagesJSON() -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel else { return nil }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(viewModel.messages) else { return nil }
    let jsonString = String(data: data, encoding: .utf8) ?? ""
    return strdup(jsonString)
}

@_cdecl("Bitchat_IsConnected")
public func Bitchat_IsConnected() -> Bool {
    return sharedViewModel?.isConnected ?? false
}

@_cdecl("Bitchat_FreeCString")
public func Bitchat_FreeCString(_ ptr: UnsafeMutablePointer<CChar>?) {
    if let ptr = ptr {
        free(ptr)
    }
}

// MARK: - Private Messaging

@_cdecl("Bitchat_SendPrivateMessage")
public func Bitchat_SendPrivateMessage(_ peerCString: UnsafePointer<CChar>, _ msgCString: UnsafePointer<CChar>) {
    guard let peerID = String(validatingUTF8: peerCString ?? ""),
          let text = String(validatingUTF8: msgCString ?? "") else { return }
    sharedViewModel?.sendPrivateMessage(text, to: peerID)
}

@_cdecl("Bitchat_StartPrivateChat")
public func Bitchat_StartPrivateChat(_ peerCString: UnsafePointer<CChar>) {
    guard let peerID = String(validatingUTF8: peerCString ?? "") else { return }
    sharedViewModel?.startPrivateChat(with: peerID)
}

@_cdecl("Bitchat_EndPrivateChat")
public func Bitchat_EndPrivateChat() {
    sharedViewModel?.endPrivateChat()
}

@_cdecl("Bitchat_GetPrivateMessagesJSON")
public func Bitchat_GetPrivateMessagesJSON(_ peerCString: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel,
          let peerID = String(validatingUTF8: peerCString ?? "") else { return nil }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let messages = viewModel.getPrivateChatMessages(for: peerID)
    guard let data = try? encoder.encode(messages) else { return nil }
    let json = String(data: data, encoding: .utf8) ?? ""
    return strdup(json)
}

// MARK: - Channel Management

@_cdecl("Bitchat_LeaveChannel")
public func Bitchat_LeaveChannel(_ cString: UnsafePointer<CChar>) {
    guard let name = String(validatingUTF8: cString ?? "") else { return }
    sharedViewModel?.leaveChannel(name)
}

@_cdecl("Bitchat_SwitchChannel")
public func Bitchat_SwitchChannel(_ cString: UnsafePointer<CChar>) {
    guard let name = String(validatingUTF8: cString ?? "") else {
        sharedViewModel?.switchToChannel(nil)
        return
    }
    if name.isEmpty {
        sharedViewModel?.switchToChannel(nil)
    } else {
        sharedViewModel?.switchToChannel(name)
    }
}

@_cdecl("Bitchat_SetChannelPassword")
public func Bitchat_SetChannelPassword(_ channelCString: UnsafePointer<CChar>, _ passCString: UnsafePointer<CChar>) {
    guard let channel = String(validatingUTF8: channelCString ?? ""),
          let password = String(validatingUTF8: passCString ?? "") else { return }
    sharedViewModel?.setChannelPassword(password, for: channel)
}

@_cdecl("Bitchat_RemoveChannelPassword")
public func Bitchat_RemoveChannelPassword(_ channelCString: UnsafePointer<CChar>) {
    guard let channel = String(validatingUTF8: channelCString ?? "") else { return }
    sharedViewModel?.removeChannelPassword(for: channel)
}

@_cdecl("Bitchat_GetChannelMessagesJSON")
public func Bitchat_GetChannelMessagesJSON(_ channelCString: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel,
          let channel = String(validatingUTF8: channelCString ?? "") else { return nil }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let messages = viewModel.getChannelMessages(channel)
    guard let data = try? encoder.encode(messages) else { return nil }
    let json = String(data: data, encoding: .utf8) ?? ""
    return strdup(json)
}

// MARK: - Peer Queries

@_cdecl("Bitchat_GetConnectedPeersJSON")
public func Bitchat_GetConnectedPeersJSON() -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel else { return nil }
    let peers = viewModel.connectedPeers
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(peers) else { return nil }
    let json = String(data: data, encoding: .utf8) ?? ""
    return strdup(json)
}

@_cdecl("Bitchat_GetPeerNicknamesJSON")
public func Bitchat_GetPeerNicknamesJSON() -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel else { return nil }
    let names = viewModel.meshService.getPeerNicknames()
    guard let data = try? JSONSerialization.data(withJSONObject: names, options: []) else { return nil }
    let json = String(data: data, encoding: .utf8) ?? ""
    return strdup(json)
}

// MARK: - Encryption Utilities

@_cdecl("Bitchat_GetFingerprint")
public func Bitchat_GetFingerprint(_ peerCString: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel,
          let peerID = String(validatingUTF8: peerCString ?? "") else { return nil }
    if let fingerprint = viewModel.getFingerprint(for: peerID) {
        return strdup(fingerprint)
    }
    return nil
}

@_cdecl("Bitchat_GetMyFingerprint")
public func Bitchat_GetMyFingerprint() -> UnsafeMutablePointer<CChar>? {
    guard let viewModel = sharedViewModel else { return nil }
    let fp = viewModel.getMyFingerprint()
    return strdup(fp)
}

@_cdecl("Bitchat_VerifyFingerprint")
public func Bitchat_VerifyFingerprint(_ peerCString: UnsafePointer<CChar>) {
    guard let peerID = String(validatingUTF8: peerCString ?? "") else { return }
    sharedViewModel?.verifyFingerprint(for: peerID)
}

@_cdecl("Bitchat_GetEncryptionStatus")
public func Bitchat_GetEncryptionStatus(_ peerCString: UnsafePointer<CChar>) -> Int32 {
    guard let viewModel = sharedViewModel,
          let peerID = String(validatingUTF8: peerCString ?? "") else { return 0 }
    let status = viewModel.getEncryptionStatus(for: peerID)
    switch status {
    case .noiseVerified:
        return 3
    case .noiseSecured:
        return 2
    case .noiseHandshaking:
        return 1
    case .none:
        return 0
    }
}
#endif
