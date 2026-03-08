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
            content: Text('Ubicación obtenida correctamente'),
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

  Future<void> _createReport() async {
    if (!_formKey.currentState!.validate()) return;

    final createReportNotifier = ref.read(createReportProvider.notifier);
    await createReportNotifier.createReport(
      problemType: _selectedProblemType,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageFile: _selectedImage,
      location: _selectedLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final createReportState = ref.watch(createReportProvider);
    final isAdmin = currentUser.value?.role == UserRole.admin;

    ref.listen<AsyncValue<void>>(createReportProvider, (previous, next) {
  
      if (previous?.isLoading == true) {
        next.when(
          data: (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte creado exitosamente'),
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
                  text: 'Crear Reporte',
                  onPressed: createReportState.isLoading ? null : _createReport,
                  isLoading: createReportState.isLoading,
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