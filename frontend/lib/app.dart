import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/reporter/incident_reporter_screen.dart';

class AquaFixApp extends StatelessWidget {
  const AquaFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaFix',
      debugShowCheckedModeBanner: false,
      
      // Premium Custom Design Theme - Deep Indigo / Cyber Teal Dark Mode
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark Slate backdrop
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo HSL tone
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF14B8A6), // Vibrant Teal accent
          surface: const Color(0xFF1E293B), // Sleek elevation surfaces
          error: const Color(0xFFEF4444), // Rich Red error warnings
        ),
        
        // Dynamic, Premium Typography using Google Fonts
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        
        // High-fidelity styled card margins & buttons
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      
      home: const IncidentReporterScreen(),
    );
  }
}
