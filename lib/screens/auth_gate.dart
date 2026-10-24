// lib/screens/auth_gate.dart
//
// "Portero" de la app: escucha los cambios de sesión de Supabase.
//  - Si hay una sesión iniciada  -> muestra la lista de ejercicios.
//  - Si no hay sesión            -> muestra la pantalla de login.
// Cuando el usuario inicia o cierra sesión, cambia solo, sin
// necesidad de navegar manualmente.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lista_ejercicios_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Usamos la sesión del evento si ya llegó; si no, la que
        // Supabase ya tenga guardada (por ejemplo al reabrir la app).
        final sesion = snapshot.data?.session ?? auth.currentSession;

        if (sesion != null) {
          return const ListaEjerciciosScreen();
        }
        return const LoginScreen();
      },
    );
  }
}