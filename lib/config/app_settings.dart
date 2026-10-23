// lib/config/app_settings.dart
//
// Configuración global de la app. A diferencia de los datos de
// ejercicios/productos/movimientos (que viven en Supabase, porque
// son datos de trabajo), esto es una PREFERENCIA de la aplicación,
// así que se guarda localmente en el dispositivo con
// shared_preferences — no tiene sentido guardarla en la nube.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const _claveDecimales = 'decimales_costo';

  /// Cuántos decimales se muestran en los costos unitarios y montos
  /// de la tabla kardex y del PDF. Es un ValueNotifier para que
  /// cualquier pantalla que lo esté "escuchando" (con
  /// ValueListenableBuilder) se actualice sola apenas cambie, sin
  /// tener que recargar la pantalla a mano.
  static final ValueNotifier<int> decimalesCosto = ValueNotifier<int>(2);

  /// Se llama UNA vez, al arrancar la app (en main.dart), para
  /// cargar el valor guardado la última vez que el usuario lo
  /// cambió. Si nunca lo cambió, se queda en el valor por defecto (2).
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    decimalesCosto.value = prefs.getInt(_claveDecimales) ?? 2;
  }

  /// Cambia el número de decimales y lo guarda para la próxima vez
  /// que se abra la app.
  static Future<void> actualizarDecimales(int nuevoValor) async {
    decimalesCosto.value = nuevoValor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_claveDecimales, nuevoValor);
  }
}