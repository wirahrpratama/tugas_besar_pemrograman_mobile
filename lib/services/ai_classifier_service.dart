import 'dart:convert';
import 'package:http/http.dart' as http;

class DamageClassificationResult {
  final String categoryId; // cat_ac, cat_proyektor, cat_jaringan, cat_lampu, cat_toilet, cat_ruang_kelas
  final String prioritas; // rendah, sedang, tinggi, darurat
  final String alasanSingkat;

  const DamageClassificationResult({
    required this.categoryId,
    required this.prioritas,
    required this.alasanSingkat,
  });
}

class AiClassifierService {
  final String? geminiApiKey;

  const AiClassifierService({this.geminiApiKey});

  /// Mengklasifikasikan deskripsi keluhan ke 6 objek kerusakan & tingkat prioritas tiket
  Future<DamageClassificationResult> classifyComplaint(String deskripsi) async {
    if (geminiApiKey != null && geminiApiKey!.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiApiKey',
        );
        final prompt = 'Kamu adalah sistem pengklasifikasi tiket pengaduan fasilitas kampus. '
            'Berdasarkan keluhan berikut: "$deskripsi", kembalikan JSON murni dengan key: '
            '"category_id" (cat_ac | cat_proyektor | cat_jaringan | cat_lampu | cat_toilet | cat_ruang_kelas), '
            '"prioritas" (rendah | sedang | tinggi | darurat), dan '
            '"alasan" (1 kalimat singkat alasan penentuan prioritas).';

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
            },
          }),
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final text = body['candidates'][0]['content']['parts'][0]['text'] as String;
          final parsed = jsonDecode(text) as Map<String, dynamic>;
          return DamageClassificationResult(
            categoryId: (parsed['category_id'] ?? 'cat_ruang_kelas').toString(),
            prioritas: (parsed['prioritas'] ?? 'sedang').toString(),
            alasanSingkat: (parsed['alasan'] ?? 'Diklasifikasikan otomatis oleh AI.').toString(),
          );
        }
      } catch (_) {
        // Fallback ke klasifikasi lokal jika sedang offline
      }
    }

    final lower = deskripsi.toLowerCase();
    if (lower.contains('korslet') || lower.contains('percikan') || lower.contains('lampu mati') || lower.contains('listrik')) {
      return const DamageClassificationResult(
        categoryId: 'cat_lampu',
        prioritas: 'darurat',
        alasanSingkat: 'Terdeteksi indikasi gangguan kelistrikan/lampu yang membutuhkan penanganan cepat (SLA 2 jam).',
      );
    } else if (lower.contains('ac') || lower.contains('panas') || lower.contains('bocor')) {
      return const DamageClassificationResult(
        categoryId: 'cat_ac',
        prioritas: 'tinggi',
        alasanSingkat: 'Gangguan AC/pendingin ruang kuliah mengganggu kenyamanan kelas (SLA 6 jam).',
      );
    } else if (lower.contains('proyektor') || lower.contains('infokus') || lower.contains('hdmi') || lower.contains('layar')) {
      return const DamageClassificationResult(
        categoryId: 'cat_proyektor',
        prioritas: 'tinggi',
        alasanSingkat: 'Proyektor dibutuhkan langsung untuk aktivitas perkuliahan (SLA 4 jam).',
      );
    } else if (lower.contains('wifi') || lower.contains('internet') || lower.contains('jaringan') || lower.contains('lan')) {
      return const DamageClassificationResult(
        categoryId: 'cat_jaringan',
        prioritas: 'tinggi',
        alasanSingkat: 'Konektivitas jaringan kampus prioritas tinggi (SLA 4 jam).',
      );
    } else if (lower.contains('toilet') || lower.contains('wc') || lower.contains('air') || lower.contains('keran')) {
      return const DamageClassificationResult(
        categoryId: 'cat_toilet',
        prioritas: 'sedang',
        alasanSingkat: 'Masalah sanitasi dan air bersih fasilitas umum (SLA 8 jam).',
      );
    }
    return const DamageClassificationResult(
      categoryId: 'cat_ruang_kelas',
      prioritas: 'rendah',
      alasanSingkat: 'Kerusakan fasilitas inventaris ruang kelas umum (SLA 24 jam).',
    );
  }
}