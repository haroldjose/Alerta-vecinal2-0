import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/report_card.dart';
import '../../widgets/custom_button.dart';
import '../reports/create_report_screen.dart';
import '../../models/report_model.dart';

class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  // Estados de los filtros locales
  ProblemType? _selectedProblemType;
  ReportStatus? _selectedStatus;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Reportes'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No hay usuario autenticado'));
          }

          final myReportsAsync = ref.watch(myReportsStreamProvider(user.id));

          return myReportsAsync.when(
            data: (reports) {
              // Aplicar filtros locales
              final filteredReports = _applyFilters(reports);

              return Column(
                children: [
                  _buildStatsBar(reports),

                  // Panel de filtros
                  if (_showFilters) _buildFiltersPanel(),

                  // Lista de reportes
                  Expanded(
                    child: filteredReports.isEmpty
                        ? _buildEmptyState(context, reports.isEmpty)
                        : _buildReportsList(filteredReports, user.id),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar tus reportes',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(myReportsStreamProvider(user.id)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateReportScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Barra de estadísticas
  Widget _buildStatsBar(List<ReportModel> reports) {
    final pendientes = reports.where((r) => r.status == ReportStatus.pendiente).length;
    final enRevision = reports.where((r) => r.status == ReportStatus.enRevision).length;
    final resueltos = reports.where((r) => r.status == ReportStatus.resuelto).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ${reports.length} reportes',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(
                'Pendientes',
                pendientes,
                ReportStatus.pendiente.color,
              ),
              _buildStatChip(
                'En Revisión',
                enRevision,
                ReportStatus.enRevision.color,
              ),
              _buildStatChip(
                'Resueltos',
                resueltos,
                ReportStatus.resuelto.color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, int colorValue) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(colorValue).withValues(alpha: 0.1),
            border: Border.all(color: Color(colorValue)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(colorValue),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Panel de filtros
  Widget _buildFiltersPanel() {
    final hasActiveFilters = _selectedProblemType != null || _selectedStatus != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con botón limpiar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),

          // Filtro por tipo de problema
          _buildFilterSection(
            'Tipo de Problema',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ProblemType.values.map((type) {
                  final isSelected = _selectedProblemType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedProblemType = selected ? type : null;
                        });
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: Color(type.borderColor).withValues(alpha: 0.2),
                      checkmarkColor: Color(type.borderColor),
                      labelStyle: TextStyle(
                        color: isSelected ? Color(type.borderColor) : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? Color(type.borderColor) : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Filtro por estado
          _buildFilterSection(
            'Estado',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ReportStatus.values.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = selected ? status : null;
                        });
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: Color(status.color).withValues(alpha: 0.2),
                      checkmarkColor: Color(status.color),
                      labelStyle: TextStyle(
                        color: isSelected ? Color(status.color) : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? Color(status.color) : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  // Lista de reportes
  Widget _buildReportsList(List<ReportModel> reports, String userId) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myReportsStreamProvider(userId));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReportCard(report: reports[index]),
          );
        },
      ),
    );
  }

  // Estado vacío
  Widget _buildEmptyState(BuildContext context, bool noReportsAtAll) {
    final hasActiveFilters = _selectedProblemType != null || _selectedStatus != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters ? Icons.filter_alt_off : Icons.assignment_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              hasActiveFilters
                  ? 'No tienes reportes con estos filtros'
                  : noReportsAtAll
                      ? 'Aún no has creado reportes'
                      : 'No tienes reportes',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Prueba ajustando los filtros'
                  : 'Crea tu primer reporte para empezar',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasActiveFilters)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar filtros'),
              )
            else
              const SizedBox(height: 8),
            CustomButton(
              text: 'Crear Reporte',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateReportScreen(),
                  ),
                );
              },
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  // Aplicar filtros
  List<ReportModel> _applyFilters(List<ReportModel> reports) {
    var filtered = reports;

    if (_selectedProblemType != null) {
      filtered = filtered.where((report) => report.problemType == _selectedProblemType).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered.where((report) => report.status == _selectedStatus).toList();
    }

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _selectedProblemType = null;
      _selectedStatus = null;
    });
  }
}