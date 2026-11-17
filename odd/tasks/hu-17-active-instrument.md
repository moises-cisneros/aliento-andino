# Feature: HU-17 Conmutación Dinámica de Instrumento Activo en Tiempo Real

Parent Issue: #56 | Sprint 1 | Delivery: one branch + PR per sub-issue (SUB-17-A #57)
Test runners: Flutter (`flutter test`, `flutter analyze`)

## Specs

S1: "Como usuario con varios instrumentos andinos, quiero cambiar el instrumento activo (Quena, Zampoña o Tarka) desde la barra superior o mi perfil con un solo toque, para que el afinador cromático, la guía de digitación y las lecciones se adapten automáticamente en tiempo real."
S2: "Componente selector en el AppBar accesible en toda la navegación principal."
S3: "Emisión de estado reactivo mediante BLoC que reconfigura instantáneamente digigramas, notas toleradas y frecuencias esperadas."
S4: "Persistencia local inmediata de la última elección del usuario."
S5: "Implementar `ActiveInstrumentBloc` en Flutter para gestionar el estado del instrumento seleccionado y emitir cambios a los listeners de toda la app. Archivos: `apps/mobile/lib/features/instrument_select/bloc/active_instrument_bloc.dart`, `apps/mobile/lib/features/instrument_select/presentation/widgets/instrument_selector_appbar.dart`."
S6: "Contratos Técnicos: Evento: `SelectInstrumentEvent(InstrumentType instrument)`. Estado: `ActiveInstrumentState(InstrumentType activeInstrument)`. Persistencia: Guardar clave `active_instrument` en SharedPreferences."
S7: "Manejo de Errores: Selección nula o corrupta en almacenamiento: Fallback predeterminado a `InstrumentType.quena`."
S8: "Pruebas Obligatorias: Unitaria: `active_instrument_bloc_test.dart` verificando transiciones `quena` -> `zampona` -> `tarka`. Integración: Re-renderizado de widget de digitación al cambiar el estado del BLoC. E2E: Cambio de instrumento en AppBar y comprobación de cambio de frecuencias en afinador. Suites de pruebas pasando con 0 errores y cobertura mínima requerida."

## Tasks

- [x] T1 (S1-S8) [inline]: Mobile — `ActiveInstrumentBloc`, `InstrumentSelectorAppBar` y `InstrumentSelectorAction`, persistencia SharedPreferences con fallback a quena, sincronización reactiva con afinador y widget de digitación adaptativo, pruebas unitarias, de integración y E2E (#57 SUB-17-A) — Branch `feat/57-active-instrument-bloc`

## Log

L1: "Implementa las subissues de la issue #56 (HU-17), realizalo con ODD, en un propio git worktree."
L2: Verification mobile: `flutter analyze` 0 issues (No issues found!), `dart format --output=none --set-exit-if-changed .` clean, `flutter test test/features/instrument_select/` 9 passed (unit, integration, and E2E suites), `flutter test test/features/tuner/tuner_bloc_test.dart` 5 passed.
