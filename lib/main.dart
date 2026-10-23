// lib/main.dart
//
// Punto de entrada de la app. Aquí inicializamos la conexión a
// Supabase ANTES de que arranque la interfaz, para asegurarnos de
// que esté lista para usarse en cualquier pantalla.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_settings.dart';
import 'config/supabase_config.dart';
import 'screens/lista_ejercicios_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Esto es necesario porque vamos a hacer una operación "async"
  // (conectar con Supabase) antes de correr la app.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos Supabase una sola vez, al arrancar la app.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Cargamos las preferencias guardadas del usuario (ej: decimales).
  await AppSettings.cargar();

  runApp(const MyApp());
}

/// Acceso rápido al cliente de Supabase desde cualquier parte de la app.
/// En vez de escribir "Supabase.instance.client" en cada archivo,
/// simplemente usamos la variable "supabase".
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kardex+',
      // Quita la cinta roja de "DEBUG" de la esquina — es solo un
      // aviso de Flutter para desarrollo, no afecta nada funcional,
      // pero tapaba el ícono de Configuraciones.
      debugShowCheckedModeBanner: false,
      // Esto hace que TODOS los widgets del sistema (el calendario,
      // los botones de "Cancelar/Aceptar", etc.) aparezcan en
      // español en vez de en inglés.
      locale: const Locale('es', 'BO'),
      supportedLocales: const [Locale('es', 'BO'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.themeData,
      home: const ListaEjerciciosScreen(),
    );
  }
}