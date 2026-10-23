// lib/config/app_version.dart
//
// Aqui se define el numero de version de Kardex+.
// Cambia el texto de [versionApp] cada vez que publiques una nueva version
// (por ejemplo v1.0.2, v1.0.3...). Asi sabes que version tienes abierta
// en el celular.

import 'package:flutter/material.dart';

const String versionApp = 'v1.0.2 - 23/10/2026';

/// Texto pequeño y centrado que muestra la version de la app.
/// Para usarlo en una pantalla basta con escribir: const VersionLabel()
class VersionLabel extends StatelessWidget {
  const VersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'Kardex+ $versionApp',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}