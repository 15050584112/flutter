# Post `flutter create .` Checklist

拿到 Flutter SDK 后，在当前目录执行：

```bash
flutter create .
flutter pub get
```

然后补下面几项。

## iOS

修改 `ios/Runner/Info.plist`，加入：

```xml
<key>NSCameraUsageDescription</key>
<string>用于扫描 cc-viewer 连接二维码</string>
<key>NSMicrophoneUsageDescription</key>
<string>用于语音输入</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>用于把语音转换成文字后再发送</string>
```

## Android

修改 `android/app/src/main/AndroidManifest.xml`，加入：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## First Run

```bash
flutter test
flutter run
```

## Connect Flow

1. 在桌面 `cc-viewer` 终端右侧点“开启手机连接”。
2. 选择 `内网` 或 `外网`。
3. 手机扫码。
4. 外网模式下，App 先调用 HUB 的 pairing consume 接口，再连 HUB websocket。
