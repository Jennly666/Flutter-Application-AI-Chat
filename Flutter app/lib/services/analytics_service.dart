// lib/services/analytics_service.dart

import 'package:flutter/foundation.dart';

// Сервис для сбора и анализа статистики использования чата
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  final DateTime _startTime;
  final Map<String, Map<String, int>> _modelUsage = {};
  final List<Map<String, dynamic>> _sessionData = [];

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal() : _startTime = DateTime.now();

  void trackMessage({
    required String model,
    required int messageLength,
    required double responseTime,
    required int tokensUsed,
  }) {
    try {
      _modelUsage[model] ??= {
        'count': 0,
        'tokens': 0,
      };

      _modelUsage[model]!['count'] = (_modelUsage[model]!['count'] ?? 0) + 1;
      _modelUsage[model]!['tokens'] =
          (_modelUsage[model]!['tokens'] ?? 0) + tokensUsed;

      _sessionData.add({
        'timestamp': DateTime.now().toIso8601String(),
        'model': model,
        'message_length': messageLength,
        'response_time': responseTime,
        'tokens_used': tokensUsed,
      });
    } catch (e) {
      debugPrint('Error tracking message: $e');
    }
  }

  Map<String, dynamic> getStatistics() {
    try {
      final now = DateTime.now();
      final sessionDuration = now.difference(_startTime).inSeconds;

      int totalMessages = 0;
      int totalTokens = 0;

      for (final modelStats in _modelUsage.values) {
        totalMessages += modelStats['count'] ?? 0;
        totalTokens += modelStats['tokens'] ?? 0;
      }

      final messagesPerMinute =
          sessionDuration > 0 ? (totalMessages * 60) / sessionDuration : 0.0;
      final tokensPerMessage =
          totalMessages > 0 ? totalTokens / totalMessages : 0.0;

      return {
        'total_messages': totalMessages,
        'total_tokens': totalTokens,
        'session_duration': sessionDuration,
        'messages_per_minute': messagesPerMinute,
        'tokens_per_message': tokensPerMessage,
        'model_usage': _modelUsage,
        'start_time': _startTime.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  List<Map<String, dynamic>> exportSessionData() {
    return List.from(_sessionData);
  }

  void clearData() {
    _modelUsage.clear();
    _sessionData.clear();
  }

  Map<String, double> getModelEfficiency() {
    final efficiency = <String, double>{};

    for (final entry in _modelUsage.entries) {
      final modelId = entry.key;
      final stats = entry.value;
      final messageCount = stats['count'] ?? 0;
      final tokensUsed = stats['tokens'] ?? 0;

      if (messageCount > 0) {
        efficiency[modelId] = tokensUsed / messageCount;
      }
    }

    return efficiency;
  }

  Map<String, dynamic> getResponseTimeStats() {
    if (_sessionData.isEmpty) return {};

    final responseTimes =
        _sessionData.map((data) => data['response_time'] as double).toList();

    responseTimes.sort();
    final count = responseTimes.length;

    return {
      'average': responseTimes.reduce((a, b) => a + b) / count,
      'median': count.isOdd
          ? responseTimes[count ~/ 2]
          : (responseTimes[(count - 1) ~/ 2] + responseTimes[count ~/ 2]) / 2,
      'min': responseTimes.first,
      'max': responseTimes.last,
    };
  }

  Map<String, dynamic> getMessageLengthStats() {
    if (_sessionData.isEmpty) return {};

    final lengths =
        _sessionData.map((data) => data['message_length'] as int).toList();

    final count = lengths.length;
    final total = lengths.reduce((a, b) => a + b);

    return {
      'average_length': total / count,
      'total_characters': total,
      'message_count': count,
    };
  }
}
