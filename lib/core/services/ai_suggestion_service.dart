import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/report_model.dart';
import '../../widgets/ai_problem_suggestion_widget.dart';

class AiSuggestionService {
  static const String _functionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/suggestProblemType';

  /// Llama a la Cloud Function y devuelve una [AiSuggestion] o null si falla.
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
}
