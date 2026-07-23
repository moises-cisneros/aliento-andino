import 'package:flutter/widgets.dart';

/// Registro de elementos de UI que el agente tutor puede resaltar.
///
/// Los widgets registran una [GlobalKey] con un nombre (ej. 'save_post_button')
/// usando [keyFor]; el ejecutor de acciones busca ese elemento por nombre con
/// [lookup] para dibujar un spotlight sobre él. Si el elemento no está en
/// pantalla, el ejecutor cae a una pista flotante genérica.
class TutorTargets {
  TutorTargets._();

  static final Map<String, GlobalKey> _keys = {};

  /// Devuelve (creando si hace falta) la key estable asociada a [name].
  static GlobalKey keyFor(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey());

  /// Busca la key registrada para [name] (null si nadie la registró).
  static GlobalKey? lookup(String name) => _keys[name];
}
