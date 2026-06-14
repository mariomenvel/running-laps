import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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
  OpenRouterClient({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<OpenRouterClientResult> createJsonCompletion({
    required String model,
    required List<OpenRouterChatMessage> messages,
    required Map<String, dynamic> jsonSchema,
    double temperature = 0.3,
    String? schemaName,
  }) async {
    final callable = _functions.httpsCallable(
      'callOpenRouter',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    try {
      final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'model': model,
        'messages': messages.map((m) => m.toMap()).toList(),
        'jsonSchema': jsonSchema,
        'temperature': temperature,
        if (schemaName != null) 'schemaName': schemaName,
      });

      final data = Map<String, dynamic>.from(result.data);
      final content = data['content'] as String? ?? '';
      if (content.trim().isEmpty) {
        throw Exception('La IA devolvió una respuesta vacía.');
      }
      final rawMap = data['raw'];
      return OpenRouterClientResult(
        content: content,
        model: data['model'] as String?,
        raw: rawMap is Map ? Map<String, dynamic>.from(rawMap) : const {},
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[OpenRouterClient] function error: ${e.code} ${e.message}');
      throw Exception(e.message ?? 'Error al contactar con el coach IA.');
    }
  }
}
