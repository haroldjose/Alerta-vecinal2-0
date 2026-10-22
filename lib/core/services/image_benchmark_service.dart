import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import 'image_service.dart';

// Escenarios que se comparan.
enum ImageScenario {
  original('A', 'Sin compresión (imagen original)'),
  pickerOnly('B', 'Solo image_picker 500 px, calidad 80 (versión anterior)'),
  pickerPlusCompress(
    'C',
    'image_picker + flutter_image_compress 1024 px, calidad 80 (versión actual)',
  );

  const ImageScenario(this.code, this.label);
  final String code;
  final String label;
}

// Resultado de una sola ejecución.
class BenchmarkRun {
  final ImageScenario scenario;
  final int originalBytes;
  final int uploadedBytes;

  // Tiempo de procesamiento/compresión antes de subir (0 en el escenario A).
  final int prepMs;

  // Subida a Firebase Storage + getDownloadURL (igual que en uploadReportImage).
  final int uploadMs;

  // Descarga de la imagen ya almacenada (equivale a "ver el reporte").
  final int downloadMs;

  const BenchmarkRun({
    required this.scenario,
    required this.originalBytes,
    required this.uploadedBytes,
    required this.prepMs,
    required this.uploadMs,
    required this.downloadMs,
  });

  // Tiempo que el usuario espera para guardar: compresión + subida.
  int get totalUploadMs => prepMs + uploadMs;
}

class Stat {
  final double mean;
  final double min;
  final double max;
  final double std;

  const Stat(this.mean, this.min, this.max, this.std);

  factory Stat.of(List<num> input) {
    if (input.isEmpty) return const Stat(0, 0, 0, 0);
    // Se convierte a List<double> para que reduce() no falle en ejecución
    // cuando llega una List<int> o List<double> tipada como List<num>.
    final List<double> values = input.map((e) => e.toDouble()).toList();
    final double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSq = 0;
    for (final x in values) {
      sumSq += (x - mean) * (x - mean);
    }
    final double variance = values.length > 1 ? sumSq / (values.length - 1) : 0;
    return Stat(
      mean,
      values.reduce((a, b) => a < b ? a : b),
      values.reduce((a, b) => a > b ? a : b),
      sqrt(variance),
    );
  }
}

class ImageBenchmarkService {
  ImageBenchmarkService({ImageService? imageService})
      : _imageService = imageService ?? ImageService();

  final ImageService _imageService;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Prepara el archivo según el escenario. 
  Future<File> _prepare(ImageScenario scenario, File original) async {
    switch (scenario) {
      case ImageScenario.original:
        return original;
      case ImageScenario.pickerOnly:
        // Aproxima lo que hacía image_picker (maxWidth/maxHeight 500, calidad 80).
        return _compressOrFail(original, 500, 500, 80);
      case ImageScenario.pickerPlusCompress:
        final first = await _compressOrFail(original, 500, 500, 80);
        final second = await _compressOrFail(first, 1024, 1024, 80);
        // Se limpia el archivo intermedio.
        if (first.path != original.path && first.path != second.path) {
          _deleteQuietly(first);
        }
        return second;
    }
  }

  Future<File> _compressOrFail(File input, int w, int h, int quality) async {
    final out = await _imageService.compressForUpload(
      input,
      minWidth: w,
      minHeight: h,
      quality: quality,
    );
    // compressForUpload devuelve el original si falla
    if (out.path == input.path) {
      throw StateError('La compresión falló: se devolvió el archivo original.');
    }
    return out;
  }

  void _deleteQuietly(File f) {
    try {
      f.deleteSync();
    } catch (_) {}
  }

  // Ejecuta un escenario una vez y devuelve las mediciones.
  Future<BenchmarkRun> runOnce(ImageScenario scenario, File original) async {
    final originalBytes = await original.length();

    // 1. Preparación / compresión
    final prepSw = Stopwatch()..start();
    final prepared = await _prepare(scenario, original);
    prepSw.stop();
    final uploadedBytes = await prepared.length();

    // 2. Subida (ruta temporal dentro de reports/ para respetar las reglas de Storage)
    final path =
        'reports/benchmark_${DateTime.now().microsecondsSinceEpoch}_${scenario.code}';
    final ref = _storage.ref().child(path);

    try {
      final uploadSw = Stopwatch()..start();
      final snapshot = await ref.putFile(prepared);
      if (snapshot.state != TaskState.success) {
        throw StateError('La subida no terminó correctamente.');
      }
      final url = await ref.getDownloadURL();
      uploadSw.stop();

      // 3. Descarga (visualización)
      final downloadSw = Stopwatch()..start();
      final response = await http.get(Uri.parse(url));
      downloadSw.stop();
      if (response.statusCode != 200) {
        throw StateError('Descarga fallida (HTTP ${response.statusCode}).');
      }

      return BenchmarkRun(
        scenario: scenario,
        originalBytes: originalBytes,
        uploadedBytes: uploadedBytes,
        prepMs: prepSw.elapsedMilliseconds,
        uploadMs: uploadSw.elapsedMilliseconds,
        downloadMs: downloadSw.elapsedMilliseconds,
      );
    } finally {
      // Limpieza: borra el objeto de prueba y el temporal comprimido.
      try {
        await ref.delete();
      } catch (_) {}
      if (prepared.path != original.path) _deleteQuietly(prepared);
    }
  }
}

