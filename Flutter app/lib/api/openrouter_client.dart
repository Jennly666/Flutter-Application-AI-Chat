// lib/api/openrouter_client.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Клиент для работы с OpenRouter и VSEGPT.
///
/// Работает по переданному [apiKey] и [baseUrl], например:
///  - baseUrl = 'https://openrouter.ai/api/v1'
///  - baseUrl = 'https://api.vsetgpt.ru/v1'
class OpenRouterClient {
  final String apiKey;
  final String baseUrl;

  OpenRouterClient({
    required this.apiKey,
    required this.baseUrl,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        // Для OpenRouter желательно указывать Referer и X-Title,
        // но если не нужны — можно убрать.
        'HTTP-Referer': 'ai_chat_flutter',
        'X-Title': 'AIChatFlutter',
      };

  bool get _isVseGPT => baseUrl.contains('vsetgpt');
  bool get _isOpenRouter => baseUrl.contains('openrouter.ai');

  /// Получение списка моделей.
  /// Возвращает список Map с полями:
  ///   id, name, pricing, context_length
  Future<List<Map<String, dynamic>>> getModels() async {
    final url = Uri.parse('$baseUrl/models');
    final resp = await http.get(url, headers: _headers);

    if (resp.statusCode != 200) {
      debugPrint('getModels failed: ${resp.statusCode} ${resp.body}');
      throw Exception('Failed to load models: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);

    // У OpenRouter это обычно {"data": [ ...models... ]}
    final List data = (decoded['data'] ?? decoded['models'] ?? []) as List;

    return data.map<Map<String, dynamic>>((dynamic item) {
      final m = item as Map<String, dynamic>;
      return {
        'id': m['id'],
        'name': m['name'] ?? m['id'],
        'pricing': m['pricing'] ?? {}, // {prompt, completion}
        'context_length': m['context_length'] ??
            m['context'] ??
            0, // если поле называется иначе
      };
    }).toList();
  }

  /// Форматированный баланс для отображения в UI.
  Future<String> getBalance() async {
    final bal = await fetchBalance();
    if (bal < 0) return '—';

    if (_isVseGPT) {
      return '${bal.toStringAsFixed(3)}₽';
    } else {
      return '\$${bal.toStringAsFixed(3)}';
    }
  }

  /// Числовой баланс для логики (AuthService).
  ///
  /// Возвращает:
  ///  - >= 0 — валидный баланс (0 допустим — бесплатные модели и т.п.)
  ///  - < 0  — ошибка
  Future<double> fetchBalance() async {
    try {
      if (_isOpenRouter) {
        // OpenRouter: GET /user/balance
        final url = Uri.parse('$baseUrl/user/balance');
        final resp = await http.get(url, headers: _headers);

        if (resp.statusCode != 200) {
          debugPrint(
              'OpenRouter balance failed: ${resp.statusCode} ${resp.body}');
          return -1;
        }

        final decoded = jsonDecode(resp.body);
        // Обычно что-то вроде { "data": { "credits": "12.34" } }
        final creditsStr = decoded['data']?['credits']?.toString();
        if (creditsStr == null) return -1;
        return double.tryParse(creditsStr) ?? -1;
      } else {
        // VSEGPT: предположим, что есть endpoint /user/balance
        // и он возвращает { "balance": number } или { "data": { "balance": number } }
        final url = Uri.parse('$baseUrl/user/balance');
        final resp = await http.get(url, headers: _headers);

        if (resp.statusCode != 200) {
          debugPrint('VSEGPT balance failed: ${resp.statusCode} ${resp.body}');
          return -1;
        }

        final decoded = jsonDecode(resp.body);
        final raw = decoded['balance'] ?? decoded['data']?['balance'];
        if (raw == null) return -1;

        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString()) ?? -1;
      }
    } catch (e, st) {
      debugPrint('Error fetching balance: $e');
      debugPrint('$st');
      return -1;
    }
  }

  /// Отправка сообщения в модель.
  ///
  /// Возвращает JSON-ответ API (Map).
  /// В случае ошибки вернет {"error": "..."}.
  Future<Map<String, dynamic>> sendMessage(String content, String model) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': content,
        }
      ],
    });

    final resp = await http.post(url, headers: _headers, body: body);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      debugPrint('sendMessage failed: ${resp.statusCode} ${resp.body}');
      try {
        final decoded = jsonDecode(resp.body);
        return {
          'error': decoded['error'] ?? resp.body,
        };
      } catch (_) {
        return {
          'error': resp.body,
        };
      }
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decoded;
  }

  /// Форматирование стоимости токена/запроса для UI.
  ///
  /// В твоём коде в `ChatProvider` эта функция используется, чтобы
  /// красиво показать цену prompt/completion.
  String formatPricing(double pricing) {
    if (pricing == 0) return '—';

    // Предположим, что pricing — это цена за 1 токен.
    // Сконвертим в цену за 1K токенов, чтобы было понятнее.
    final perK = pricing * 1000;

    if (_isVseGPT) {
      return '${perK.toStringAsFixed(4)}₽ / 1K токенов';
    } else {
      return '\$${perK.toStringAsFixed(4)} / 1K tokens';
    }
  }
}
