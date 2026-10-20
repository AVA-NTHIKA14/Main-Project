import 'package:flutter/material.dart';

abstract final class RoadSenseColors {
  static const ink = Color(0xFF17252F);
  static const muted = Color(0xFF687780);
  static const canvas = Color(0xFFF6F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDE5E3);
  static const teal = Color(0xFF167D78);
  static const tealSoft = Color(0xFFE3F1EF);
  static const amber = Color(0xFFB66A13);
  static const amberSoft = Color(0xFFFFF1D9);
  static const red = Color(0xFFB84B45);
  static const redSoft = Color(0xFFFBE8E6);
}

abstract final class RoadSenseSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class RoadSenseRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

ThemeData buildRoadSenseTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: RoadSenseColors.teal).copyWith(
    primary: RoadSenseColors.teal,
    onPrimary: Colors.white,
    surface: RoadSenseColors.surface,
    onSurface: RoadSenseColors.ink,
    error: RoadSenseColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RoadSenseColors.canvas,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: RoadSenseColors.ink,
        fontSize: 25,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      titleLarge: TextStyle(
        color: RoadSenseColors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: RoadSenseColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: RoadSenseColors.ink,
        fontSize: 16,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        color: RoadSenseColors.muted,
        fontSize: 14,
        height: 1.35,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RoadSenseColors.canvas,
      foregroundColor: RoadSenseColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RoadSenseColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RoadSenseRadius.md),
        borderSide: const BorderSide(color: RoadSenseColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RoadSenseRadius.md),
        borderSide: const BorderSide(color: RoadSenseColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RoadSenseRadius.md),
        borderSide: const BorderSide(color: RoadSenseColors.teal, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RoadSenseRadius.md),
        ),
        elevation: 0,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 76,
      backgroundColor: RoadSenseColors.surface,
      indicatorColor: RoadSenseColors.tealSoft,
    ),
  );
}

enum StatusTone { good, warning, error }

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == StatusTone.good
        ? RoadSenseColors.teal
        : tone == StatusTone.warning
        ? RoadSenseColors.amber
        : RoadSenseColors.red;
    final background = tone == StatusTone.good
        ? RoadSenseColors.tealSoft
        : tone == StatusTone.warning
        ? RoadSenseColors.amberSoft
        : RoadSenseColors.redSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RoadSenseRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MapControl extends StatelessWidget {
  const MapControl({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: RoadSenseColors.surface,
    elevation: 2,
    shadowColor: RoadSenseColors.ink.withValues(alpha: .12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RoadSenseRadius.sm),
    ),
    child: IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon)),
  );
}

class RoadMap extends StatelessWidget {
  const RoadMap({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(RoadSenseRadius.lg),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _RoadMapPainter()),
        Positioned(
          top: RoadSenseSpacing.md,
          left: RoadSenseSpacing.md,
          right: RoadSenseSpacing.md,
          child: TextField(
            readOnly: true,
            onTap: () {},
            decoration: const InputDecoration(
              hintText: 'Search a place or route',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const Positioned(
          right: RoadSenseSpacing.md,
          bottom: RoadSenseSpacing.md,
          child: Column(
            children: [
              MapControl(
                icon: Icons.my_location_outlined,
                tooltip: 'Center map',
              ),
              SizedBox(height: RoadSenseSpacing.sm),
              MapControl(icon: Icons.layers_outlined, tooltip: 'Map layers'),
            ],
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(child: _MapPin()),
        ),
      ],
    ),
  );
}

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: RoadSenseColors.ink,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
    ),
    child: const Icon(Icons.navigation, color: Colors.white, size: 20),
  );
}

class _RoadMapPainter extends CustomPainter {
  const _RoadMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8F0EC),
    );
    final minor = Paint()
      ..color = const Color(0xFFD0DED9)
      ..strokeWidth = 2;
    final major = Paint()
      ..color = Colors.white
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFC4D4CE)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    for (var x = -size.height; x < size.width + size.height; x += 74) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        minor,
      );
    }
    final roads = [
      [
        Offset(size.width * .1, size.height),
        Offset(size.width * .43, size.height * .5),
        Offset(size.width * .94, size.height * .16),
      ],
      [
        Offset(size.width * .6, -20),
        Offset(size.width * .55, size.height * .5),
        Offset(size.width * .76, size.height + 20),
      ],
    ];
    for (final points in roads) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, edge);
      canvas.drawPath(path, major);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoadSenseEmptyState extends StatelessWidget {
  const RoadSenseEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 42, color: RoadSenseColors.muted),
      const SizedBox(height: RoadSenseSpacing.md),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: RoadSenseSpacing.sm),
      Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class RoadSenseBottomSheet extends StatelessWidget {
  const RoadSenseBottomSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(
        RoadSenseSpacing.md,
        RoadSenseSpacing.sm,
        RoadSenseSpacing.md,
        RoadSenseSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: RoadSenseColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RoadSenseRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: RoadSenseColors.line,
              borderRadius: BorderRadius.circular(RoadSenseRadius.pill),
            ),
          ),
          const SizedBox(height: RoadSenseSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class RoadSenseLoadingState extends StatelessWidget {
  const RoadSenseLoadingState({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: RoadSenseSpacing.sm),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class RoadSenseErrorState extends StatelessWidget {
  const RoadSenseErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(
        Icons.cloud_off_outlined,
        size: 42,
        color: RoadSenseColors.red,
      ),
      const SizedBox(height: RoadSenseSpacing.md),
      Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (onRetry != null) ...[
        const SizedBox(height: RoadSenseSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ],
  );
}
