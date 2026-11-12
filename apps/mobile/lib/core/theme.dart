import 'package:material_ui/material_ui.dart';

/// Semantic colour tokens (light + dark). Mirrors packages/design-tokens/tokens.json.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.pink,
    required this.green,
    required this.cyan,
    required this.weekend,
    required this.divider,
    required this.border,
    required this.tileOrange,
    required this.tileGreen,
    required this.tileGrey,
    required this.segmentBg,
  });

  final Color primary, background, surface, textPrimary, textSecondary, pink, green, cyan, weekend, divider, border;
  final Color tileOrange, tileGreen, tileGrey, segmentBg;

  static const light = AppColors(
    primary: Color(0xFF9137E8),
    background: Color(0xFFF2F1F7),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF777777),
    pink: Color(0xFFEB3485),
    green: Color(0xFF28B84A),
    cyan: Color(0xFF078EA7),
    weekend: Color(0xFFE5484D),
    divider: Color(0xFFE3E2E8),
    border: Color(0xFFDCDBE1),
    tileOrange: Color(0xFFF2D9A6),
    tileGreen: Color(0xFFB9EDBE),
    tileGrey: Color(0xFFDDDDE2),
    segmentBg: Color(0xFFE6E5EB),
  );

  static const dark = AppColors(
    primary: Color(0xFFB27BF2),
    background: Color(0xFF0E0D12),
    surface: Color(0xFF1C1B22),
    textPrimary: Color(0xFFF4F3F8),
    textSecondary: Color(0xFFA09FA8),
    pink: Color(0xFFFF5FA2),
    green: Color(0xFF4CD467),
    cyan: Color(0xFF2EC0D9),
    weekend: Color(0xFFFF6B6F),
    divider: Color(0xFF2C2B33),
    border: Color(0xFF3A3942),
    tileOrange: Color(0xFF4A3B1E),
    tileGreen: Color(0xFF1E4426),
    tileGrey: Color(0xFF34333B),
    segmentBg: Color(0xFF2A2931),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness, {String? fontFamily}) {
  final c = brightness == Brightness.light ? AppColors.light : AppColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: brightness,
  ).copyWith(primary: c.primary, surface: c.surface, onSurface: c.textPrimary, error: c.weekend);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: fontFamily,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.textPrimary, fontFamily: fontFamily),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 0.6, space: 0.6),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.background, showDragHandle: true),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
  );
}
