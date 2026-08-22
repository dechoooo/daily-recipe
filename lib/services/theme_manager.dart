import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ThemeConfig {
  final Color primaryColor;
  final Color accentColor;
  final String? backgroundImage;
  final bool bgEnabled;
  static const defaultBackgroundColor = Colors.white;

  ThemeConfig({
    this.primaryColor = const Color(0xFF1a237e),
    this.accentColor = const Color(0xFFf9a825),
    this.backgroundImage,
    this.bgEnabled = true,
  });

  Map<String, dynamic> toMap() => {
    'primary_color': primaryColor.value,
    'accent_color': accentColor.value,
    'background_image': backgroundImage,
    'bg_enabled': bgEnabled,
  };

  factory ThemeConfig.fromMap(Map<String, dynamic> map) => ThemeConfig(
    primaryColor: Color(map['primary_color'] as int? ?? 0xFF1a237e),
    accentColor: Color(map['accent_color'] as int? ?? 0xFFf9a825),
    backgroundImage: map['background_image'] as String?,
    bgEnabled: map['bg_enabled'] as bool? ?? true,
  );

  String toJson() => jsonEncode(toMap());
  factory ThemeConfig.fromJson(String json) => ThemeConfig.fromMap(jsonDecode(json));

  ThemeConfig copyWith({
    Color? primaryColor,
    Color? accentColor,
    String? backgroundImage,
    bool? bgEnabled,
  }) => ThemeConfig(
    primaryColor: primaryColor ?? this.primaryColor,
    accentColor: accentColor ?? this.accentColor,
    backgroundImage: backgroundImage ?? this.backgroundImage,
    bgEnabled: bgEnabled ?? this.bgEnabled,
  );
}

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  ThemeConfig _config = ThemeConfig();
  ThemeConfig get config => _config;

  String? getBackgroundPath() {
    if (!config.bgEnabled || config.backgroundImage == null || config.backgroundImage!.isEmpty) {
      return null;
    }
    final path = config.backgroundImage!;
    return File(path).existsSync() ? path : null;
  }

  /// Returns an ImageProvider for the background image.
  /// - If user has set a custom background, returns FileImage
  /// - If bgEnabled but no custom image, returns AssetImage (default background)
  /// - If bgEnabled is false, returns null
  ImageProvider? getBackgroundImage() {
    if (!config.bgEnabled) return null;
    
    // User has custom background
    if (config.backgroundImage != null && config.backgroundImage!.isNotEmpty) {
      final path = config.backgroundImage!;
      if (File(path).existsSync()) {
        return FileImage(File(path));
      }
    }
    
    // Default built-in background
    return const AssetImage('assets/default_background.png');
  }

  Color get backgroundColor => ThemeConfig.defaultBackgroundColor;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final json = sp.getString(AppConstants.spKeyThemeConfig);
    if (json != null && json.isNotEmpty) {
      try {
        _config = ThemeConfig.fromJson(json);
        final oldRecipeBg = sp.getString('recipe_page_background');
        if (oldRecipeBg != null && oldRecipeBg.isNotEmpty && _config.backgroundImage == null) {
          _config = _config.copyWith(backgroundImage: oldRecipeBg);
          await save();
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppConstants.spKeyThemeConfig, _config.toJson());
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _config = _config.copyWith(primaryColor: color);
    await save();
  }

  Future<void> setBackgroundImage(String? path) async {
    _config = _config.copyWith(backgroundImage: path, bgEnabled: path != null);
    await save();
  }

  Future<void> clearBackgroundImage() async {
    _config = _config.copyWith(backgroundImage: null, bgEnabled: false);
    await save();
  }

  Future<void> toggleBackgroundEnabled(bool enabled) async {
    _config = _config.copyWith(bgEnabled: enabled);
    await save();
  }

  ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _config.primaryColor,
      primary: _config.primaryColor,
      secondary: _config.accentColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: _config.primaryColor,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: _config.primaryColor.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _config.primaryColor,
          );
        }
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.grey[600],
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(size: 24, color: _config.primaryColor);
        }
        return IconThemeData(size: 24, color: Colors.grey[600]);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _config.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _config.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _config.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _config.primaryColor.withOpacity(0.08),
      selectedColor: _config.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(color: _config.primaryColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}