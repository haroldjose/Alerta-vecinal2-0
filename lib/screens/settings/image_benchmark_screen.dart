import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/services/image_benchmark_service.dart';

// Pantalla para medir el tiempo de carga de imágenes con y sin compresión.

class ImageBenchmarkScreen extends StatefulWidget {
  const ImageBenchmarkScreen({super.key});

  @override
  State<ImageBenchmarkScreen> createState() => _ImageBenchmarkScreenState();
}

class _ImageBenchmarkScreenState extends State<ImageBenchmarkScreen> {
  final _service = ImageBenchmarkService();
  final _picker = ImagePicker();

  File? _image;
  int _originalBytes = 0;
  int _repetitions = 10;
  bool _running = false;
  bool _cancel = false;
  String _status = '';
  String? _error;
  final List<BenchmarkRun> _runs = [];

  Future<void> _pick(ImageSource source) async {
    // Sin maxWidth/maxHeight: se obtiene la imagen original del dispositivo.
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.length();
    if (!mounted) return;
    setState(() {
      _image = file;
      _originalBytes = bytes;
      _runs.clear();
      _error = null;
      _status = '';
    });
  }

  Future<void> _start() async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _running = true;
      _cancel = false;
      _runs.clear();
      _error = null;
      _status = 'Calentamiento (no se cuenta)...';
    });

    try {
      // Una ronda de calentamiento descartada (conexión, plugin de compresión).
      for (final s in ImageScenario.values) {
        if (_cancel) break;
        await _service.runOnce(s, image);
      }

      final all = ImageScenario.values;
      for (var i = 0; i < _repetitions && !_cancel; i++) {
        for (var k = 0; k < all.length && !_cancel; k++) {
          // Se rota el orden en cada repetición para no favorecer a ningún escenario.
          final scenario = all[(i + k) % all.length];
          if (!mounted) return;
          setState(() {
            _status =
                'Repetición ${i + 1}/$_repetitions · escenario ${scenario.code}';
          });
          final run = await _service.runOnce(scenario, image);
          if (!mounted) return;
          setState(() => _runs.add(run));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _status = _cancel ? 'Prueba cancelada' : 'Prueba finalizada';
        });
      }
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _repetitions * ImageScenario.values.length;
    final showReport = _runs.isNotEmpty && !_running;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Prueba de carga de imágenes'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Compara el tiempo de guardado y de visualización entre:\n'
            'A: sin compresión · B: versión anterior · C: versión actual.\n',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_image!, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(
              'Imagen original: ${(_originalBytes / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _running ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _running ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Repeticiones por escenario:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _repetitions,
                items: const [5, 10, 15, 20, 30]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: _running
                    ? null
                    : (v) => setState(() => _repetitions = v ?? 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_running)
            ElevatedButton.icon(
              onPressed: _image == null ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar prueba'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => setState(() => _cancel = true),
              icon: const Icon(Icons.stop),
              label: const Text('Cancelar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status),
            if (_running) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _runs.length / total),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              'Error: $_error',
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          if (showReport) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  BenchmarkReport.asText(_runs, _originalBytes),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _copy(
                      BenchmarkReport.asText(_runs, _originalBytes),
                      'Resumen',
                    ),
                    child: const Text('Copiar resumen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _copy(BenchmarkReport.asCsv(_runs), 'CSV'),
                    child: const Text('Copiar CSV'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}