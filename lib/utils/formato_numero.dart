// lib/utils/formato_numero.dart
//
// Formatea un número con separador de miles (coma) y punto decimal,
// ej: 1054200.5 → "1,054,200.50". Se usa en toda la tarjeta kardex
// (costos unitarios y montos) para que sea más fácil de leer.

import 'package:intl/intl.dart';

String formatoConMiles(double valor, int decimales) {
  // Armamos el patrón según cuántos decimales corresponda, ej:
  // 2 decimales → "#,##0.00", 0 decimales → "#,##0".
  final patron = decimales == 0 ? '#,##0' : '#,##0.${'0' * decimales}';

  // Forzamos el formato "en_US" (coma para miles, punto para
  // decimales) sin importar el idioma del dispositivo, ya que es el
  // formato que se pidió para la tarjeta kardex.
  final formato = NumberFormat(patron, 'en_US');
  return formato.format(valor);
}