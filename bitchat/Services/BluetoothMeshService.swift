#if os(Windows)
public typealias BluetoothMeshService = WindowsBluetoothMeshService
#else
public typealias BluetoothMeshService = AppleBluetoothMeshService
#endif
