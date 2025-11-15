Place your app launcher icon image at `assets/icon/icon.png`.

Recommended: a 1024x1024 PNG with transparency. The `flutter_launcher_icons` tool will generate all required sizes for Android and iOS.

Steps to generate the icons (run in your project root):

```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

If you prefer to share/generate adaptive icons, update `pubspec.yaml` `flutter_icons` config accordingly. See https://pub.dev/packages/flutter_launcher_icons for options.
