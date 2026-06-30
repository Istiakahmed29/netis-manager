/// Basic router information shown on the home screen.
class RouterInfo {
  const RouterInfo({
    required this.ipAddress,
    this.firmwareVersion,
    this.macAddress,
    this.wanIp,
  });

  final String ipAddress;
  final String? firmwareVersion;
  final String? macAddress;
  final String? wanIp;
}
