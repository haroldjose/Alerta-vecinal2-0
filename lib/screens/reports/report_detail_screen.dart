import 'dart:io';
import 'package:alerta_vecinal/models/user_model.dart';
import 'package:alerta_vecinal/widgets/location_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/report_model.dart';
import '../../core/constants/colors.dart';
import '../../core/services/local_storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import 'edit_report_screen.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final ReportModel report;

  const ReportDetailScreen({
    super.key,
    required this.report,
  });

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  ReportStatus? _selectedStatus;
  bool _isUpdatingStatus = false;
  bool _isDeletingReport = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null || _selectedStatus == widget.report.status) return;
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final reportService = ref.read(reportServiceProvider);
      await reportService.updateReportStatus(widget.report.id, _selectedStatus!);
      
      ref.invalidate(reportsStreamProvider);
      for (final problemType in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(problemType));
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteReport() async {
    if (_isDeletingReport) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reporte'),
        content: const Text('¿Estás seguro de que quieres eliminar este reporte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isDeletingReport = true;
      });

      try {
        final reportService = ref.read(reportServiceProvider);
        await reportService.deleteReport(widget.report.id);
        
        ref.invalidate(reportsStreamProvider);
        for (final problemType in ProblemType.values) {
          ref.invalidate(reportsByTypeProvider(problemType));
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte eliminado correctamente'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeletingReport = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _editReport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReportScreen(report: widget.report),
      ),
    );
    
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser.value?.role == UserRole.admin;
    final isOwner = currentUser.value?.id == widget.report.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del Reporte'),
        backgroundColor: AppColors.primary,
        actions: [
          if (isOwner || isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editReport,
              tooltip: 'Editar reporte',
            ),
          if (isAdmin)
            IconButton(
              icon: _isDeletingReport
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete),
              onPressed: _isDeletingReport ? null : _deleteReport,
              tooltip: 'Eliminar reporte',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo de problema
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(widget.report.problemType.borderColor),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.report.problemType.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.report.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información básica
                  _buildInfoSection(
                    title: 'Información del Reporte',
                    children: [
                      _buildInfoRow('Reportado por:', widget.report.userName),
                      _buildInfoRow('Fecha:', _formatDate(widget.report.createdAt)),
                      if (widget.report.createdAt != widget.report.updatedAt)
                        _buildInfoRow('Actualizado:', _formatDate(widget.report.updatedAt)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Estado
                  _buildInfoSection(
                    title: 'Estado',
                    children: [
                      if (isAdmin && _selectedStatus != widget.report.status) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ReportStatus>(
                              value: _selectedStatus,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                              items: ReportStatus.values.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status.displayName),
                                );
                              }).toList(),
                              onChanged: _isUpdatingStatus 
                                  ? null 
                                  : (ReportStatus? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedStatus = newValue;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isUpdatingStatus ? null : _updateStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: _isUpdatingStatus
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Actualizar Estado',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(widget.report.status.color).withValues(alpha: 0.1),
                            border: Border.all(color: Color(widget.report.status.color)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.report.status.displayName,
                            style: TextStyle(
                              color: Color(widget.report.status.color),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isUpdatingStatus
                                ? null
                                : () {
                                    setState(() {
                                      _selectedStatus = widget.report.status == ReportStatus.pendiente 
                                          ? ReportStatus.enRevision 
                                          : ReportStatus.resuelto;
                                    });
                                  },
                            child: const Text('Cambiar estado'),
                          ),
                        ],
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Descripción
                  _buildInfoSection(
                    title: 'Descripción',
                    children: [
                      Text(
                        widget.report.description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  //Imagen con soporte offline
                  if (widget.report.imageUrl != null) ...[
                    _buildInfoSection(
                      title: 'Imagen',
                      children: [
                        _ReportImageWidget(
                          reportId: widget.report.id,
                          imageUrl: widget.report.imageUrl!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Ubicación
                  if (widget.report.location != null) ...[
                    _buildInfoSection(
                      title: 'Ubicación',
                      children: [
                        LocationWidget(location: widget.report.location!),
                      ],
                    ),
                  ],

                  // Botón de editar para el dueño
                  if (isOwner || isAdmin) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _editReport,
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar Reporte'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

//Widget para manejar imágenes en modo offline
class _ReportImageWidget extends StatelessWidget {
  final String reportId;
  final String imageUrl;

  const _ReportImageWidget({
    required this.reportId,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Intentar cargar imagen local primero
    final localStorage = LocalStorageService();
    final localReport = localStorage.getReport(reportId);
    
    // Si existe imagen local,
    if (localReport?.localImagePath != null) {
      final localFile = File(localReport!.localImagePath!);
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          localFile,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder();
          },
        ),
      );
    }
    
    // Si no hay imagen local, intentar cargar de red
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Imagen no disponible',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

