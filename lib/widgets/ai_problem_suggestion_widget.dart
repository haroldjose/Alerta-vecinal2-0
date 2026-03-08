import 'package:flutter/material.dart';
import '../core/constants/colors.dart';
import '../models/report_model.dart';

// Estado de la sugerencia de IA
enum AiSuggestionState {
  idle,       
  loading,   
  success,    
  error,      
}

// Modelo que representa una sugerencia de la IA
class AiSuggestion {
  final ProblemType problemType;
  final String confidence; 
  final String reason;

  const AiSuggestion({
    required this.problemType,
    required this.confidence,
    required this.reason,
  });
}

// Widget que muestra el banner de sugerencia de tipo de problema por IA.
class AiProblemSuggestionWidget extends StatelessWidget {
  final AiSuggestionState state;
  final AiSuggestion? suggestion;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;

  const AiProblemSuggestionWidget({
    super.key,
    required this.state,
    this.suggestion,
    this.onAccept,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (state == AiSuggestionState.idle) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (state) {
      case AiSuggestionState.loading:
        return _buildLoadingBanner();
      case AiSuggestionState.success:
        if (suggestion == null) return const SizedBox.shrink();
        return _buildSuggestionBanner(context);
      case AiSuggestionState.error:
        return _buildErrorBanner();
      case AiSuggestionState.idle:
        return const SizedBox.shrink();
    }
  }

  // Banner de carga mientras la IA analiza el texto
  Widget _buildLoadingBanner() {
    return Container(
      key: const ValueKey('loading'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'La IA está analizando el tipo de problema...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Banner con la sugerencia de tipo de problema
  Widget _buildSuggestionBanner(BuildContext context) {
    final sug = suggestion!;
    final typeColor = Color(sug.problemType.borderColor);

    return Container(
      key: const ValueKey('suggestion'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: typeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sugerencia de IA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
              _buildConfidenceBadge(sug.confidence, typeColor),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeColor),
                ),
                child: Text(
                  sug.problemType.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            sug.reason,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aplicar sugerencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: typeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Badge de nivel de confianza
  Widget _buildConfidenceBadge(String confidence, Color typeColor) {
    Color badgeColor;
    String label;
    switch (confidence) {
      case 'alta':
        badgeColor = AppColors.success;
        label = '● Alta confianza';
        break;
      case 'media':
        badgeColor = const Color(0xFFD69E2E);
        label = '● Media confianza';
        break;
      default:
        badgeColor = Colors.grey;
        label = '● Baja confianza';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: badgeColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Banner de error discreto
  Widget _buildErrorBanner() {
    return Container(
      key: const ValueKey('error'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudo obtener sugerencia de IA. Selecciona el tipo manualmente.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
