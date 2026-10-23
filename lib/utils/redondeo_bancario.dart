// lib/utils/redondeo_bancario.dart
//
// Redondeo "bancario" (también llamado "al par más cercano"),
// usado para los montos en Bs de la tarjeta kardex. Es distinto
// del redondeo simple: la regla especial SOLO se activa cuando el
// dígito a redondear es EXACTAMENTE 5 (nada más después).
//
// - Si el dígito anterior al 5 es IMPAR, sube al siguiente.
// - Si el dígito anterior al 5 es PAR, se queda igual.
// - En cualquier otro caso (menor a 5 baja, mayor a 5 sube), es el
//   redondeo normal de toda la vida.
//
// Ejemplo con 2 decimales:
//   10.125 → 10.12  (el "2" ya es par, se queda igual)
//   10.135 → 10.14  (el "3" es impar, sube a "4")
//   10.126 → 10.13  (no es un caso de "exactamente 5", redondeo normal)

import 'dart:math' as math;

double redondearBancario(double valor, int decimales) {
  final esNegativo = valor < 0;
  final valorAbsoluto = valor.abs();
  final factor = math.pow(10, decimales).toDouble();
  final escalado = valorAbsoluto * factor;
  final base = escalado.floorToDouble();
  final parteDecimal = escalado - base;

  double resultado;
  // Tolerancia pequeña porque los decimales no siempre se
  // representan de forma exacta en la computadora.
  const tolerancia = 1e-9;
  if ((parteDecimal - 0.5).abs() < tolerancia) {
    // Exactamente en la mitad: redondeamos al PAR más cercano.
    final baseEsPar = base.toInt().isEven;
    resultado = baseEsPar ? base : base + 1;
  } else {
    resultado = escalado.roundToDouble();
  }

  final valorFinal = resultado / factor;
  return esNegativo ? -valorFinal : valorFinal;
}