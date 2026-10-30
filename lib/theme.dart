import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/settings.dart';

/// Bir temanın tüm renkleri.
class Palette {
  final String key, name;
  final bool dark;
  final Color bg, surface, surface2, text, muted, accent, accent2, on, border, danger, warn, ok;
  const Palette({
    required this.key,
    required this.name,
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.on,
    required this.border,
    required this.danger,
    required this.warn,
    required this.ok,
  });

  /// Afili başlık/rakam fontu.
  TextStyle displayStyle(double size, {Color? color, double height = 1.05, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.sora(fontSize: size, color: color ?? text, height: height, fontWeight: weight, letterSpacing: -0.5);

  TextStyle bodyStyle(double size, {Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, color: color ?? text, fontWeight: weight);
}

/// Gece (koyu) — varsayılan. Sıcak amber + dingin teal.
const gece = Palette(
  key: 'gece', name: 'Gece', dark: true,
  bg: Color(0xFF0E1419), surface: Color(0xFF161F27), surface2: Color(0xFF212E39),
  text: Color(0xFFEDF3F8), muted: Color(0xFF93A4B3), accent: Color(0xFFF2B33D),
  accent2: Color(0xFF3DD0A8), on: Color(0xFF1A1203), border: Color(0xFF2A3845),
  danger: Color(0xFFFF8A80), warn: Color(0xFFFFCB4D), ok: Color(0xFF3DD0A8),
);

/// Gündüz (açık) — temiz, yüksek kontrast.
const gunduz = Palette(
  key: 'gunduz', name: 'Gündüz', dark: false,
  bg: Color(0xFFF4F6F8), surface: Color(0xFFFFFFFF), surface2: Color(0xFFEAEEF2),
  text: Color(0xFF13202B), muted: Color(0xFF5C6B78), accent: Color(0xFFE09612),
  accent2: Color(0xFF12A47E), on: Color(0xFFFFFFFF), border: Color(0xFFDCE3EA),
  danger: Color(0xFFD0453B), warn: Color(0xFFB7791F), ok: Color(0xFF12A47E),
);

const themes = <Palette>[gece, gunduz];

/// Cihaza özel seçili tema (her telefon kendi görünümünü seçer).
Palette appTheme() {
  final k = Settings.getLocal('theme', 'gece');
  return themes.firstWhere((p) => p.key == k, orElse: () => gece);
}
