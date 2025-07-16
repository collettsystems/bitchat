# BitChat Windows Port

This document outlines the approach for bringing BitChat to Windows using WinUI 3.

## Overview

BitChat's core logic is written in Swift and kept platform agnostic. On Windows
the UI can be implemented with C# and WinUI while the existing Swift code is
compiled as a static library. The thin Swift layer exposes C-callable functions
that the C# front‑end can invoke via P/Invoke.

## Steps

1. **Install the Swift toolchain for Windows.**
   Download it from [swift.org](https://www.swift.org/download/#releases).
2. **Build the Swift library.**
   ```powershell
   swift build -c Release
   ```
   This produces `.lib` and `.dll` files under `.build/` which expose the core
   logic including `ChatViewModel`.
3. **Create a WinUI 3 app in Visual Studio.**
   Add the generated Swift library to the project and declare the required
   `DllImport` signatures to call into Swift.
4. **Recreate application startup.**
   Implement a C# `App` class and `MainWindow` that instantiate `ChatViewModel`
   and wire up lifecycle events analogous to `BitchatApp` on Apple platforms.
5. **Notifications.**
   Use the Windows `ToastNotification` APIs to mirror `NotificationService`.

The existing view models remain in Swift with minimal conditional code. Only the
UI layer is rewritten for Windows.
