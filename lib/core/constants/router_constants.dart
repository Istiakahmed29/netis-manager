/// Core constants for the NETIS WF2409E web interface.
///
/// These values were derived by inspecting the router's HTTP traffic
/// in a browser (Chrome DevTools → Network tab) while navigating the
/// stock firmware admin panel at http://192.168.1.1
///
/// The NETIS WF2409E has NO official REST API. The app works by
/// replaying the same HTTP requests that the browser sends — form POSTs
/// with session cookies. If NETIS updates its firmware and changes these
/// paths, update this file only.

// ignore_for_file: constant_identifier_names

class RouterConstants {
  RouterConstants._();

  // ---------------------------------------------------------------------------
  // Candidate gateway IPs tried during auto-discovery
  // ---------------------------------------------------------------------------
  static const List<String> candidateIPs = [
    '192.168.1.1',
    '192.168.0.1',
    '10.0.0.1',
    '192.168.2.1',
  ];

  static const Duration discoveryTimeout = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 10);

  // ---------------------------------------------------------------------------
  // NETIS WF2409E web interface paths
  //
  // Source: captured from stock firmware v2.x via browser devtools.
  // The router uses a simple CGI + session-cookie auth model.
  // ---------------------------------------------------------------------------

  /// Root page — redirects to login if session invalid
  static const String pathRoot = '/';

  /// Login POST endpoint
  /// Form fields: username, password, (optional) rememberme
  static const String pathLogin = '/cgi-bin/login.asp';

  /// Alternative login path seen on some firmware revisions
  static const String pathLoginAlt = '/login.asp';

  /// Main status page — scrape for WAN/LAN info
  static const String pathStatus = '/cgi-bin/status.asp';

  /// DHCP client list — primary source of connected device list
  /// Returns an HTML table with: hostname, IP, MAC, lease time
  static const String pathDhcpClients = '/cgi-bin/dhcpclients.asp';

  /// Wireless station list — shows devices currently associated
  /// Returns MAC + signal; merged with DHCP list for full device picture
  static const String pathWirelessClients = '/cgi-bin/wirelessclients.asp';

  /// MAC filter configuration page
  /// Used to read current block list and to add/remove entries
  static const String pathMacFilter = '/cgi-bin/macfilter.asp';

  /// MAC filter POST action endpoint
  static const String pathMacFilterAction = '/cgi-bin/macfilter.asp';

  // ---------------------------------------------------------------------------
  // Known form field names (firmware v2.x)
  // ---------------------------------------------------------------------------
  static const String fieldUsername = 'username';
  static const String fieldPassword = 'password';

  /// MAC filter mode values POSTed to the router
  static const String macFilterModeDisable = '0'; // no filtering
  static const String macFilterModeBlacklist = '1'; // block listed MACs
  static const String macFilterModeWhitelist = '2'; // allow listed only

  // ---------------------------------------------------------------------------
  // Storage keys
  // ---------------------------------------------------------------------------
  static const String storageKeyUsername = 'router_username';
  static const String storageKeyPassword = 'router_password';
  static const String storageKeyRouterIP = 'router_ip';
}
