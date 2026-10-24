// lib/screens/login_screen.dart
//
// Pantalla de inicio de sesión. Solo tiene un botón: "Continuar con
// Google". Al pulsarlo, Supabase redirige al usuario a Google para
// que elija su cuenta, y luego lo devuelve a la app ya con sesión.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_version.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _cargando = false;
  String? _error;

  // Dirección a la que Google debe devolver al usuario después de
  // iniciar sesión. En tu computadora (localhost) vuelve a localhost;
  // en internet vuelve a tu página de GitHub Pages.
  String get _urlDeRetorno {
    if (kIsWeb && Uri.base.host == 'localhost') {
      return Uri.base.origin;
    }
    return 'https://lpp421-source.github.io/kardex-plus/';
  }

  Future<void> _iniciarConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _urlDeRetorno,
      );
      // En web la página se redirige a Google, así que aquí no
      // hace falta apagar el indicador de carga.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo iniciar sesión. Intenta de nuevo.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colores.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: colores.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kardex+',
                    style: textos.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Practica y aprende inventarios con PEPS, UEPS y '
                    'Costo Promedio Ponderado.',
                    textAlign: TextAlign.center,
                    style: textos.bodyMedium?.copyWith(
                      color: colores.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _cargando ? null : _iniciarConGoogle,
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _cargando ? 'Conectando...' : 'Continuar con Google',
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colores.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Kardex+ $versionApp',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}