import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // ProviderScope is mandatory for Riverpod state access
    const ProviderScope(
      child: AquaFixApp(),
    ),
  );
}
