// test/redondeo_bancario_test.dart
//
// Prueba automatizada del redondeo bancario (al par más cercano),
// usado para los montos de la tarjeta kardex.
//
// Para correr: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/utils/redondeo_bancario.dart';

void main() {
  test('Redondea normalmente cuando NO está exactamente en la mitad', () {
    // Menor a 5 en la posición siguiente: baja.
    expect(redondearBancario(10.121, 2), closeTo(10.12, 0.0001));
    // Mayor a 5: sube.
    expect(redondearBancario(10.129, 2), closeTo(10.13, 0.0001));
    expect(redondearBancario(10.126, 2), closeTo(10.13, 0.0001));
    expect(redondearBancario(10.124, 2), closeTo(10.12, 0.0001));
  });

  test('Exactamente en la mitad (.5): redondea al PAR más cercano', () {
    // 10.12(5): el dígito antes del 5 es "2" (par) → se queda igual.
    expect(redondearBancario(10.125, 2), closeTo(10.12, 0.0001));
    // 10.13(5): el dígito antes del 5 es "3" (impar) → sube a "4".
    expect(redondearBancario(10.135, 2), closeTo(10.14, 0.0001));
    // 10.10(5): "0" es par → se queda igual.
    expect(redondearBancario(10.105, 2), closeTo(10.10, 0.0001));
    // 10.11(5): "1" es impar → sube a "2".
    expect(redondearBancario(10.115, 2), closeTo(10.12, 0.0001));
  });

  test('Funciona igual con números negativos', () {
    expect(redondearBancario(-10.125, 2), closeTo(-10.12, 0.0001));
    expect(redondearBancario(-10.135, 2), closeTo(-10.14, 0.0001));
  });

  test('Funciona con distintas cantidades de decimales', () {
    // Redondear a 0 decimales: 2.5 → 2 (par), 3.5 → 4 (impar sube).
    expect(redondearBancario(2.5, 0), closeTo(2.0, 0.0001));
    expect(redondearBancario(3.5, 0), closeTo(4.0, 0.0001));
  });
}