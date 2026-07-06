import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/formatters.dart';

class ReceiptOcrResult {
  const ReceiptOcrResult({required this.rawText, required this.amountCents});

  final String rawText;
  final int? amountCents;
}

class ReceiptOcrService {
  Future<ReceiptOcrResult> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(imagePath);
      final text = await recognizer.processImage(image);
      return ReceiptOcrResult(
        rawText: text.text.trim(),
        amountCents: _bestAmount(text),
      );
    } finally {
      await recognizer.close();
    }
  }

  int? _bestAmount(RecognizedText recognizedText) {
    _AmountCandidate? best;
    final lines = recognizedText.blocks
        .expand((block) => block.lines)
        .map((line) => line.text)
        .where((line) => line.trim().isNotEmpty);
    for (final line in lines) {
      final scoreBoost = _lineScoreBoost(line);
      for (final match in _amountPattern.allMatches(line)) {
        final raw = match.group(0) ?? '';
        final cents = parseBahtToCents(raw.replaceAll(RegExp(r'[^0-9.,]'), ''));
        if (cents <= 0 || cents > 999999999) continue;
        if (_looksLikeDateOrTime(line, raw)) continue;
        final hasDecimals = raw.contains('.');
        final score = cents + scoreBoost + (hasDecimals ? 1000000 : 0);
        final candidate = _AmountCandidate(cents: cents, score: score);
        if (best == null || candidate.score > best.score) {
          best = candidate;
        }
      }
    }
    return best?.cents;
  }

  int _lineScoreBoost(String line) {
    final lower = line.toLowerCase();
    final keywords = [
      'total',
      'amount',
      'paid',
      'payment',
      'cash',
      'balance',
      'ยอด',
      'รวม',
      'สุทธิ',
      'ชำระ',
      'จ่าย',
    ];
    return keywords.any(lower.contains) ? 5000000 : 0;
  }

  bool _looksLikeDateOrTime(String line, String raw) {
    final value = raw.replaceAll(',', '');
    if (RegExp(r'\d{1,2}[:/.-]\d{1,2}').hasMatch(line) && !raw.contains('.')) {
      return true;
    }
    final number = int.tryParse(value.split('.').first);
    return number != null && number >= 1900 && number <= 2200;
  }

  static final _amountPattern = RegExp(
    r'(?:฿|THB|B)?\s*([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]{2})?',
    caseSensitive: false,
  );
}

class _AmountCandidate {
  const _AmountCandidate({required this.cents, required this.score});

  final int cents;
  final int score;
}
