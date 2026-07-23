import 'dart:io';

import 'package:dio/dio.dart';

/// Mensaje amable para mostrar cuando la falla es por falta de conexión.
const String offlineMessage = 'Necesitás conexión a internet para ver esto.';

/// `true` si el error es por falta de red (no un 4xx/5xx del servidor).
///
/// Sirve para distinguir "estás offline" de un error real del backend y
/// mostrar un estado amable en vez del `DioException` técnico.
bool isConnectionError(Object e) {
  if (e is SocketException) return true;
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return e.error is SocketException;
    }
  }
  return false;
}
