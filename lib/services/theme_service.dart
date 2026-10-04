import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Polaris palette (from your picked swatches).
class PolarisPalette {
  PolarisPalette._();

  static const Color night = Color(0xFF151E2F); // dark background
  static const Color royal = Color(0xFF2A3E83); // brand blue
  static const Color khaki = Color(0xFFDAD69F);
  static const Color star = Color(0xFFD7A02B); // star yellow
  static const Color olive = Color(0xFFA3945D);
  static const Color periwinkle = Color(0xFF6D82B1);
  static const Color slate = Color(0xFF303F63);
}

/// Extra colors the views use directly (text, cards, fields, status colors).
/// Read them with `context.pc`.
@immutable
class PolarisColors extends ThemeExtension<PolarisColors> {
  const PolarisColors({
    required this.background,
    required this.card,
    required this.field,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.star,
    required this.line,
    required this.success,
    required this.danger,
  });

  final Color background; // screen background
  final Color card; // cards, sheets, dialogs
  final Color field; // text field + chip fill
  final Color ink; // main text and icons
  final Color muted; // secondary text
  final Color accent; // links, selected chips, highlights
  final Color star; // prices and star highlights
  final Color line; // dividers
  final Color success;
  final Color danger;

  static const PolarisColors light = PolarisColors(
    background: Color(0xFFFFFFFF),
    card: Color(0xFFF1F3F9),
    field: Color(0xFFE6E9F3),
    ink: PolarisPalette.night,
    muted: Color(0xFF4F5B7A),
    accent: PolarisPalette.royal,
    star: Color(0xFF7A6C2D), // darkened olive so small price text stays readable
    line: Color(0xFFD5DAEA),
    success: Color(0xFF1E7A4C),
    danger: Color(0xFFC0252B),
  );

  static const PolarisColors dark = PolarisColors(
    background: PolarisPalette.night,
    card: Color(0xFF1D2840),
    field: PolarisPalette.slate,
    ink: Color(0xFFF2F5FF),
    muted: Color(0xFFAEB9DA),
    accent: Color(0xFFA9BBF0), // lightened periwinkle for contrast on navy
    star: PolarisPalette.star,
    line: Color(0xFF3A4A75),
    success: Color(0xFF6FD6A0),
    danger: Color(0xFFFF9AA0),
  );

  @override
  PolarisColors copyWith({
    Color? background,
    Color? card,
    Color? field,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? star,
    Color? line,
    Color? success,
    Color? danger,
  }) {
    return PolarisColors(
      background: background ?? this.background,
      card: card ?? this.card,
      field: field ?? this.field,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      star: star ?? this.star,
      line: line ?? this.line,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  PolarisColors lerp(ThemeExtension<PolarisColors>? other, double t) {
    if (other is! PolarisColors) return this;
    return PolarisColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      field: Color.lerp(field, other.field, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      star: Color.lerp(star, other.star, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension PolarisThemeContext on BuildContext {
  PolarisColors get pc => Theme.of(this).extension<PolarisColors>()!;
}

/// Holds the chosen theme mode (system by default) and remembers it.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController._(this._mode, this._prefs);

  static const String _key = 'theme_mode';

  final SharedPreferences? _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  static Future<ThemeModeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final mode = saved == 'dark'
          ? ThemeMode.dark
          : saved == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
      return ThemeModeController._(mode, prefs);
    } catch (_) {
      return ThemeModeController._(ThemeMode.system, null);
    }
  }

  void toggle({required bool currentlyDark}) {
    _mode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _prefs?.setString(_key, currentlyDark ? 'light' : 'dark');
  }
}

/// Sun/moon button. Moon in light mode (tap for dark), sun in dark mode.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () =>
          context.read<ThemeModeController>().toggle(currentlyDark: isDark),
    );
  }
}

/// One place for the whole app's look.
///
/// In main.dart:
///   theme: ThemeService.light,
///   darkTheme: ThemeService.dark,
///   themeMode: themeController.mode,  (see main.dart)
class ThemeService {
  ThemeService._();

  static const double radius = 16;

  static final ThemeData light = _build(Brightness.light, PolarisColors.light);
  static final ThemeData dark = _build(Brightness.dark, PolarisColors.dark);

  static ThemeData _build(Brightness brightness, PolarisColors c) {
    final isDark = brightness == Brightness.dark;

    final primary = isDark ? PolarisPalette.star : PolarisPalette.royal;
    final onPrimary = isDark ? PolarisPalette.night : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? PolarisPalette.slate : const Color(0xFFDDE3F6),
      onPrimaryContainer: c.ink,
      secondary: c.accent,
      onSecondary: isDark ? PolarisPalette.night : Colors.white,
      secondaryContainer: PolarisPalette.royal,
      onSecondaryContainer: Colors.white,
      tertiary: isDark ? PolarisPalette.star : PolarisPalette.olive,
      onTertiary: PolarisPalette.night,
      error: c.danger,
      onError: isDark ? PolarisPalette.night : Colors.white,
      surface: c.background,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.card,
      surfaceContainerHighest: c.field,
      outline: c.line,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    );

    final fieldRadius = BorderRadius.circular(radius);
    const noBorder = BorderSide.none;

    OutlineInputBorder fieldBorder() => OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: noBorder,
        );

    final focusFill = isDark ? const Color(0xFF3B4B7A) : const Color(0xFFDAE0F4);
    final errorFill = isDark ? const Color(0xFF4A2635) : const Color(0xFFFADCDC);

    return base.copyWith(
      extensions: [c],
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.line,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 24),
      iconTheme: IconThemeData(color: c.ink),

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.ink),
        actionsIconTheme: IconThemeData(color: c.ink),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: c.ink,
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Filled fields, no outlines anywhere.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.error)) return errorFill;
          if (states.contains(WidgetState.focused)) return focusFill;
          return c.field;
        }),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: c.muted),
        labelStyle: TextStyle(color: c.muted),
        floatingLabelStyle: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
        helperStyle: TextStyle(color: c.muted),
        errorStyle: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: fieldBorder(),
        enabledBorder: fieldBorder(),
        focusedBorder: fieldBorder(),
        errorBorder: fieldBorder(),
        focusedErrorBorder: fieldBorder(),
        disabledBorder: fieldBorder(),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withOpacity(0.3),
        selectionHandleColor: c.accent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: c.field,
          disabledForegroundColor: c.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: c.field,
          disabledForegroundColor: c.muted,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.field,
        selectedColor: c.accent,
        disabledColor: c.field,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: textTheme.labelLarge?.copyWith(color: c.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: isDark ? PolarisPalette.night : Colors.white,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.accent.withOpacity(0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.ink : c.muted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? c.ink : c.muted,
          );
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: c.ink,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.muted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.accent,
        textColor: c.ink,
        subtitleTextStyle: TextStyle(color: c.muted, fontSize: 13),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? PolarisPalette.slate : PolarisPalette.night,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    );
  }
}