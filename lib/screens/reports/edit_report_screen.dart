import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/services/image_service.dart';
import '../../core/services/ai_suggestion_service.dart';
import '../../models/report_model.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ai_problem_suggestion_widget.dart';

class EditReportScreen extends ConsumerStatefulWidget {
  final ReportModel report;
  
  const EditReportScreen({
    super.key, 
    required this.report,
  });

  @override
  ConsumerState<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends ConsumerState<EditReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late ProblemType _selectedProblemType;
  File? _newImage;
  LocationData? _selectedLocation;
  bool _isLoadingImage = false;
  bool _isLoadingLocation = false;
  bool _imageRemoved = false;

  // Estado de la sugerencia de IA
  AiSuggestionState _suggestionState = AiSuggestionState.idle;
  AiSuggestion? _currentSuggestion;
  Timer? _debounceTimer;                          
  final AiSuggestionService _aiService = AiSuggestionService();

//bandera
  bool _isCheckingOffensive = false;
   //  bandera duplicado
  bool _isCheckingDuplicate = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos existentes
    _titleController.text = widget.report.title;
    _descriptionController.text = widget.report.description;
    _selectedProblemType = widget.report.problemType;
    _selectedLocation = widget.report.location;

    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);

    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

   // Callback disparado cuando se escribe en título o descripción.
  void _onTextChanged() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.length + description.length < 5) {
      if (_suggestionState != AiSuggestionState.idle) {
        setState(() {
          _suggestionState = AiSuggestionState.idle;
          _currentSuggestion = null;
        });
      }
      _debounceTimer?.cancel();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1200), () {
      _fetchAiSuggestion(title, description);
    });
  }

  // Llama al servicio de IA y actualiza el estado de la sugerencia
  Future<void> _fetchAiSuggestion(String title, String description) async {
    if (!mounted) return;

    setState(() {
      _suggestionState = AiSuggestionState.loading;
      _currentSuggestion = null;
    });

    final suggestion = await _aiService.getSuggestion(
      title: title,
      description: description,
    );

    if (!mounted) return;

    setState(() {
  if (suggestion != null) {
    _suggestionState = AiSuggestionState.success;
    _currentSuggestion = suggestion;
  } else {
    _suggestionState = AiSuggestionState.error;
  }
});
  }

  // Aplica la sugerencia al selector de tipo de problema
  void _acceptSuggestion() {
    if (_currentSuggestion == null) return;
    setState(() {
      _selectedProblemType = _currentSuggestion!.problemType;
      _suggestionState = AiSuggestionState.idle;
      _currentSuggestion = null;
    });
  }

  // Descarta la sugerencia sin cambiar el tipo
  void _dismissSuggestion() {
    setState(() {
      _suggestionState = AiSuggestionState.idle;
      _currentSuggestion = null;
    });
  }


  // Muestra cuando detecta lenguaje ofensivo
  void _showOffensiveWordsDialog(List<String> offensiveWords) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Lenguaje inapropiado detectado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu reporte contiene palabras que no están permitidas. '
              'Por favor, modifica el contenido antes de continuar.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Palabras detectadas:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Mostrar cada palabra en un chip rojo
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: offensiveWords.map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Entendido, lo corregiré',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }


 // Dialogo  duplicado
  void _showDuplicateDialog(
    SimilarReportData similarReport,
    VoidCallback onConfirmNotDuplicate,
  ) {
  
    String formattedDate = similarReport.createdAt;
    try {
      final dt = DateTime.parse(similarReport.createdAt).toLocal();
      formattedDate =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final problemTypeLabels = {
      'inseguridad':      'Inseguridad',
      'serviciosBasicos': 'Servicios Básicos',
      'contaminacion':    'Contaminación',
      'convivencia':      'Convivencia',
    };
    final problemLabel =
        problemTypeLabels[similarReport.problemType] ?? similarReport.problemType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.content_copy_rounded,
                  color: Colors.orange, size: 26),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reporte similar encontrado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    const TextSpan(
                        text: 'Los cambios que estás guardando resultan '),
                    TextSpan(
                      text: '${similarReport.similarity}% similares',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const TextSpan(
                      text: ' a otro reporte registrado en las últimas 48 horas. '
                          'Los cambios no se guardarán si describen el mismo problema.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              //
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      similarReport.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      similarReport.description.length > 120
                          ? '${similarReport.description.substring(0, 117)}...'
                          : similarReport.description,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                    const Divider(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                            icon: Icons.category_outlined,
                            label: problemLabel),
                        _InfoChip(
                            icon: Icons.person_outline,
                            label: similarReport.userName),
                        _InfoChip(
                            icon: Icons.access_time_outlined,
                            label: formattedDate),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Si tus cambios describen un problema diferente o en otro lugar, '
                'puedes continuar guardando.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar cambios',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirmNotDuplicate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'No es el mismo',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _pickImage() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final imageService = ImageService();
      final imageFile = await imageService.showImageSourceDialogSafe(context);
      if (imageFile != null) {
        setState(() {
          _newImage = imageFile;
          _imageRemoved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingImage = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final location = await locationService.getCurrentLocation();
      setState(() {
        _selectedLocation = location;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actualizada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener ubicación: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

 // 
  Future<void> _updateReport() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isCheckingOffensive = true);

    final offensiveResult = await _aiService.checkOffensiveContent(
      title: title,
      description: description,
    );

    if (!mounted) return;
    setState(() => _isCheckingOffensive = false);

    if (offensiveResult.isOffensive) {
      _showOffensiveWordsDialog(offensiveResult.offensiveWords);
      return; 
    }

    setState(() => _isCheckingDuplicate = true);

    final duplicateResult = await _aiService.checkDuplicateReport(
      title:           title,
      description:     description,
      location:        _selectedLocation,
      excludeReportId: widget.report.id, 
    );

    if (!mounted) return;
    setState(() => _isCheckingDuplicate = false);

    if (duplicateResult.isDuplicate && duplicateResult.similarReport != null) {
      _showDuplicateDialog(
        duplicateResult.similarReport!,
        _saveChanges, 
      );
      return;
    }

    await _saveChanges();

    
  }

  Future<void> _saveChanges() async {
    final editReportNotifier = ref.read(editReportProvider.notifier);
    await editReportNotifier.updateReport(
      reportId:         widget.report.id,
      userId:           widget.report.userId,
      problemType:      _selectedProblemType,
      title:            _titleController.text.trim(),
      description:      _descriptionController.text.trim(),
      imageFile:        _newImage,
      existingImageUrl: _imageRemoved ? null : widget.report.imageUrl,
      location:         _selectedLocation,
    );
  }

  String? _getCurrentImageUrl() {
    if (_imageRemoved) return null;
    if (_newImage != null) return null;
    return widget.report.imageUrl;
  }

  String _getLocationDisplayText() {
    if (_selectedLocation == null) {
      return 'No se ha seleccionado ubicación';
    }
    
    final locationService = ref.read(locationServiceProvider);
    return locationService.formatLocation(_selectedLocation!);
  }




  @override
  Widget build(BuildContext context) {
    final editReportState = ref.watch(editReportProvider);

    final bool isButtonDisabled =
        editReportState.isLoading || _isCheckingOffensive || _isCheckingDuplicate;

    ref.listen<AsyncValue<void>>(editReportProvider, (previous, next) {
      
      if (previous?.isLoading == true) {
        next.when(
          data: (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte actualizado exitosamente'),
                  backgroundColor: AppColors.success,
                ),
              );
              
              Navigator.pop(context, true);
            }
          },
          loading: () {}, 
          error: (error, stack) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Reporte'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titulo del reporte
              const Text(
                'Título del reporte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                hintText: 'Ingrese un título descriptivo',
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El título es requerido';
                  }
                  if (value.trim().length < 5) {
                    return 'El título debe tener al menos 5 caracteres';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              // Descripción
              const Text(
                'Descripción',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe detalladamente el problema...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La descripción es requerida';
                    }
                    if (value.trim().length < 10) {
                      return 'La descripción debe tener al menos 10 caracteres';
                    }
                    return null;
                  },
                ),
              ),

              // sugerencia
              AiProblemSuggestionWidget(
                state: _suggestionState,
                suggestion: _currentSuggestion,
                onAccept: _acceptSuggestion,
                onDismiss: _dismissSuggestion,
              ),

              const SizedBox(height: 24),

              // Tipo de problema
              Row(
                children: [
                  const Text(
                    'Tipo de problema',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
              
                  Tooltip(
                    message: 'La IA sugiere el tipo según tu título y descripción',
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(_selectedProblemType.borderColor),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProblemType>(
                    value: _selectedProblemType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    items: ProblemType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Color(type.borderColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(type.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (ProblemType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedProblemType = newValue;
                          _suggestionState = AiSuggestionState.idle;
                          _currentSuggestion = null;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Fecha de creación
              const Text(
                'Fecha de creación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(widget.report.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Estado actual
              const Text(
                'Estado actual',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color(widget.report.status.color),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Color(widget.report.status.color).withValues(alpha: 0.1),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.report.status.displayName,
                  style: TextStyle(
                    color: Color(widget.report.status.color),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Solo los administradores pueden cambiar el estado',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 24),

              // Imagen
              const Text(
                'Imagen (opcional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isLoadingImage ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: _isLoadingImage
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : _newImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    _newImage!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _newImage = null;
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _getCurrentImageUrl() != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        _getCurrentImageUrl()!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                                size: 40,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _imageRemoved = true;
                                          });
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Toca para agregar imagen',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ),

              const SizedBox(height: 24),

              // Ubicación
              const Text(
                'Ubicación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: _selectedLocation != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getLocationDisplayText(),
                            style: TextStyle(
                              color: _selectedLocation != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(
                          _isLoadingLocation
                              ? 'Obteniendo ubicación...'
                              : 'Actualizar ubicación',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botón guardar cambios
              Center(
                child: CustomButton(
                  text: _isCheckingOffensive
                      ? 'Verificando contenido...'
                      : _isCheckingDuplicate
                          ? 'Verificando duplicados...' 
                          : 'Guardar Cambios',
                  onPressed: isButtonDisabled ? null : _updateReport,
                  isLoading: isButtonDisabled,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Mostrar chip de información
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}