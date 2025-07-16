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
#endif
