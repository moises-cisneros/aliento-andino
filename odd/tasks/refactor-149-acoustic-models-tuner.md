# Feature: Refactor Acoustic Models, Tuner and Unify Instrument Types (#149)

Tracking document for Issue #149 refactoring mobile acoustic models, fingerings, tuner and unifying InstrumentType.

## Specs

- S1: "Unificar enum Instrument en enum InstrumentType { quena, zampona, tarka } en todo apps/mobile."
- S2: "Sincronizar InstrumentService con ActiveInstrumentBloc y settings_screen.dart bajo la clave unificada active_instrument."
- S3: "Corregir QuenaFingering.forNote en fingering_models.dart: preservar {0, ...base.halfHoles} en segunda octava y corregir digitacion cruzada de Sol6."
- S4: "Ajustar la afinacion de Zampona Malta de 13 tubos (arcaNotes e iraNotes) e invertir la altura de tubos en zampona_fingering_widget.dart (graves mas largos, agudos mas cortos) con FittedBox."
- S5: "Extender TarkaFingering con Do6 y digitaciones de armonicos sobreinsuflados."
- S6: "En tuner_bloc.dart: Derivar notas andinas desde los modelos de digitacion, remover rango de quenacho (Sol3..Fa#4) e implementar desviacion en cents logaritmica: 1200 * log2(f / f_target)."
- S7: "Actualizar y ejecutar suite completa de tests en apps/mobile/test/."
- S8: "La conmutacion de instrumento en AppBar se refleja instantaneamente en afinador, lecciones y ajustes."
- S9: "El afinador responde en cents a la tesitura real de Quena (G4..G6), Zampona Malta (F#4..D6) y Tarka (C5..D6)."
- S10: "flutter test pasa al 100% con >= 75% de cobertura."

## Tasks

- [x] T1: Unificar enum Instrument en InstrumentType en todo apps/mobile | Route: direct-inline | Spec: S1 | Commit: 0ff6527
- [x] T2: Sincronizar InstrumentService y settings_screen con ActiveInstrumentBloc (clave active_instrument) | Route: direct-inline | Spec: S2, S8 | Commit: 0ff6527
- [x] T3: Corregir QuenaFingering.forNote (preservar halfHoles en 2da octava y digitación cruzada Sol6) | Route: direct-inline | Spec: S3, S9 | Commit: 0ff6527
- [x] T4: Ajustar afinación Zampoña Malta 13 tubos e invertir alturas con FittedBox en ZamponaFingeringWidget | Route: direct-inline | Spec: S4, S9 | Commit: 0ff6527
- [x] T5: Extender TarkaFingering con Do6 y armónicos sobreinsuflados | Route: direct-inline | Spec: S5, S9 | Commit: 0ff6527
- [x] T6: Derivar notas andinas en tuner_bloc.dart, remover quenacho e implementar desviación logarítmica en cents | Route: direct-inline | Spec: S6, S9 | Commit: 0ff6527
- [x] T7: Actualizar tests unitarios e integración en apps/mobile/test/ y validar análisis estático | Route: direct-inline | Spec: S7, S10 | Commit: 0ff6527

## Log

- L1: "Implementa la #149 usa odd de gentle-ai"
- L2: Implementación completa: unificación a InstrumentType, sincronización de InstrumentService y settings_screen con ActiveInstrumentBloc mediante clave active_instrument, corrección de digitaciones de Quena (Sol6 cruzado T 0 2 3 0 0 0 y preservación de halfHoles), Zampoña Malta de 13 tubos (F#4..D6) con alturas invertidas y FittedBox, Tarka (Do6 tara y Re6), TunerBloc con derivación directa de notas andinas y desviación logarítmica en cents. 407 pruebas en verde y flutter analyze con 0 errores/warnings. PR #155 abierta hacia main.
