import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenRouterChatMessage {
  final String role;
  final String content;

  const OpenRouterChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class OpenRouterClientResult {
  final String content;
  final String? model;
  final Map<String, dynamic> raw;

  const OpenRouterClientResult({
    required this.content,
    required this.raw,
    this.model,
  });
}

class OpenRouterClient {
  OpenRouterClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://openrouter.ai/api/v1';

  final http.Client _httpClient;
  final String _baseUrl;

  Future<OpenRouterClientResult> createJsonCompletion({
    required String apiKey,
    required String model,
    required List<OpenRouterChatMessage> messages,
    required Map<String, dynamic> jsonSchema,
    double temperature = 0.3,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final payload = <String, dynamic>{
      'model': model,
      'temperature': temperature,
      'messages': messages.map((item) => item.toMap()).toList(),
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'ai_coach_weekly_plan',
          'strict': true,
          'schema': jsonSchema,
        },
      },
    };

    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    if (!kIsWeb) {
      headers['HTTP-Referer'] = 'https://runninglaps.app';
      headers['X-Title'] = 'Running Laps';
    }

    final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[OpenRouterClient] request error: $e');
      throw Exception('No se pudo conectar con OpenRouter: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[OpenRouterClient] error ${response.statusCode}: ${response.body}');
      throw Exception(_buildErrorMessage(response.statusCode, response.body));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('OpenRouter sin choices');
    }

    final firstChoice = Map<String, dynamic>.from(choices.first as Map);
    final message =
        Map<String, dynamic>.from(firstChoice['message'] as Map? ?? const {});
    final contentValue = message['content'];
    final content = contentValue is String
        ? contentValue
        : contentValue is List
            ? contentValue
                .map((item) => item is Map<String, dynamic> ? item['text'] : '')
                .join()
            : '';

    if (content.trim().isEmpty) {
      throw Exception('OpenRouter devolvio contenido vacio');
    }

    return OpenRouterClientResult(
      content: content,
      raw: decoded,
      model: decoded['model'] as String?,
    );
  }

  String _buildErrorMessage(int statusCode, String rawBody) {
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return 'OpenRouter error $statusCode: $message';
        }
      }
    } catch (_) {}
    return 'OpenRouter error $statusCode';
  }
}
