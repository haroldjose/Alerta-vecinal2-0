import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/report_model.dart';
import '../../widgets/ai_problem_suggestion_widget.dart';

// encapsula si el texto es ofensivo
class OffensiveContentResult {

  final bool isOffensive;
  final List<String> offensiveWords;

  const OffensiveContentResult({
    required this.isOffensive,
    this.offensiveWords = const [],
  });

  const OffensiveContentResult.clean()
      : isOffensive = false,
        offensiveWords = const [];

  String get formattedWords {
    if (offensiveWords.isEmpty) return 'contenido inapropiado';
    return offensiveWords.map((w) => '"$w"').join(', ');
  }
}



class AiSuggestionService {
  //sugerencias
  static const String _functionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/suggestProblemType';
  
  // lenguaje ofensivo
  static const String _offensiveFunctionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/checkOffensiveContent';    


  // Llama a la Cloud Function y devuelve una [AiSuggestion] o null si falla.
  Future<AiSuggestion?> getSuggestion({
    required String title,
    required String description,
  }) async {
    // No llamar si no hay suficiente texto
    final combinedLength = title.trim().length + description.trim().length;
    if (combinedLength < 5) return null;

    try {
      final response = await http
          .post(
            Uri.parse(_functionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'title': title, 'description': description}),
          )
          .timeout(const Duration(seconds: 45)); 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Parsear el tipo de problema desde el string devuelto
        final suggestionStr = data['suggestion'] as String? ?? '';
        final problemType = ProblemTypeExtension.fromString(suggestionStr);

        return AiSuggestion(
          problemType: problemType,
          confidence: data['confidence'] as String? ?? 'baja',
          reason: data['reason'] as String? ?? '',
        );
      } else {
         print('[AiSuggestionService] Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[AiSuggestionService] Excepción: $e');
      return null;
    }
  }


  // chequea el lenguaje ofensivo
  Future<OffensiveContentResult> checkOffensiveContent({
    required String title,
    required String description,
  }) async {
    final combinedText = '${title.trim()} ${description.trim()}'.trim();
    if (combinedText.length < 2) {
      print('[checkOffensive] Texto demasiado corto, saltando.');  // 
      return const OffensiveContentResult.clean();
    }

     // LOG DIAGNÓSTICO
    print('[checkOffensive] ▶ Llamando a Cloud Function...');
    print('[checkOffensive]   URL: $_offensiveFunctionUrl');
    print('[checkOffensive]   title="$title"');
    print('[checkOffensive]   description="$description"');

    try {
      final response = await http
          .post(
            Uri.parse(_offensiveFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'title': title, 'description': description}),
          )
          .timeout(const Duration(seconds: 30));

          // LOG DIAGNÓSTICO
      print('[checkOffensive] ◀ statusCode: ${response.statusCode}');
      print('[checkOffensive] ◀ body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isOffensive = data['isOffensive'] as bool? ?? false;

        if (!isOffensive) return const OffensiveContentResult.clean();
  
        final rawWords = data['offensiveWords'];
        final List<String> words = rawWords is List
            ? rawWords.map((w) => w.toString()).toList()
            : [];

        return OffensiveContentResult(
          isOffensive: true,
          offensiveWords: words,
        );
      } else {
        print('[AiSuggestionService] checkOffensive error ${response.statusCode}');
        // Ante error HTTP, no bloqueamos al usuario
        return const OffensiveContentResult.clean();
      }
    } catch (e) {
      print('[AiSuggestionService] Excepción checkOffensive: $e');
      // Ante excepción (timeout, sin red), no bloqueamos al usuario
      return const OffensiveContentResult.clean();
    }
  }
}
