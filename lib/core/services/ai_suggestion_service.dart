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

// Encapsula el resultado de la detección de reportes duplicados.

class DuplicateCheckResult {
  final bool isDuplicate;
  final SimilarReportData? similarReport;

  const DuplicateCheckResult({
    required this.isDuplicate,
    this.similarReport,
  });


  const DuplicateCheckResult.noDuplicate()
      : isDuplicate = false,
        similarReport = null;
}

// Datos del reporte similar devuelto por la Cloud Function.
class SimilarReportData {
  final String id;
  final String title;
  final String description;
  final String problemType;
  final String createdAt;
  final String userName;
  final String status;
  final int similarity; 

  const SimilarReportData({
    required this.id,
    required this.title,
    required this.description,
    required this.problemType,
    required this.createdAt,
    required this.userName,
    required this.status,
    required this.similarity,
  });

  factory SimilarReportData.fromMap(Map<String, dynamic> map) {
    return SimilarReportData(
      id:          map['id']          as String? ?? '',
      title:       map['title']       as String? ?? '',
      description: map['description'] as String? ?? '',
      problemType: map['problemType'] as String? ?? '',
      createdAt:   map['createdAt']   as String? ?? '',
      userName:    map['userName']    as String? ?? 'Usuario',
      status:      map['status']      as String? ?? 'pendiente',
      similarity:  (map['similarity'] as num?)?.toInt() ?? 0,
    );
  }
}




class AiSuggestionService {
  //sugerencias
  static const String _functionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/suggestProblemType';
  
  // lenguaje ofensivo
  static const String _offensiveFunctionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/checkOffensiveContent';    

  // duplicado
   static const String _duplicateFunctionUrl =
      'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net/checkDuplicateReport';    


  // Llama a la Cloud Function y devuelve una [AiSuggestion] o null si falla.
  Future<AiSuggestion?> getSuggestion({
    required String title,
    required String description,
  }) async {
    
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

    print('[checkOffensive] Llamando a Cloud Function...');
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

          
      print('[checkOffensive] statusCode: ${response.statusCode}');
      print('[checkOffensive] body: ${response.body}');

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

  // Verifica si el reporte que se está creando o editando es similar a alguno de los últimos 48 horas en Firestore.
  Future<DuplicateCheckResult> checkDuplicateReport({
    required String title,
    required String description,
    LocationData? location,
    String? excludeReportId,
  }) async {
    final combinedText = '${title.trim()} ${description.trim()}'.trim();
    if (combinedText.length < 5) {
      return const DuplicateCheckResult.noDuplicate();
    }

    print('[checkDuplicate] Verificando duplicados...');
    print('[checkDuplicate]   Título: "$title"');

    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
      };

      if (location != null) {
        body['location'] = {
          'latitude':  location.latitude,
          'longitude': location.longitude,
        };
      }

      if (excludeReportId != null) {
        body['excludeReportId'] = excludeReportId;
      }

      final response = await http
          .post(
            Uri.parse(_duplicateFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 50));

      print('[checkDuplicate] Status: ${response.statusCode}');
      print('[checkDuplicate] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isDuplicate = data['isDuplicate'] as bool? ?? false;

        if (!isDuplicate) return const DuplicateCheckResult.noDuplicate();

        // Parsear los datos del reporte similar
        final similarMap = data['similarReport'] as Map<String, dynamic>?;
        final similarReport =
            similarMap != null ? SimilarReportData.fromMap(similarMap) : null;

        return DuplicateCheckResult(
          isDuplicate: true,
          similarReport: similarReport,
        );
      } else {
        print('[checkDuplicate] Error HTTP ${response.statusCode}');
        return const DuplicateCheckResult.noDuplicate();
      }
    } catch (e) {
      print('[checkDuplicate] Excepción: $e');
      // Ante cualquier error (timeout, sin red) no bloqueamos al usuario
      return const DuplicateCheckResult.noDuplicate();
    }
  }



}
