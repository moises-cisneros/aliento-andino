import 'package:shared_preferences/shared_preferences.dart';

import 'instrument.dart';

/// Persiste el instrumento elegido por el usuario (SharedPreferences), siguiendo
/// el patrón de servicio-por-feature del resto de la app (ej. DailyGoalService).
class InstrumentService {
  static const _key = 'synth_instrument';
  static const Instrument defaultInstrument = Instrument.piano;

  Future<Instrument> get() async {
    final p = await SharedPreferences.getInstance();
    final i = p.getInt(_key);
    if (i != null && i >= 0 && i < Instrument.values.length) {
      return Instrument.values[i];
    }
    return defaultInstrument;
  }

  Future<void> set(Instrument v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key, v.index);
  }
}
