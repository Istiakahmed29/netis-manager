import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/errors/app_error.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/router_info.dart';

/// Parses HTML pages returned by the NETIS WF2409E web interface.
///
/// ─── Why HTML scraping? ───────────────────────────────────────────────────
/// The NETIS WF2409E runs a basic embedded HTTP server that serves static
/// HTML pages with no JSON API. Every "action" (login, block device) is a
/// browser form POST. Reading data means parsing the returned HTML table.
///
/// ─── Firmware notes ───────────────────────────────────────────────────────
/// Tested against stock firmware v2.1.36xxx. If your firmware version
/// returns different HTML structure, the parse methods will throw [ParseError]
/// with details — that's your signal to inspect the actual HTML and update
/// the selectors below.
///
/// To inspect the HTML:
///   1. Connect to router Wi-Fi.
///   2. Open http://192.168.1.1 in Chrome.
///   3. Log in with admin credentials.
///   4. Open DevTools → Network → navigate to the DHCP client list page.
///   5. Click the response → Copy → Copy response.
///   6. Compare table structure to the selectors used here.
class NetisHtmlParser {
  const NetisHtmlParser();

  // ---------------------------------------------------------------------------
  // Login result detection
  // ---------------------------------------------------------------------------

  /// Returns true if the response HTML indicates a successful login.
  ///
  /// The NETIS firmware redirects to the main status page on success.
  /// On failure it re-renders the login form (often with an error div).
  bool isLoginSuccessful(String html) {
    // Successful login: page does NOT contain the login form username field.
    // Failed login: the login form is still present.
    final doc = html_parser.parse(html);
    final hasLoginForm =
        doc.querySelector('input[name="username"]') != null ||
        doc.querySelector('input[name="user"]') != null ||
        doc.querySelector('form[action*="login"]') != null;

    final hasErrorMsg =
        html.toLowerCase().contains('invalid') ||
        html.toLowerCase().contains('incorrect') ||
        html.toLowerCase().contains('wrong password') ||
        html.toLowerCase().contains('login failed');

    appLogger.d('[Parser] isLoginSuccessful: '
        'hasLoginForm=$hasLoginForm, hasErrorMsg=$hasErrorMsg');

    return !hasLoginForm && !hasErrorMsg;
  }

  // ---------------------------------------------------------------------------
  // DHCP client list
  // ---------------------------------------------------------------------------

  /// Parses the DHCP client list page into a list of [Device]s.
  ///
  /// The NETIS DHCP table typically looks like:
  /// ```html
  /// <table>
  ///   <tr><th>Host Name</th><th>IP Address</th><th>MAC Address</th><th>Expires</th></tr>
  ///   <tr><td>android-abc</td><td>192.168.1.100</td><td>AA:BB:CC:DD:EE:FF</td><td>23:59:59</td></tr>
  /// </table>
  /// ```
  List<Device> parseDhcpClients(String html) {
    final doc = html_parser.parse(html);
    final devices = <Device>[];

    // Find all tables and look for one that has IP/MAC columns.
    final tables = doc.querySelectorAll('table');
    if (tables.isEmpty) {
      appLogger.w('[Parser] No tables found in DHCP page');
      return devices;
    }

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue; // need at least header + 1 data row

      // Determine column indices from header row
      final headers = rows.first
          .querySelectorAll('th, td')
          .map((e) => e.text.trim().toLowerCase())
          .toList();

      final hostnameIdx = _findColumn(headers, ['host', 'hostname', 'name', 'client']);
      final ipIdx = _findColumn(headers, ['ip', 'address', 'ip address']);
      final macIdx = _findColumn(headers, ['mac', 'mac address', 'physical']);

      // If this table doesn't look like a DHCP table, skip it
      if (ipIdx == -1 || macIdx == -1) continue;

      appLogger.d('[Parser] DHCP table found. '
          'hostname=$hostnameIdx ip=$ipIdx mac=$macIdx');

      // Parse data rows (skip header)
      for (final row in rows.skip(1)) {
        final cells = row.querySelectorAll('td');
        if (cells.length <= macIdx) continue;

        final ip = cells[ipIdx].text.trim();
        final mac = _normalizeMac(cells[macIdx].text.trim());
        final hostname = hostnameIdx >= 0 && cells.length > hostnameIdx
            ? cells[hostnameIdx].text.trim()
            : null;

        if (ip.isEmpty || mac.isEmpty) continue;
        if (!_isValidIp(ip) || !_isValidMac(mac)) continue;

        devices.add(Device(
          mac: mac,
          ip: ip,
          hostname: hostname?.isEmpty == true ? null : hostname,
        ));
      }

      if (devices.isNotEmpty) break; // found the right table
    }

