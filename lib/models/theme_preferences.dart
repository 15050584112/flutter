import "package:flutter/material.dart";

enum AppThemeMode {
  system,
  light,
  dark,
}

class ThemePreferences {
  static const int defaultAccentColor = 0xFF005B99;

  final AppThemeMode mode;
  final int accentColor;

  const ThemePreferences({
    this.mode = AppThemeMode.system,
    this.accentColor = defaultAccentColor,
  });

  ThemePreferences copyWith({
    AppThemeMode? mode,
    int? accentColor,
  }) {
    return ThemePreferences(
      mode: mode ?? this.mode,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "mode": mode.name,
      "accentColor": accentColor,
    };
  }

  factory ThemePreferences.fromJson(Map<String, dynamic> json) {
    final modeRaw = json["mode"];
    final accentRaw = json["accentColor"];

    AppThemeMode parsedMode = AppThemeMode.system;
    if (modeRaw is String) {
      for (final value in AppThemeMode.values) {
        if (value.name == modeRaw) {
          parsedMode = value;
          break;
        }
      }
    }

    int parsedAccent = defaultAccentColor;
    if (accentRaw is int) {
      parsedAccent = accentRaw;
    } else if (accentRaw is String) {
      parsedAccent = int.tryParse(accentRaw) ?? defaultAccentColor;
    }

    return ThemePreferences(
      mode: parsedMode,
      accentColor: parsedAccent,
    );
  }

  ThemeMode toThemeMode() {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }
}