// Construye la tabla de texto y el CSV para pegar en el documento.
class BenchmarkReport {
  static String _kb(num bytes) => (bytes / 1024).toStringAsFixed(1);

  static String _ms(Stat s) =>
      '${s.mean.toStringAsFixed(0)} ± ${s.std.toStringAsFixed(0)}';

  static String _change(double base, double value) {
    if (base == 0) return 'n/d';
    final pct = (value - base) / base * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %';
  }

  static String asText(List<BenchmarkRun> runs, int originalBytes) {
    if (runs.isEmpty) return 'Sin datos.';

    final by = {
      for (final s in ImageScenario.values)
        s: runs.where((r) => r.scenario == s).toList(),
    };
    final n = by[ImageScenario.original]!.length;

    final b = StringBuffer()
      ..writeln('Imagen de prueba: ${_kb(originalBytes)} KB | '
          'Repeticiones por escenario: $n')
      ..writeln('Valores en ms: promedio ± desviación estándar')
      ..writeln();

    const w = [4, 12, 14, 14, 16, 14];
    String row(List<String> c) => [
          for (var i = 0; i < c.length; i++) c[i].padRight(w[i]),
        ].join(' ');

    b.writeln(row([
      'Esc.',
      'Tamaño KB',
      'Compresión',
      'Subida',
      'Total guardar',
      'Descarga',
    ]));
    b.writeln('-' * 76);

    final stats = <ImageScenario, Map<String, Stat>>{};
    for (final s in ImageScenario.values) {
      final r = by[s]!;
      final m = {
        'size': Stat.of(r.map((e) => e.uploadedBytes / 1024).toList()),
        'prep': Stat.of(r.map((e) => e.prepMs).toList()),
        'upload': Stat.of(r.map((e) => e.uploadMs).toList()),
        'total': Stat.of(r.map((e) => e.totalUploadMs).toList()),
        'download': Stat.of(r.map((e) => e.downloadMs).toList()),
      };
      stats[s] = m;
      b.writeln(row([
        s.code,
        m['size']!.mean.toStringAsFixed(1),
        _ms(m['prep']!),
        _ms(m['upload']!),
        _ms(m['total']!),
        _ms(m['download']!),
      ]));
    }

    b
      ..writeln()
      ..writeln('Variación respecto a otro escenario (promedios):');

    void compare(String title, ImageScenario base, ImageScenario other) {
      final sb = stats[base]!;
      final so = stats[other]!;
      b.writeln('$title: '
          'tamaño ${_change(sb['size']!.mean, so['size']!.mean)} | '
          'total guardar ${_change(sb['total']!.mean, so['total']!.mean)} | '
          'descarga ${_change(sb['download']!.mean, so['download']!.mean)}');
    }

    compare('B vs A', ImageScenario.original, ImageScenario.pickerOnly);
    compare('C vs A', ImageScenario.original, ImageScenario.pickerPlusCompress);
    compare('C vs B', ImageScenario.pickerOnly, ImageScenario.pickerPlusCompress);

    b
      ..writeln()
      ..writeln('A: ${ImageScenario.original.label}')
      ..writeln('B: ${ImageScenario.pickerOnly.label}')
      ..writeln('C: ${ImageScenario.pickerPlusCompress.label}');

    return b.toString();
  }

  static String asCsv(List<BenchmarkRun> runs) {
    final b = StringBuffer(
      'escenario,original_kb,subido_kb,compresion_ms,subida_ms,total_guardar_ms,descarga_ms\n',
    );
    for (final r in runs) {
      b.writeln('${r.scenario.code},'
          '${_kb(r.originalBytes)},${_kb(r.uploadedBytes)},'
          '${r.prepMs},${r.uploadMs},${r.totalUploadMs},${r.downloadMs}');
    }
    return b.toString();
  }
}