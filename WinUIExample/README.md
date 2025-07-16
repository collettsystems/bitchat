# WinUI Example

This folder contains a minimal WinUI 3 front end that calls the Swift
`ChatViewModel` via P/Invoke.

Build steps:
1. Build the Swift library in `Release` mode on Windows:
   ```powershell
   swift build -c Release
   ```
   Copy the resulting `bitchat.dll` into this project's folder.
2. Open `WinUIExample.csproj` in Visual Studio and build.
