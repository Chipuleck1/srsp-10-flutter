import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Палитра TaskFlow: синий #007ea7, розовый #df1778 и белый.
abstract final class Tf {
  static const blue = Color(0xFF007EA7);
  static const pink = Color(0xFFDF1778);
  static const white = Colors.white;

  static const blueSoft = Color(0xFFE5F3F8);
  static const pinkSoft = Color(0xFFFCE7F1);
  static const background = Color(0xFFF6FAFC);
  static const ink = Color(0xFF12313F);
  static const muted = Color(0xFF6E8794);
  static const border = Color(0xFFE1ECF1);
  static const green = Color(0xFF1E9E6E);
  static const orange = Color(0xFFF08A24);

  static const gradient = LinearGradient(
    colors: [blue, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      onPrimary: white,
      secondary: pink,
      onSecondary: white,
      surface: white,
      onSurface: ink,
      error: pink,
    );
    final radius = BorderRadius.circular(16);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: white,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: pink,
        foregroundColor: white,
        shape: StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: blue),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: pink),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: pinkSoft,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? pink : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? pink : muted,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: blue,
        unselectedLabelColor: muted,
        indicatorColor: pink,
        dividerColor: border,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        actionTextColor: const Color(0xFFFF8DC1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
    );
  }

  static Color statusColor(TaskStatus s) => switch (s) {
    TaskStatus.todo => muted,
    TaskStatus.inProgress => blue,
    TaskStatus.done => green,
    TaskStatus.cancelled => const Color(0xFFA3B1B8),
  };

  static IconData statusIcon(TaskStatus s) => switch (s) {
    TaskStatus.todo => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.timelapse,
    TaskStatus.done => Icons.check_circle,
    TaskStatus.cancelled => Icons.cancel_outlined,
  };

  static Color priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.low => const Color(0xFF7FB8CC),
    TaskPriority.medium => blue,
    TaskPriority.high => orange,
    TaskPriority.critical => pink,
  };

  static Color projectStatusColor(ProjectStatus s) => switch (s) {
    ProjectStatus.active => blue,
    ProjectStatus.completed => green,
    ProjectStatus.archived => muted,
  };
}

String fmtDate(DateTime? d) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String fmtDateTime(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${fmtDate(d)} ${two(d.hour)}:${two(d.minute)}';
}
