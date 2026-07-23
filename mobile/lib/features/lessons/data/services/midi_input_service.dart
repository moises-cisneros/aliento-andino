import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:permission_handler/permission_handler.dart';

/// Un evento de tecla pulsada recibido por MIDI.
class MidiNoteEvent {
  final int midi; // número MIDI (ej. 69 = A4)
  final String note; // nombre con sostenidos, ej. "A4"
  final int velocity; // 1..127 (dinámica)
  const MidiNoteEvent(this.midi, this.note, this.velocity);
}

const _noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

/// Convierte un número MIDI (0..127) a nombre con octava. Ej: 69 → "A4".
String midiNumberToName(int n) => '${_noteNames[n % 12]}${n ~/ 12 - 1}';

/// Parsea "C4", "F#5", "Bb3" → número MIDI. Retorna null si no parsea.
/// Inverso aproximado de [midiNumberToName] (los enarmónicos colapsan al mismo
/// número, ej. "Bb3" y "A#3" → 58).
int? noteNameToMidi(String note) {
  final m = RegExp(r'^([A-G])([#b]?)(\d+)').firstMatch(note);
  if (m == null) return null;
  final letter = m.group(1)!;
  final accidental = m.group(2)!;
  final octave = int.parse(m.group(3)!);
  const letterToSemi = {
    'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11,
  };
  var semi = letterToSemi[letter]!;
  if (accidental == '#') semi++;
  if (accidental == 'b') semi--;
  return (octave + 1) * 12 + semi;
}

/// Servicio de **entrada MIDI** (USB / Bluetooth LE) sobre `flutter_midi_command`.
///
/// Es la fuente de **máxima precisión**: a diferencia del micrófono, recibe el
/// evento digital exacto (note-on, nota, velocity) sin inferir del sonido.
/// Convierte los note-on entrantes en [MidiNoteEvent] y expone el dispositivo
/// conectado para la UI. Auto-conecta al primer teclado disponible (USB ya
/// enchufado o BLE escaneado) y reacciona a cambios de conexión.
class MidiInputService {
  final MidiCommand _midi = MidiCommand();
  StreamSubscription<MidiPacket>? _rxSub;
  StreamSubscription<String>? _setupSub;

  final _notes = StreamController<MidiNoteEvent>.broadcast();

  /// Dispositivo MIDI conectado actualmente (null = buscando / ninguno).
  final ValueNotifier<MidiDevice?> connected = ValueNotifier(null);

  /// Estado del pedal de sustain (Control Change 64). true = pedal pisado.
  final ValueNotifier<bool> sustainOn = ValueNotifier(false);

  /// Stream de teclas pulsadas (solo note-on con velocity > 0).
  Stream<MidiNoteEvent> get noteOnStream => _notes.stream;

  /// Empieza a escuchar y trata de conectar el primer teclado disponible.
  Future<void> start() async {
    _rxSub = _midi.onMidiDataReceived?.listen(_onData);
    // Reconectar si se enchufa/desenchufa un dispositivo.
    _setupSub = _midi.onMidiSetupChanged?.listen((_) => _autoConnect());
    // Permisos BLE (Android 12+): sin esto el escaneo no encuentra teclados
    // inalámbricos. USB no los necesita. En iOS dispara el prompt del sistema.
    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    } catch (_) {}
    // Escaneo BLE (no falla si el dispositivo no tiene Bluetooth).
    try {
      await _midi.startBluetoothCentral();
      await _midi.startScanningForBluetoothDevices();
    } catch (_) {}
    await _autoConnect();
  }

  Future<void> _autoConnect() async {
    if (connected.value != null) return;
    final devices = await _midi.devices;
    if (devices == null || devices.isEmpty) return;
    final dev = devices.firstWhere(
      (d) => !d.connected,
      orElse: () => devices.first,
    );
    try {
      await _midi.connectToDevice(dev);
      connected.value = dev;
    } catch (_) {}
  }

  void _onData(MidiPacket packet) {
    final data = packet.data;
    if (data.length < 3) return;
    final status = data[0] & 0xF0;
    if (status == 0x90) {
      final velocity = data[2];
      if (velocity == 0) return; // note-on con velocity 0 == note-off
      final n = data[1];
      _notes.add(MidiNoteEvent(n, midiNumberToName(n), velocity));
    } else if (status == 0xB0 && data[1] == 64) {
      // Control Change 64 = pedal de sustain (>=64 pisado).
      sustainOn.value = data[2] >= 64;
    }
  }

  void dispose() {
    _rxSub?.cancel();
    _setupSub?.cancel();
    final d = connected.value;
    if (d != null) {
      try {
        _midi.disconnectDevice(d);
      } catch (_) {}
    }
    try {
      _midi.stopScanningForBluetoothDevices();
    } catch (_) {}
    _notes.close();
    connected.dispose();
    sustainOn.dispose();
  }
}
