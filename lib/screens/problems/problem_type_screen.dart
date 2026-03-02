import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/report_model.dart';
import '../../core/constants/colors.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/report_card.dart';
import '../../widgets/custom_button.dart';
import '../reports/create_report_screen.dart';

class ProblemTypeScreen extends ConsumerWidget {
  final ProblemType problemType;

  const ProblemTypeScreen({
    super.key,
    required this.problemType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsByTypeProvider(problemType));

    ref.listen<AsyncValue<void>>(createReportProvider, (previous, next) {
      next.whenData((_) {
        if (previous?.isLoading == true) {
          ref.invalidate(reportsByTypeProvider(problemType));
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(problemType.displayName),
        backgroundColor: Color(problemType.borderColor),
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            // No hay reportes de este tipo
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForProblemType(problemType),
                      size: 80,
                      color: Color(problemType.borderColor).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No hay reportes de ${problemType.displayName.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Crear Reporte',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateReportScreen(
                              initialProblemType: problemType,
                            ),
                          ),
                        );
                        
                        if (result == true || context.mounted) {
                          ref.invalidate(reportsByTypeProvider(problemType));
                        }
                      },
                      width: 200,
                    ),
                  ],
                ),
              ),
            );
          }

          // Mostrar reportes filtrados
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(problemType.borderColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(problemType.borderColor).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForProblemType(problemType),
                      color: Color(problemType.borderColor),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            problemType.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(problemType.borderColor),
                            ),
                          ),
                          Text(
                            '${reports.length} ${reports.length == 1 ? 'reporte' : 'reportes'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de reportes
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(reportsByTypeProvider(problemType));
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportCard(report: reports[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar reportes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(reportsByTypeProvider(problemType));
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateReportScreen(
                initialProblemType: problemType,
              ),
            ),
          );
          
          if (result == true || context.mounted) {
            ref.invalidate(reportsByTypeProvider(problemType));
          }
        },
        backgroundColor: Color(problemType.borderColor),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _getIconForProblemType(ProblemType type) {
    switch (type) {
      case ProblemType.inseguridad:
        return Icons.security;
      case ProblemType.serviciosBasicos:
        return Icons.build;
      case ProblemType.contaminacion:
        return Icons.eco;
      case ProblemType.convivencia:
        return Icons.people;
    }
  }
}