# ccviewer_mobile_hub

Flutter app shell for the `cc-viewer` mobile bridge.

## Implemented

- Scan QR (`ccviewer://mobile-connect?payload=...`)
- Parse payload JSON from base64url
- Connect LAN websocket (`payload.wsUrl`)
- Connect HUB mode:
  - POST pairing consume to `POST {hubDomain}/api/mobile/pairings/consume`
  - Use response `wsUrl`; fallback to `/ws/mobile/client?token=...`
- Show chat snapshot messages
- Show prompt options and submit answer
- Send text message to Claude Code
- Voice-to-text fills input box (speech recognition, manual send)

## Files

- `lib/main.dart`: app shell, chat page, voice input, state rendering
- `lib/models/connect_payload.dart`: QR payload model
- `lib/models/chat_models.dart`: snapshot/prompt models
- `lib/services/qr_payload_parser.dart`: decode + parse QR payload
- `lib/services/connection_service.dart`: websocket + hub pairing logic
- `lib/widgets/qr_scan_page.dart`: scanner page
- `lib/widgets/prompt_card.dart`: prompt UI
- `test/`: parser + widget smoke tests
- `docs/post_flutter_create.md`: SDK 到位后生成平台目录的接入清单

## Local run

1. Install Flutter SDK (3.22+ recommended) and add `flutter` to PATH.
2. In this directory, run:
   - `flutter create .`
   - `flutter pub get`
   - `flutter test`
   - `flutter run`

## Permissions

- iOS (`ios/Runner/Info.plist`):
  - `NSCameraUsageDescription` for QR scan
  - `NSSpeechRecognitionUsageDescription` for voice
  - `NSMicrophoneUsageDescription` for voice
- Android (`android/app/src/main/AndroidManifest.xml`):
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`

## Notes

- 当前仓库故意不手写 `ios/`、`android/` 生成物，避免和 `flutter create .` 的模板冲突。
- 需要生成平台目录后，再按 [docs/post_flutter_create.md](/Users/wangli/Desktop/cctv/flutter/docs/post_flutter_create.md) 补权限。
