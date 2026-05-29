import 'dart:io';
import 'dart:async'; 
import 'package:alerta_vecinal/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/services/image_service.dart';
import '../../core/services/ai_suggestion_service.dart'; 
import '../../models/report_model.dart';
import '../../providers/reports_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/ai_problem_suggestion_widget.dart';

class CreateReportScreen extends ConsumerStatefulWidget {
  final ProblemType? initialProblemType;
  
  const CreateReportScreen({
    super.key,
    this.initialProblemType,
  });

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late ProblemType _selectedProblemType;
  ReportStatus _selectedStatus = ReportStatus.pendiente;
  File? _selectedImage;
  LocationData? _selectedLocation;
  bool _isLoadingImage = false;
  bool _isLoadingLocation = false;

  // Estado de la sugerencia IA
  AiSuggestionState _suggestionState = AiSuggestionState.idle;
  AiSuggestion? _currentSuggestion;
  Timer? _debounceTimer;   
  final AiSuggestionService _aiService = AiSuggestionService(); 

   // bandera indica si se verifica el lenguaje
   bool _isCheckingOffensive = false;
   // bandera duplicado
   bool _isCheckingDuplicate = false;

  @override
  void initState() {
    super.initState();
    _selectedProblemType = widget.initialProblemType ?? ProblemType.inseguridad;

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
  // Callback que se ejecuta cuando se escribe en titulo o descripción
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
    // reiniciar el timer
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1200), () {
      _fetchAiSuggestion(title, description);
    });
  }

  // Llama al servicio de IA para obtener la sugerencia de tipo de problema
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

  // Aplica sugerencia de la IA
  void _acceptSuggestion() {
    if (_currentSuggestion == null) return;
    setState(() {
      _selectedProblemType = _currentSuggestion!.problemType;
      _suggestionState = AiSuggestionState.idle;
      _currentSuggestion = null;
    });
  }

  // Descarta la sugerencia de la IA
  void _dismissSuggestion() {
    setState(() {
      _suggestionState = AiSuggestionState.idle;
      _currentSuggestion = null;
    });
  }

  // muestra la deteccion del lenguaje ofensivo
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
            // palabras ofensivas
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

  // Diálogo que se muestra cuando se detecta un reporte duplicado.
  
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

    // Traducir tipo de problema al español
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
              // Explicación principal
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    const TextSpan(
                      text: 'Ya existe un reporte ',
                    ),
                    TextSpan(
                      text: '${similarReport.similarity}% similar',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const TextSpan(
                      text: ' al tuyo registrado en las últimas 48 horas. '
                          'El reporte no puede guardarse si describe el mismo problema.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tarjeta con datos del reporte similar
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
                    // Título del reporte similar
                    Text(
                      similarReport.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    // Descripción truncada
                    Text(
                      similarReport.description.length > 120
                          ? '${similarReport.description.substring(0, 117)}...'
                          : similarReport.description,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const Divider(height: 16),
                    // Metadatos en chips
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

              // Nota aclaratoria
              Text(
                'Si tu reporte describe un problema diferente o en otro lugar, '
                'puedes continuar.',
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
              'Cancelar reporte',
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
          _selectedImage = imageFile;
        });
        // Confirmación visual al seleccionar imagen correctamente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Imagen seleccionada correctamente')),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Mensaje de error al fallar la selección de imagen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al seleccionar imagen: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
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
        // Confirmación visual al obtener ubicación correctamente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Ubicación obtenida correctamente')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Mensaje de error al fallar la obtención de ubicación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al obtener ubicación: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _createReport() async {
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
      title:       title,
      description: description,
      location:    _selectedLocation, 
    );

    if (!mounted) return;
    setState(() => _isCheckingDuplicate = false);

    if (duplicateResult.isDuplicate && duplicateResult.similarReport != null) {
      
      _showDuplicateDialog(
        duplicateResult.similarReport!,
        _saveReport, 
      );
      return;
    }

    await _saveReport();

  }


  // guardado del reporte
  Future<void> _saveReport() async {
    final createReportNotifier = ref.read(createReportProvider.notifier);
    await createReportNotifier.createReport(
      problemType: _selectedProblemType,
      title:       _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageFile:   _selectedImage,
      location:    _selectedLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final createReportState = ref.watch(createReportProvider);
    final isAdmin = currentUser.value?.role == UserRole.admin;

    final bool isButtonDisabled =
        createReportState.isLoading || _isCheckingOffensive || _isCheckingDuplicate;

    ref.listen<AsyncValue<void>>(createReportProvider, (previous, next) {
  
      if (previous?.isLoading == true) {
        next.when(
          data: (_) {
            if (mounted) {
              // Confirmación visual al crear el reporte correctamente
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(child: Text('Reporte creado exitosamente')),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  duration: Duration(seconds: 3),
                ),
              );

              Navigator.pop(context, true);
            }
          },
          loading: () {},
          error: (error, stack) {
            if (mounted) {
              // Mensaje de error al fallar la creación del reporte
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Error: $error')),
                    ],
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 4),
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
        title: const Text('Crear Reporte'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Titulo del reporte
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
              //sugerencia
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
                  // Ícono que indica que la IA puede ayudar con este campo
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

              // Estado (solo para admin)
              if (isAdmin) ...[
                const Text(
                  'Estado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
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
                      onChanged: (ReportStatus? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Fecha automática
              const Text(
                'Fecha',
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
                  '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
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
                      : _selectedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    _selectedImage!,
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
                                        _selectedImage = null;
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
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
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _selectedLocation != null
                            ? ref.read(locationServiceProvider).formatLocation(_selectedLocation!)
                            : 'No se ha seleccionado ubicación',
                        style: TextStyle(
                          color: _selectedLocation != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isLoadingLocation ? null : _getCurrentLocation,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isLoadingLocation
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Botón crear reporte
              Center(
                child: CustomButton(
                  text: _isCheckingOffensive
                      ? 'Verificando contenido...'
                      : _isCheckingDuplicate
                          ? 'Verificando duplicados...' 
                          : 'Crear Reporte',
                  onPressed: isButtonDisabled ? null : _createReport,
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
}

// Muestra ships de información
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
