# WinUI Example

This folder contains a WinUI 3 client that calls the Swift
`ChatViewModel` via P/Invoke.  It exposes most of the features of the
iOS/macOS UI including channel chats, private messaging and nickname
management.  The window polls the Swift layer periodically to refresh
messages and connection status.

Build steps:
1. Build the Swift library in `Release` mode on Windows:
   ```powershell
   swift build -c Release
   ```
   Copy the resulting `bitchat.dll` into this project's folder.
2. Open `WinUIExample.csproj` in Visual Studio and build.

The application will present tabs for public chat, joined channels,
private chats and settings.  It relies entirely on the Swift
`ChatViewModel` for state management and networking.
