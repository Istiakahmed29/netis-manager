# NETIS Manager

A focused Flutter app for Android that lets you **instantly block and unblock
devices** connected to your NETIS WF2409E router — without ever opening the
router's web interface.

---

## What this app actually does

| Feature | Status | Notes |
|---------|--------|-------|
| Auto-discover router on local Wi-Fi | ✅ | Tries 192.168.1.1 and 192.168.0.1 |
| Login with admin credentials | ✅ | Session cookie kept in memory |
| Save login securely | ✅ | Android Keystore (AES-256) |
| List connected devices | ✅ | Scrapes DHCP client table |
| Show hostname / IP / MAC | ✅ | |
| Block a device | ✅ | Adds MAC to router's blacklist |
| Unblock a device | ✅ | Removes MAC from blacklist |
| Search devices | ✅ | By name, IP, or MAC |
| Dark Material 3 UI | ✅ | |
| Per-device speed limiting | ❌ | Not supported by WF2409E firmware |
| Real-time bandwidth graphs | ❌ | Firmware exposes no such data |
| QoS / priority | ❌ | Not in stock firmware |

---

## How it works (no official API)

The NETIS WF2409E has **no JSON API**. Its admin panel is a set of HTML pages
served by a basic embedded HTTP server. The app works by replaying exactly the
same HTTP requests a browser would send:

```
App                        Router (192.168.1.1)
 │                               │
 │── POST /cgi-bin/login.asp ───►│  (username + password form fields)
 │◄── 200 OK + Set-Cookie ───────│  (session cookie stored by app)
 │                               │
 │── GET /cgi-bin/dhcpclients.asp►│ (with session cookie)
 │◄── HTML table of devices ─────│
 │                               │
 │── GET /cgi-bin/macfilter.asp ─►│
 │◄── HTML with blocked MACs ────│
 │                               │
 │── POST /cgi-bin/macfilter.asp ►│ (updated MAC list to block/unblock)
 │◄── 200 OK ────────────────────│
```

The HTML is parsed by `NetisHtmlParser` which finds tables by their column
headers rather than hard-coded CSS selectors, making it resilient to minor
layout changes.

---

## Project structure

```
lib/
├── core/
│   ├── constants/router_constants.dart   # All router URLs and field names
│   ├── errors/app_error.dart             # Typed exception hierarchy
│   └── utils/
│       ├── result.dart                   # Result<T> monad
│       └── logger.dart                   # App-wide logger
│
├── data/
│   ├── datasources/
│   │   ├── router_remote_datasource.dart # HTTP layer (Dio + cookies)
│   │   ├── netis_html_parser.dart        # HTML scraper / parser
│   │   └── credential_storage.dart       # Secure storage (Keystore)
│   └── repositories/
│       └── router_repository_impl.dart   # Wires datasources → domain
│
├── domain/
│   ├── entities/
│   │   ├── device.dart                   # Device model
│   │   └── router_info.dart              # Router info model
│   └── repositories/
│       └── router_repository.dart        # Abstract interface
│
└── presentation/
    ├── providers/
    │   ├── providers.dart                # DI root (Riverpod)
    │   ├── auth_provider.dart            # Auth state machine
    │   └── device_list_provider.dart     # Device list + block actions
    ├── screens/
    │   ├── login_screen.dart
    │   └── device_list_screen.dart
    ├── widgets/
    │   ├── device_card.dart
    │   └── device_list_skeleton.dart
    └── theme/app_theme.dart
```

---

## Setup & build

### Prerequisites
- Flutter 3.16+ (`flutter --version`)
- Android SDK 33+ (or connected Android phone in USB debug mode)

### 1. Get dependencies
```bash
cd netis_manager
flutter pub get
```

### 2. Run on your phone
```bash
flutter run --release
```

### 3. Build APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## How to log in

1. Connect your Android phone to the **NETIS router's Wi-Fi**.
2. Open the app.
3. Leave the IP field **blank** — the app will discover the router automatically.
4. Enter your admin username (default: `admin`) and password.
5. Tap **Connect to Router**.

The credentials are encrypted and saved. Next time you open the app it logs in
automatically.

---

## Troubleshooting

### "Could not find the router on your network"
- Make sure your phone is connected to the **NETIS Wi-Fi**, not mobile data.
- Check that the router's gateway is 192.168.1.1 or 192.168.0.1. If it's
  something else, enter it manually in the IP field.
- Try opening `http://192.168.1.1` in Chrome on your phone to confirm the
  router is reachable.

### "Could not read router response"
- This usually means the firmware's HTML structure differs from what was
  tested. Enable `appLogger` output (debug build), capture the HTML, and
  update `NetisHtmlParser` accordingly.
- See the comment at the top of `netis_html_parser.dart` for how to capture
  the router's HTML using Chrome DevTools.

### Block/Unblock doesn't seem to work
- Open `http://192.168.1.1/cgi-bin/macfilter.asp` in a browser.
- Look at the form's action URL and field names in DevTools → Elements.
- Compare them to `RouterConstants.pathMacFilterAction` and the field names
  in `RouterRemoteDataSource._submitMacFilterList`. Update if different.

---

## Extending the app

### Adding a new router feature
1. Add the URL to `RouterConstants`.
2. Add a parse method in `NetisHtmlParser`.
3. Add a method to `RouterRemoteDataSource`.
4. Add an abstract method to `RouterRepository`.
5. Implement it in `RouterRepositoryImpl`.
6. Add a provider / notifier.
7. Build the UI widget.

### Supporting a different router model
Create a new `datasources/` folder for the new router's HTTP interface and
parser. The domain layer (entities, repository interface) stays unchanged.

---

## Running tests

```bash
flutter test
```

Tests cover:
- `NetisHtmlParser` — all parse methods with real HTML fixtures
- `Device` entity — equality, `displayName`, `copyWith`
- `Result<T>` — `fold`, `valueOrThrow`, `isSuccess`

---

## Technical limitations (honest)

The NETIS WF2409E is a budget home router. Its stock firmware does not expose:

- Per-device bandwidth usage
- Real-time traffic graphs
- QoS or speed limiting per device
- CPU / RAM usage
- Detailed connection history

These features would require replacing the firmware (e.g. with OpenWrt, if the
hardware is supported) which is outside the scope of this app. The app is built
to detect unsupported features and disable the relevant UI elements rather than
pretending to implement them.
