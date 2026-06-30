import 'package:flutter_test/flutter_test.dart';
import 'package:netis_manager/data/datasources/netis_html_parser.dart';

void main() {
  const parser = NetisHtmlParser();

  // ---------------------------------------------------------------------------
  // Login detection
  // ---------------------------------------------------------------------------
  group('isLoginSuccessful', () {
    test('returns true when no login form present', () {
      const html = '''
        <html><body>
          <h1>Status</h1>
          <p>Welcome, admin</p>
        </body></html>
      ''';
      expect(parser.isLoginSuccessful(html), isTrue);
    });

    test('returns false when login form is present', () {
      const html = '''
        <html><body>
          <form action="/login.asp">
            <input type="text" name="username" />
            <input type="password" name="password" />
          </form>
        </body></html>
      ''';
      expect(parser.isLoginSuccessful(html), isFalse);
    });

    test('returns false when error text present', () {
      const html = '''
        <html><body>
          <p>Invalid username or password.</p>
        </body></html>
      ''';
      expect(parser.isLoginSuccessful(html), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // DHCP client parsing
  // ---------------------------------------------------------------------------
  group('parseDhcpClients', () {
    test('parses standard NETIS DHCP table', () {
      const html = '''
        <html><body>
          <table>
            <tr>
              <th>Host Name</th>
              <th>IP Address</th>
              <th>MAC Address</th>
              <th>Expires</th>
            </tr>
            <tr>
              <td>android-phone</td>
              <td>192.168.1.100</td>
              <td>AA:BB:CC:DD:EE:FF</td>
              <td>23:59:59</td>
            </tr>
            <tr>
              <td>laptop</td>
              <td>192.168.1.101</td>
              <td>11:22:33:44:55:66</td>
              <td>23:59:59</td>
            </tr>
          </table>
        </body></html>
      ''';

      final devices = parser.parseDhcpClients(html);
      expect(devices.length, equals(2));

      expect(devices[0].hostname, equals('android-phone'));
      expect(devices[0].ip, equals('192.168.1.100'));
      expect(devices[0].mac, equals('AA:BB:CC:DD:EE:FF'));

      expect(devices[1].hostname, equals('laptop'));
      expect(devices[1].ip, equals('192.168.1.101'));
    });

    test('normalizes MAC from hyphen to colon format', () {
      const html = '''
        <html><body>
          <table>
            <tr><th>Host Name</th><th>IP Address</th><th>MAC Address</th></tr>
            <tr><td>device</td><td>192.168.1.100</td><td>AA-BB-CC-DD-EE-FF</td></tr>
          </table>
        </body></html>
      ''';

      final devices = parser.parseDhcpClients(html);
      expect(devices.first.mac, equals('AA:BB:CC:DD:EE:FF'));
    });

    test('skips rows with invalid IP or MAC', () {
      const html = '''
        <html><body>
          <table>
            <tr><th>Host Name</th><th>IP Address</th><th>MAC Address</th></tr>
            <tr><td>bad</td><td>not-an-ip</td><td>AA:BB:CC:DD:EE:FF</td></tr>
            <tr><td>good</td><td>192.168.1.100</td><td>AA:BB:CC:DD:EE:FF</td></tr>
          </table>
        </body></html>
      ''';

      final devices = parser.parseDhcpClients(html);
      expect(devices.length, equals(1));
      expect(devices.first.ip, equals('192.168.1.100'));
    });

    test('returns empty list when no suitable table found', () {
      const html = '<html><body><p>No devices</p></body></html>';
      final devices = parser.parseDhcpClients(html);
      expect(devices, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // MAC filter parsing
  // ---------------------------------------------------------------------------
  group('parseBlockedMacs', () {
    test('parses MACs from filter table', () {
      const html = '''
        <html><body>
          <table>
            <tr><th>MAC</th><th>Action</th></tr>
            <tr><td>AA:BB:CC:DD:EE:FF</td><td>Delete</td></tr>
            <tr><td>11:22:33:44:55:66</td><td>Delete</td></tr>
          </table>
        </body></html>
      ''';

      final macs = parser.parseBlockedMacs(html);
      expect(macs.contains('AA:BB:CC:DD:EE:FF'), isTrue);
      expect(macs.contains('11:22:33:44:55:66'), isTrue);
    });

    test('finds MACs in JavaScript filter context', () {
      const html = '''
        <html><body>
          <script>
            var filter_list = "block AA:BB:CC:DD:EE:FF";
          </script>
        </body></html>
      ''';

      final macs = parser.parseBlockedMacs(html);
      expect(macs.contains('AA:BB:CC:DD:EE:FF'), isTrue);
    });

    test('returns empty set when no MACs found', () {
      const html = '<html><body><p>No filters</p></body></html>';
      final macs = parser.parseBlockedMacs(html);
      expect(macs, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Hidden fields
  // ---------------------------------------------------------------------------
  group('parseHiddenFields', () {
    test('extracts hidden input fields', () {
      const html = '''
        <form>
          <input type="hidden" name="token" value="abc123" />
          <input type="hidden" name="session" value="xyz" />
          <input type="text" name="username" />
        </form>
      ''';

      final fields = parser.parseHiddenFields(html);
      expect(fields['token'], equals('abc123'));
      expect(fields['session'], equals('xyz'));
      expect(fields.containsKey('username'), isFalse);
    });

    test('returns empty map when no hidden fields', () {
      const html = '<form><input type="text" name="user" /></form>';
      final fields = parser.parseHiddenFields(html);
      expect(fields, isEmpty);
    });
  });
}
