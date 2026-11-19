import 'package:shared_preferences/shared_preferences.dart';

import 'instrument.dart';

/// Persiste el instrumento elegido por el usuario (SharedPreferences), siguiendo
/// la clave unificada `active_instrument` compatible con [ActiveInstrumentBloc].
class InstrumentService {
  static const String key = 'active_instrument';
  static const InstrumentType defaultInstrument = InstrumentType.quena;

  Future<InstrumentType> get() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.get(key);
    if (raw is String && raw.trim().isNotEmpty) {
      final normalized = raw.trim().toLowerCase();
      for (final type in InstrumentType.values) {
        if (type.name.toLowerCase() == normalized) {
          return type;
        }
      }
    } else if (raw is int && raw >= 0 && raw < InstrumentType.values.length) {
      return InstrumentType.values[raw];
    }

    // Fallback adicional por clave heredada
    final synthRaw = p.get('synth_instrument');
    if (synthRaw is int &&
        synthRaw >= 0 &&
        synthRaw < InstrumentType.values.length) {
      return InstrumentType.values[synthRaw];
    } else if (synthRaw is String && synthRaw.trim().isNotEmpty) {
      final normalized = synthRaw.trim().toLowerCase();
      for (final type in InstrumentType.values) {
        if (type.name.toLowerCase() == normalized) {
          return type;
        }
      }
    }

    return defaultInstrument;
  }

  Future<void> set(InstrumentType v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, v.name);
  }
}
