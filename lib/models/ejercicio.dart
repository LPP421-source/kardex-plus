// lib/models/ejercicio.dart
//
// Este archivo define qué es un "Ejercicio" dentro de la app.
// Un Ejercicio es un caso de práctica: por ejemplo,
// "Ejercicio 1 - Compraventa de laptops", con un método de
// valuación asignado (PEPS, UEPS o CPP).

/// Los tres métodos de valuación de inventarios que la app va a manejar.
///
/// Nota académica: bajo NIIF/NIC 2, el método UEPS (LIFO) está
/// prohibido para reportes financieros oficiales. Lo incluimos aquí
/// solo con fines educativos/comparativos.
enum MetodoValuacion {
  peps, // Primero en Entrar, Primero en Salir (FIFO)
  ueps, // Último en Entrar, Primero en Salir (LIFO)
  cpp, // Costo Promedio Ponderado
}

/// Función auxiliar para mostrar el nombre completo y legible
/// de cada método en la interfaz (en vez de mostrar "peps" a secas).
extension MetodoValuacionNombre on MetodoValuacion {
  String get nombreCompleto {
    switch (this) {
      case MetodoValuacion.peps:
        return 'PEPS (Primero en Entrar, Primero en Salir)';
      case MetodoValuacion.ueps:
        return 'UEPS (Último en Entrar, Primero en Salir)';
      case MetodoValuacion.cpp:
        return 'CPP (Costo Promedio Ponderado)';
    }
  }
}

/// Representa un ejercicio de práctica creado por el estudiante.
class Ejercicio {
  /// Identificador único. Cuando lo traigamos de Supabase será un
  /// UUID (texto). Mientras no esté guardado, puede ser null.
  final String? id;

  /// Nombre corto del ejercicio, ej: "Ejercicio 1"
  final String nombre;

  /// Nombre de la empresa del caso práctico, ej: "Distribuidora
  /// Santa Cruz S.A." Es un campo de texto libre (no un id único),
  /// así que varios ejercicios pueden compartir la misma empresa
  /// sin ningún problema — solo es información descriptiva.
  final String? empresa;

  /// Descripción opcional con el contexto del caso.
  final String? descripcion;

  /// Método de valuación asignado a este ejercicio.
  final MetodoValuacion metodo;

  /// Cuántos decimales se muestran en la columna "Costo Unitario"
  /// de este ejercicio en particular. Vive aquí (no como ajuste
  /// global de la app) porque distintos ejercicios pueden necesitar
  /// distinta precisión — por ejemplo, CPP suele generar costos con
  /// muchos decimales, mientras que un ejercicio simple puede
  /// bastarle con 2. Los montos totales (Bs) SIEMPRE se muestran a
  /// 2 decimales, sin importar este valor.
  final int decimalesCosto;

  /// Fecha en que se creó el ejercicio (para ordenarlos en la lista).
  final DateTime fechaCreacion;

  Ejercicio({
    this.id,
    required this.nombre,
    this.empresa,
    this.descripcion,
    required this.metodo,
    this.decimalesCosto = 2,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  /// Convierte este objeto Dart a un Map, que es el formato que
  /// Supabase espera para guardar una fila en la base de datos.
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'empresa': empresa,
      'descripcion': descripcion,
      'metodo': metodo.name, // guarda "peps", "ueps" o "cpp" como texto
      'decimales_costo': decimalesCosto,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  /// Hace lo contrario: toma una fila que viene de Supabase (Map)
  /// y construye un objeto Ejercicio de Dart a partir de ella.
  factory Ejercicio.fromMap(Map<String, dynamic> map) {
    return Ejercicio(
      id: map['id'] as String?,
      nombre: map['nombre'] as String,
      empresa: map['empresa'] as String?,
      descripcion: map['descripcion'] as String?,
      metodo: MetodoValuacion.values.byName(map['metodo'] as String),
      decimalesCosto: (map['decimales_costo'] as num?)?.toInt() ?? 2,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
    );
  }
}