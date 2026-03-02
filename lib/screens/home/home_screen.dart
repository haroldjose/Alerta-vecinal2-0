import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_drawer.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/report_card.dart';
import '../../widgets/custom_button.dart';
import '../reports/create_report_screen.dart';
import '../../models/report_model.dart';

import '../settings/settings_screen.dart';
import '../../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Estados de los filtros
  ProblemType? _selectedProblemType;
  ReportStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final reportsAsync = ref.watch(reportsStreamProvider);
    final currentTheme = ref.watch(currentThemeProvider);

    // Escucha cambios en el provider de creación de reportes
    ref.listen<AsyncValue<void>>(createReportProvider, (previous, next) {
      next.whenData((_) {
        if (previous?.isLoading == true) {
          ref.invalidate(reportsStreamProvider);
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerta Vecinal'),
        backgroundColor: currentTheme.primary,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No hay usuario autenticado'));
          }

          return reportsAsync.when(
            data: (reports) {
              // Aplicar filtros
              final filteredReports = _applyFilters(reports);

              return Column(
                children: [
                  // Panel de filtros
                  if (_showFilters) _buildFiltersPanel(),

                  // Lista de reportes
                  Expanded(
                    child:
                        filteredReports.isEmpty
                            ? _buildEmptyState(context)
                            : _buildReportsList(filteredReports),
                  ),
                ],
              );
            },
            loading:
                () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
            error:
                (error, stack) => Center(
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
                        onPressed: () => ref.refresh(reportsStreamProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        error:
            (error, stack) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateReportScreen()),
          );

          if (result == true) {
            ref.invalidate(reportsStreamProvider);
            
            await Future.delayed(const Duration(milliseconds: 200));
          }
        },
        backgroundColor: currentTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Panel de filtros
  Widget _buildFiltersPanel() {
    final hasActiveFilters =
        _selectedProblemType != null ||
        _selectedStatus != null ||
        _selectedDateRange != null;

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
                children:
                    ProblemType.values.map((type) {
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
                          selectedColor: Color(
                            type.borderColor,
                          ).withValues(alpha: 0.2),
                          checkmarkColor: Color(type.borderColor),
                          labelStyle: TextStyle(
                            color:
                                isSelected
                                    ? Color(type.borderColor)
                                    : AppColors.textSecondary,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Color(type.borderColor)
                                    : Colors.transparent,
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
                children:
                    ReportStatus.values.map((status) {
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
                          selectedColor: Color(
                            status.color,
                          ).withValues(alpha: 0.2),
                          checkmarkColor: Color(status.color),
                          labelStyle: TextStyle(
                            color:
                                isSelected
                                    ? Color(status.color)
                                    : AppColors.textSecondary,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Color(status.color)
                                    : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          // Filtro por fecha
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: Icon(
                    _selectedDateRange != null
                        ? Icons.date_range
                        : Icons.calendar_today,
                    size: 18,
                  ),
                  label: Text(
                    _selectedDateRange != null
                        ? '${_formatDateShort(_selectedDateRange!.start)} - ${_formatDateShort(_selectedDateRange!.end)}'
                        : 'Seleccionar rango',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _selectedDateRange != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                    side: BorderSide(
                      color:
                          _selectedDateRange != null
                              ? AppColors.primary
                              : Colors.grey[300]!,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  Widget _buildReportsList(List<ReportModel> reports) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportsStreamProvider);
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
  Widget _buildEmptyState(BuildContext context) {
    final hasActiveFilters =
        _selectedProblemType != null ||
        _selectedStatus != null ||
        _selectedDateRange != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters ? Icons.filter_alt_off : Icons.report_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              hasActiveFilters
                  ? 'No se encontraron reportes con estos filtros'
                  : 'No se tienen reportes',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (hasActiveFilters)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar filtros'),
              )
            else
              const SizedBox(height: 16),
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

    // Filtrar por tipo de problema
    if (_selectedProblemType != null) {
      filtered =
          filtered
              .where((report) => report.problemType == _selectedProblemType)
              .toList();
    }

    // Filtrar por estado
    if (_selectedStatus != null) {
      filtered =
          filtered.where((report) => report.status == _selectedStatus).toList();
    }

    // Filtrar por fecha
    if (_selectedDateRange != null) {
      filtered =
          filtered.where((report) {
            final reportDate = report.createdAt;
            final startDate = DateTime(
              _selectedDateRange!.start.year,
              _selectedDateRange!.start.month,
              _selectedDateRange!.start.day,
            );
            final endDate = DateTime(
              _selectedDateRange!.end.year,
              _selectedDateRange!.end.month,
              _selectedDateRange!.end.day,
              23,
              59,
              59,
            );
            return reportDate.isAfter(
                  startDate.subtract(const Duration(seconds: 1)),
                ) &&
                reportDate.isBefore(endDate.add(const Duration(seconds: 1)));
          }).toList();
    }

    return filtered;
  }

  // Limpiar filtros
  void _clearFilters() {
    setState(() {
      _selectedProblemType = null;
      _selectedStatus = null;
      _selectedDateRange = null;
    });
  }

  // Seleccionar rango de fechas
  Future<void> _selectDateRange() async {
    final currentTheme = ref.read(currentThemeProvider);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: currentTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // Formatear fecha
  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
