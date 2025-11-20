// lib/services/auth_service.dart

import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:ai_chat_flutter/models/auth_info.dart';
import 'package:ai_chat_flutter/services/database_service.dart';

class AuthService {
  final DatabaseService _db;

  AuthService(this._db);

  /// Определяем провайдера по префиксу ключа.
  /// - OpenRouter: sk-or-v1-...
  /// - VSEGPT:    sk-or-vv-...
  ApiProvider detectProvider(String apiKey) {
    if (apiKey.startsWith('sk-or-v1-')) {
      return ApiProvider.openRouter;
    } else if (apiKey.startsWith('sk-or-vv-')) {
      return ApiProvider.vseGPT;
    } else {
      throw Exception(
        'Неизвестный тип ключа.\n'
        'Ожидался ключ вида sk-or-v1-... (OpenRouter) или sk-or-vv-... (VSEGPT).',
      );
    }
  }

  /// Генерация 4-значного PIN.
  String _generatePin() {
    final rnd = Random.secure().nextInt(10000);
    return rnd.toString().padLeft(4, '0');
  }

  /// SHA-256 хэш PIN-кода.
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<AuthInfo?> getSavedAuth() => _db.getAuthInfo();

  Future<void> clearAuth() => _db.clearAuthInfo();

  /// Попытка получить "баланс" / лимит по ключу.
  ///
  /// Возвращает:
  ///   - число >= 0  → баланс/лимит, ключ валиден
  ///   - -1          → API явно отверг ключ (401/403)
  ///   - null        → не получилось корректно прочитать баланс
  ///                    (любой другой код, формат, сеть и т.п.)
  Future<double?> _tryFetchBalance(
    String apiKey,
    ApiProvider provider,
  ) async {
    try {
      if (provider == ApiProvider.openRouter) {
        final uri = Uri.parse('https://openrouter.ai/api/v1/key');
        final resp = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ai-chat-flutter.local',
            'X-Title': 'AIChatFlutter',
          },
        );

        // Явное отклонение ключа
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          return -1;
        }

        // Любой не-успешный код, но не 401/403 — считаем, что баланс получить не удалось,
        // но ключ, возможно, всё равно валиден (сеть, временная ошибка и т.д.).
        if (resp.statusCode != 200) {
          return null;
        }

        final data = jsonDecode(resp.body);
        final info = data['data'];

        final remaining = info?['limit_remaining'];

        if (remaining == null) {
          // Ключ валиден, но лимит не указан / безлимит.
          return 0;
        }

        if (remaining is num) {
          return remaining.toDouble();
        }

        return double.tryParse(remaining.toString());
      } else {
        // VSEGPT — посылаем запрос на /user/balance.
        final uri = Uri.parse('https://api.vsetgpt.ru/v1/user/balance');
        final resp = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        );

        if (resp.statusCode == 401 || resp.statusCode == 403) {
          return -1;
        }

        if (resp.statusCode != 200) {
          return null;
        }

        final data = jsonDecode(resp.body);

        final raw = data['balance'] ??
            data['data']?['balance'] ??
            data['data']?['amount'];

        if (raw == null) {
          return 0;
        }

        if (raw is num) {
          return raw.toDouble();
        }

        return double.tryParse(raw.toString());
      }
    } catch (_) {
      // Любая ошибка → не смогли получить баланс, но не считаем ключ заведомо неверным.
      return null;
    }
  }

  /// Основной метод: проверяем ключ, если он не отклонён API (401/403),
  /// генерируем PIN и сохраняем auth-запись в БД.
  ///
  /// ВАЖНО:
  ///   - balance >= 0      → валидный ключ (включая 0 и бесплатные / безлимитные тарифы).
  ///   - balance == null   → не удалось прочитать баланс, но ключ по виду ок → всё равно пропускаем.
  ///   - balance == -1     → API явно сказал 401/403 → кидаем ошибку.
  Future<String> setupApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw Exception('Ключ пустой');
    }

    final provider = detectProvider(trimmed);

    final balance = await _tryFetchBalance(trimmed, provider);

    // Явное отклонение ключа
    if (balance == -1) {
      throw Exception(
        'API отклонил ключ (401/403).\n'
        'Проверьте, правильно ли введён ключ и активен ли он.',
      );
    }

    // Все остальные случаи (>=0 или null) считаем допустимыми:
    // - >=0 → есть числовой лимит/баланс, всё ок;
    // - null → не смогли прочитать баланс, но не мешаем пользователю.

    final pin = _generatePin();
    final pinHash = _hashPin(pin);

    final info = AuthInfo(
      id: 0,
      apiKey: trimmed,
      provider: provider,
      pinHash: pinHash,
      createdAt: DateTime.now(),
    );

    await _db.saveAuthInfo(info);
    return pin;
  }

  /// Проверка PIN при входе.
  Future<bool> verifyPin(String pin) async {
    final auth = await getSavedAuth();
    if (auth == null) return false;

    final pinHash = _hashPin(pin.trim());
    return auth.pinHash == pinHash;
  }
}
