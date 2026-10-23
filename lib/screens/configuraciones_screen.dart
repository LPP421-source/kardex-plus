// lib/screens/configuraciones_screen.dart
//
// Pantalla de configuraciones de la app. Por ahora solo tiene una
// opción (decimales de costo unitario), pero está pensada para
// poder agregar más configuraciones después sin reestructurar nada.

import 'package:flutter/material.dart';
import '../config/app_settings.dart';
import '../config/app_version.dart';

class ConfiguracionesScreen extends StatelessWidget {
  const ConfiguracionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuraciones')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'VISUALIZACIÓN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          // ValueListenableBuilder hace que este widget se
          // reconstruya SOLO cuando cambia decimalesCosto, sin
          // necesidad de un StatefulWidget completo.
          ValueListenableBuilder<int>(
            valueListenable: AppSettings.decimalesCosto,
            builder: (context, decimales, _) {
              return ListTile(
                title: const Text('Decimales sugeridos por defecto'),
                subtitle: Text(
                  'Se usa como sugerencia al crear un ejercicio nuevo '
                  '(cada ejercicio puede tener su propio valor). '
                  'Actualmente: $decimales decimal${decimales == 1 ? '' : 'es'}.',
                ),
                trailing: DropdownButton<int>(
                  value: decimales,
                  items: List.generate(11, (n) => n) // 0 al 10
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text('$n')),
                      )
                      .toList(),
                  onChanged: (nuevoValor) {
                    if (nuevoValor != null) {
                      AppSettings.actualizarDecimales(nuevoValor);
                    }
                  },
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cada ejercicio tiene su propio ajuste de decimales para '
              'la columna "Costo Unitario" (lo eliges al crear o editar '
              'el ejercicio). Este valor de aquí solo se usa como '
              'sugerencia inicial para ejercicios nuevos. Los montos '
              'totales (Bs) siempre se muestran con 2 decimales.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          // Versión de la app (se cambia en lib/config/app_version.dart)
          const VersionLabel(),
        ],
      ),
    );
  }
}