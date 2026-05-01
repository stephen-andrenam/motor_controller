import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'screens/home_screen.dart';
import 'services/ble_manager.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await FlutterBluePlus.setOptions(showPowerAlert: false);

      WidgetsBinding.instance.addObserver(BleManager.instance);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      runApp(const MotorControllerApp());
    },
    (error, stack) => debugPrint('Uncaught Dart error: $error\n$stack'),
  );
}

class MotorControllerApp extends StatelessWidget {
  const MotorControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motor Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        cardTheme: CardThemeData(
          color: const Color(0xFF112240),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1628),
          foregroundColor: Color(0xFFCCD6F6),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B4D8),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A2F4A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF233554)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF233554)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8892B0)),
          hintStyle: const TextStyle(color: Color(0xFF4A5568)),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF00B4D8),
          inactiveTrackColor: const Color(0xFF233554),
          thumbColor: const Color(0xFF00B4D8),
          overlayColor: const Color(0x2900B4D8),
          valueIndicatorColor: const Color(0xFF00B4D8),
          valueIndicatorTextStyle: const TextStyle(color: Colors.black),
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFCCD6F6)),
          bodyMedium: TextStyle(color: Color(0xFF8892B0)),
          titleLarge: TextStyle(
            color: Color(0xFFCCD6F6),
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFFCCD6F6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