    appLogger.i('[Parser] Parsed ${devices.length} DHCP clients');
    return devices;
  }

  // ---------------------------------------------------------------------------
  // MAC filter (block) list
  // ---------------------------------------------------------------------------

  /// Parses the MAC filter page and returns all currently-blocked MAC addresses.
  ///
  /// The NETIS MAC filter page shows the filter mode and a table of filtered MACs.
  Set<String> parseBlockedMacs(String html) {
    final doc = html_parser.parse(html);
    final blocked = <String>{};

    // Look for MAC addresses in any table on the page
    final tables = doc.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        for (final cell in cells) {
          final text = cell.text.trim();
          if (_isValidMac(text)) {
            blocked.add(_normalizeMac(text));
          }
        }
      }
    }

    // Also scan for MAC-like patterns in the raw HTML (some firmwares
    // embed the block list in JavaScript variables rather than a table)
    final macPattern = RegExp(
      r'([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}',
    );
    for (final match in macPattern.allMatches(html)) {
      final mac = _normalizeMac(match.group(0)!);
      // Only add if it appears in a context suggesting it's a filter entry
      final context = html.substring(
        (match.start - 50).clamp(0, html.length),
        (match.end + 50).clamp(0, html.length),
      );
      if (context.toLowerCase().contains('filter') ||
          context.toLowerCase().contains('block') ||
          context.toLowerCase().contains('deny')) {
        blocked.add(mac);
      }
    }

    appLogger.i('[Parser] Found ${blocked.length} blocked MACs: $blocked');
    return blocked;
  }

  /// Extracts hidden form fields from a page (CSRF tokens, session vars, etc.)
  /// Returns a map of field name → value for all hidden inputs.
  Map<String, String> parseHiddenFields(String html) {
    final doc = html_parser.parse(html);
    final fields = <String, String>{};

    for (final input in doc.querySelectorAll('input[type="hidden"]')) {
      final name = input.attributes['name'];
      final value = input.attributes['value'] ?? '';
      if (name != null && name.isNotEmpty) {
        fields[name] = value;
      }
    }

    appLogger.d('[Parser] Hidden fields: $fields');
    return fields;
  }

  // ---------------------------------------------------------------------------
  // Router info
  // ---------------------------------------------------------------------------

  /// Parses the router status page for basic info.
  RouterInfo parseRouterInfo(String html, String routerIp) {
    final doc = html_parser.parse(html);

    String? extract(List<String> keywords) {
      // Try to find a table cell whose adjacent label cell contains a keyword
      for (final row in doc.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 2) {
          final label = cells[0].text.trim().toLowerCase();
          if (keywords.any((k) => label.contains(k))) {
            return cells[1].text.trim();
          }
        }
      }
      return null;
    }

    return RouterInfo(
      ipAddress: routerIp,
      firmwareVersion: extract(['firmware', 'version', 'fw']),
      macAddress: extract(['mac', 'wan mac']),
      wanIp: extract(['wan ip', 'ip address', 'internet ip']),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int _findColumn(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      if (keywords.any((k) => headers[i].contains(k))) return i;
    }
    return -1;
  }

  String _normalizeMac(String raw) {
    // Normalize to uppercase colon-separated format: AA:BB:CC:DD:EE:FF
    return raw
        .toUpperCase()
        .replaceAll('-', ':')
        .replaceAll(' ', '');
  }

  bool _isValidMac(String s) {
    return RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$').hasMatch(s);
  }

  bool _isValidIp(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }
}
