import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../../core/constants/router_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/router_info.dart';
import 'netis_html_parser.dart';

/// Low-level HTTP client for the NETIS WF2409E web interface.
///
/// ─── How the NETIS firmware handles sessions ──────────────────────────────
/// 1. POST to /cgi-bin/login.asp with username + password form fields.
/// 2. On success the server sets a session cookie (typically "session_id"
///    or "SESSIONID"). All subsequent requests must include this cookie.
/// 3. The session expires after ~5 minutes of inactivity, at which point
///    the router redirects any request back to the login page.
///
/// ─── MAC filtering / blocking ─────────────────────────────────────────────
/// The NETIS WF2409E supports MAC-based filtering. There are two modes:
///   • Blacklist (mode=1): listed MACs are blocked, all others pass.
///   • Whitelist (mode=2): only listed MACs are allowed.
///
/// The app always operates in blacklist mode. When you block a device its
/// MAC is added to the list. When you unblock, it is removed.
///
/// ─── Limitations ──────────────────────────────────────────────────────────
/// • No per-device bandwidth limiting (firmware doesn't support it).
/// • DHCP client list only shows leased clients, not all-time history.
/// • Wireless client list (signal strength) is on a separate page.
/// • If the router returns unexpected HTML, [ParseError] is thrown.
///   Open the URL in a browser, inspect the HTML, and update
///   [NetisHtmlParser] if needed.
class RouterRemoteDataSource {
  RouterRemoteDataSource() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        connectTimeout: RouterConstants.requestTimeout,
        receiveTimeout: RouterConstants.requestTimeout,
        followRedirects: true,
        maxRedirects: 3,
        // The router returns text/html — tell Dio not to auto-decode JSON
        responseType: ResponseType.plain,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(_loggingInterceptor());
  }

  late final Dio _dio;
  late final CookieJar _cookieJar;
  final _parser = const NetisHtmlParser();

  String? _currentBaseUrl;

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Tries each candidate IP and returns the first that answers as a router.
  Future<String?> discoverRouter() async {
    for (final ip in RouterConstants.candidateIPs) {
      final url = 'http://$ip';
      try {
        appLogger.d('[Discovery] Trying $url');
        final response = await _dio.get(
          url,
          options: Options(
            receiveTimeout: RouterConstants.discoveryTimeout,
            connectTimeout: RouterConstants.discoveryTimeout,
          ),
        );
        // Accept any 2xx or redirect response — the router is there
        if (response.statusCode != null &&
            (response.statusCode! < 400)) {
          appLogger.i('[Discovery] Found router at $ip');
          _currentBaseUrl = url;
          return ip;
        }
      } on DioException catch (e) {
        appLogger.d('[Discovery] $ip → ${e.type}');
        // continue to next IP
      } catch (e) {
        appLogger.d('[Discovery] $ip → $e');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Authenticates with the router.
  /// Throws [AuthenticationError] if credentials are wrong.
  /// Throws [RouterConnectionError] on network problems.
  Future<void> login({
    required String routerIp,
    required String username,
    required String password,
  }) async {
    _currentBaseUrl = 'http://$routerIp';
    await _cookieJar.deleteAll(); // clear any stale session

    // Try primary login path first, fall back to alternative
    final loginPaths = [
      RouterConstants.pathLogin,
      RouterConstants.pathLoginAlt,
    ];

    // Fetch the login page first to pick up any hidden fields / tokens
    String? loginHtml;
    String? workingPath;

    for (final path in loginPaths) {
      try {
        final res = await _get(path);
        if (res != null) {
          loginHtml = res;
          workingPath = path;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    if (workingPath == null) {
      throw const RouterConnectionError('Could not reach login page');
    }

    // Collect any hidden form fields (CSRF tokens, etc.)
    final hiddenFields = loginHtml != null
        ? _parser.parseHiddenFields(loginHtml)
        : <String, String>{};

    // Build POST body — hidden fields first, then credentials
    final formData = {
      ...hiddenFields,
      RouterConstants.fieldUsername: username,
      RouterConstants.fieldPassword: password,
    };

    appLogger.d('[Auth] POSTing to $workingPath with fields: '
        '${formData.keys.toList()}');

    try {
      final response = await _dio.post(
        '$_currentBaseUrl$workingPath',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: true,
          maxRedirects: 3,
        ),
      );

      final body = response.data as String? ?? '';

      if (!_parser.isLoginSuccessful(body)) {
        await _cookieJar.deleteAll();
        throw const AuthenticationError();
      }

      appLogger.i('[Auth] Login successful');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Future<void> logout() async {
    await _cookieJar.deleteAll();
    _currentBaseUrl = null;
    appLogger.i('[Auth] Logged out, session cleared');
  }

  // ---------------------------------------------------------------------------
  // Device list
  // ---------------------------------------------------------------------------

  /// Fetches DHCP client list and MAC filter list, merges them.
  Future<List<Device>> getConnectedDevices() async {
    _assertLoggedIn();

    // 1. Get DHCP lease table (all known devices)
    final dhcpHtml = await _get(RouterConstants.pathDhcpClients);
    if (dhcpHtml == null) {
      throw const ParseError('DHCP client page returned empty response');
    }

    final devices = _parser.parseDhcpClients(dhcpHtml);

    // 2. Get MAC filter list to know which devices are blocked
    Set<String> blockedMacs = {};
    try {
      final filterHtml = await _get(RouterConstants.pathMacFilter);
      if (filterHtml != null) {
        blockedMacs = _parser.parseBlockedMacs(filterHtml);
      }
    } catch (e) {
      // MAC filter page unavailable — treat all as unblocked
      appLogger.w('[Devices] Could not fetch MAC filter list: $e');
    }

    // 3. Merge: mark devices that are in the block list
    return devices.map((d) {
      return d.copyWith(isBlocked: blockedMacs.contains(d.mac));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Block / Unblock
  // ---------------------------------------------------------------------------

  /// Adds [mac] to the blacklist on the router.
  Future<void> blockDevice(String mac) async {
    _assertLoggedIn();
    appLogger.i('[Block] Blocking $mac');

    // Fetch the current MAC filter page to get hidden fields + existing list
    final filterHtml = await _get(RouterConstants.pathMacFilter);
    if (filterHtml == null) {
      throw const ParseError('MAC filter page unavailable');
    }

    final hiddenFields = _parser.parseHiddenFields(filterHtml);
    final currentBlocked = _parser.parseBlockedMacs(filterHtml);

    if (currentBlocked.contains(mac)) {
      appLogger.i('[Block] $mac already blocked');
      return; // nothing to do
    }

    // Build the new block list including this MAC
    final newList = {...currentBlocked, mac};

    await _submitMacFilterList(
      hiddenFields: hiddenFields,
      macs: newList,
      mode: RouterConstants.macFilterModeBlacklist,
    );
  }

  /// Removes [mac] from the blacklist on the router.
  Future<void> unblockDevice(String mac) async {
    _assertLoggedIn();
    appLogger.i('[Block] Unblocking $mac');

    final filterHtml = await _get(RouterConstants.pathMacFilter);
    if (filterHtml == null) {
      throw const ParseError('MAC filter page unavailable');
    }

    final hiddenFields = _parser.parseHiddenFields(filterHtml);
    final currentBlocked = _parser.parseBlockedMacs(filterHtml);

    if (!currentBlocked.contains(mac)) {
      appLogger.i('[Block] $mac not in block list');
      return; // nothing to do
    }

    final newList = currentBlocked.difference({mac});

    // If the list is now empty, disable filter mode entirely
    final mode = newList.isEmpty
        ? RouterConstants.macFilterModeDisable
        : RouterConstants.macFilterModeBlacklist;

    await _submitMacFilterList(
      hiddenFields: hiddenFields,
      macs: newList,
      mode: mode,
    );
  }

  // ---------------------------------------------------------------------------
  // Router info
  // ---------------------------------------------------------------------------

  Future<RouterInfo> getRouterInfo() async {
    _assertLoggedIn();
    final html = await _get(RouterConstants.pathStatus);
    if (html == null) {
      throw const ParseError('Status page returned empty response');
    }
    return _parser.parseRouterInfo(html, _currentBaseUrl!.replaceAll('http://', ''));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// GETs a path and returns the response body string, or null on error.
  Future<String?> _get(String path) async {
    try {
      final response = await _dio.get('$_currentBaseUrl$path');
      final body = response.data as String?;

      // Check if we got redirected to login (session expired)
      if (body != null && _parser.parseHiddenFields(body).containsKey(RouterConstants.fieldUsername)) {
        throw const SessionExpiredError();
      }

      return body;
    } on SessionExpiredError {
      rethrow;
    } on DioException catch (e) {
      _handleDioError(e);
    }
    return null;
  }

  /// Submits the MAC filter form with the given MAC set and mode.
  ///
  /// The exact form field names vary slightly between firmware versions.
  /// The most common pattern on the WF2409E is a repeating set of fields:
  ///   mac_addr_1, mac_addr_2, … for each MAC address
  ///   filter_mode = 0|1|2
  ///
  /// If this doesn't work for your firmware, fetch the filter page in a
  /// browser, inspect the form's action + field names in DevTools, and
  /// update the field names below.
  Future<void> _submitMacFilterList({
    required Map<String, String> hiddenFields,
    required Set<String> macs,
    required String mode,
  }) async {
    final formData = <String, String>{
      ...hiddenFields,
      'filter_mode': mode,
      'mac_filter_enable': mode != RouterConstants.macFilterModeDisable ? '1' : '0',
    };

    // Add each MAC as a numbered field
    int index = 1;
    for (final mac in macs) {
      formData['mac_addr_$index'] = mac;
      formData['mac_$index'] = mac; // alternate field name used on some versions
      index++;
    }

    appLogger.d('[MACFilter] Submitting: $formData');

    try {
      await _dio.post(
        '$_currentBaseUrl${RouterConstants.pathMacFilterAction}',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: true,
        ),
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  void _assertLoggedIn() {
    if (_currentBaseUrl == null) {
      throw const SessionExpiredError();
    }
  }

  Never _handleDioError(DioException e) {
    appLogger.e('[HTTP] ${e.type}: ${e.message}');
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw RouterConnectionError('Request timed out (${e.type.name})');
      case DioExceptionType.connectionError:
        throw RouterConnectionError(e.message ?? 'Connection failed');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) throw const AuthenticationError();
        throw RouterConnectionError('HTTP $status');
      default:
        throw RouterConnectionError(e.message ?? 'Unknown error');
    }
  }

  Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        appLogger.d('[HTTP →] ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        appLogger.d('[HTTP ←] ${response.statusCode} '
            '${response.realUri.path} '
            '(${(response.data as String?)?.length ?? 0} chars)');
        handler.next(response);
      },
      onError: (error, handler) {
        appLogger.e('[HTTP ✗] ${error.type}: ${error.message}');
        handler.next(error);
      },
    );
  }
}
