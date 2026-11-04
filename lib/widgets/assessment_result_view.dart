// Hiển thị kết quả chấm M4: điểm, từng từ, từng âm vị IPA và gợi ý cải thiện.
// Dùng chung cho màn luyện tập (kết quả vừa chấm) và màn lịch sử (xem lại).

import 'package:flutter/material.dart';

import '../models/assessment.dart';
import '../services/pronunciation_labels.dart';

typedef SpeakCallback = Future<void> Function(String text);

class AssessmentResultView extends StatefulWidget {
  const AssessmentResultView({
    super.key,
    required this.assessment,
    this.onSpeak,
    this.catalog = const {},
  });

  final Assessment assessment;
  final SpeakCallback? onSpeak;

  /// Danh mục âm vị (IPA → mẹo) để giải thích âm sai; có thể rỗng.
  final Map<String, PhonemeInfo> catalog;

  @override
  State<AssessmentResultView> createState() => _AssessmentResultViewState();
}

class _AssessmentResultViewState extends State<AssessmentResultView> {
  int? _wordIndex;
  int? _phonemeIndex;

  @override
  void initState() {
    super.initState();
    _selectFirstError();
  }

  @override
  void didUpdateWidget(covariant AssessmentResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assessment.id != widget.assessment.id) _selectFirstError();
  }

  void _selectFirstError() {
    final words = widget.assessment.words;
    final idx = words.indexWhere((w) => w.isError);
    _wordIndex = words.isEmpty ? null : (idx >= 0 ? idx : 0);
    _phonemeIndex = null;
    if (_wordIndex != null) {
      final p = words[_wordIndex!].phonemes.indexWhere((p) => p.isError);
      _phonemeIndex = p >= 0 ? p : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreHeader(assessment: a),
        const SizedBox(height: 12),
        if (!a.isAcousticAssessment) _FallbackNotice(source: a.source),
        if (a.words.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Phân tích từng từ',
            subtitle: 'Chạm vào một từ để xem chi tiết âm vị',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < a.words.length; i++)
                      _wordChip(i, a.words[i]),
                  ],
                ),
                if (_wordIndex != null) ...[
                  const SizedBox(height: 14),
                  _WordDetail(
                    word: a.words[_wordIndex!],
                    selectedPhoneme: _phonemeIndex,
                    onSelectPhoneme: (i) => setState(() => _phonemeIndex = i),
                    onSpeak: widget.onSpeak,
                    catalog: widget.catalog,
                  ),
                ],
                if (a.recognizedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    a.isAcousticAssessment
                        ? 'Âm nghe được: ${a.recognizedText}'
                        : 'Nhận dạng: "${a.recognizedText}"',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (a.feedback.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Gợi ý cải thiện',
            child: Column(
              children: [
                for (final f in a.feedback)
                  _FeedbackTile(item: f, onSpeak: widget.onSpeak),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _wordChip(int index, WordResult w) {
    final color = PronunciationLabels.wordColor(w);
    final selected = index == _wordIndex;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.25),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color, width: selected ? 2 : 1),
      label: Text(
        '${w.word} ${w.accuracy.round()}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          decoration:
              w.errorType == 'Omission' ? TextDecoration.lineThrough : null,
        ),
      ),
      onSelected: (_) => setState(() {
        _wordIndex = index;
        final p = w.phonemes.indexWhere((p) => p.isError);
        _phonemeIndex = p >= 0 ? p : null;
      }),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.assessment});

  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final color = PronunciationLabels.levelColor(a.level);
    final s = a.scores;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: s.pronunciation / 100,
                          strokeWidth: 7,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      ),
                      Text(
                        '${a.overallScore}',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PronunciationLabels.level(a.level),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PronunciationLabels.source(a.source, a.provider),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (a.durationMs > 0)
                        Text(
                          'Độ dài bản ghi: ${(a.durationMs / 1000).toStringAsFixed(1)} giây',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ScoreBar(label: 'Độ chính xác âm vị', value: s.accuracy),
            _ScoreBar(label: 'Độ trôi chảy', value: s.fluency),
            _ScoreBar(label: 'Độ đầy đủ', value: s.completeness),
            if (s.prosody != null)
              _ScoreBar(label: 'Ngữ điệu', value: s.prosody!),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = PronunciationLabels.scoreColor(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${value.round()}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice({required this.source});

  final AssessmentSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kết quả dự phòng: chấm dựa trên chữ nhận dạng được, chưa phân tích âm thanh. '
              'Kết nối Pronunciation API để có phân tích âm vị chính xác.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordDetail extends StatelessWidget {
  const _WordDetail({
    required this.word,
    required this.selectedPhoneme,
    required this.onSelectPhoneme,
    required this.onSpeak,
    required this.catalog,
  });

  final WordResult word;
  final int? selectedPhoneme;
  final ValueChanged<int> onSelectPhoneme;
  final SpeakCallback? onSpeak;
  final Map<String, PhonemeInfo> catalog;

  @override
  Widget build(BuildContext context) {
    final color = PronunciationLabels.wordColor(word);
    final p = selectedPhoneme != null && selectedPhoneme! < word.phonemes.length
        ? word.phonemes[selectedPhoneme!]
        : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: word.word,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    if (word.ipa != null && word.ipa!.isNotEmpty)
                      TextSpan(
                        text: '  /${word.ipa}/',
                        style: const TextStyle(
                            color: Colors.teal, fontWeight: FontWeight.w600),
                      ),
                  ]),
                ),
              ),
              if (onSpeak != null)
                IconButton(
                  tooltip: 'Nghe phát âm chuẩn',
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () => onSpeak!(word.word),
                ),
            ],
          ),
          Text(
            '${PronunciationLabels.wordErrorType(word.errorType)} · ${word.accuracy.round()}/100',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (word.phonemes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < word.phonemes.length; i++)
                  _PhonemeChip(
                    phoneme: word.phonemes[i],
                    selected: i == selectedPhoneme,
                    onTap: () => onSelectPhoneme(i),
                  ),
              ],
            ),
          ],
          if (p != null) ...[
            const SizedBox(height: 10),
            _PhonemeExplanation(phoneme: p, info: catalog[p.expected]),
          ],
        ],
      ),
    );
  }
}

class _PhonemeChip extends StatelessWidget {
  const _PhonemeChip(
      {required this.phoneme, required this.selected, required this.onTap});

  final PhonemeResult phoneme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = phoneme;
    final color = PronunciationLabels.phonemeColor(p);
    final label = switch (p.errorKind) {
      'substitution' when p.actual != null => '/${p.expected}/→/${p.actual}/',
      'deletion' => '/${p.expected}/ ✕',
      _ => '/${p.expected}/',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                decoration: p.errorKind == 'deletion'
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            Text('${p.accuracy.round()}',
                style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PhonemeExplanation extends StatelessWidget {
  const _PhonemeExplanation({required this.phoneme, this.info});

  final PhonemeResult phoneme;
  final PhonemeInfo? info;

  @override
  Widget build(BuildContext context) {
    final p = phoneme;
    final pattern = PronunciationLabels.pattern(p.pattern);
    final position = PronunciationLabels.position(p.position);
    final lines = <String>[
      '/${p.expected}/${position.isEmpty ? '' : ' ($position)'}: ${PronunciationLabels.errorKind(p.errorKind)}'
          '${p.isError && p.actual != null && p.actual != p.expected ? ' → bạn đọc /${p.actual}/' : ''}',
      if (pattern != null) 'Lỗi thường gặp: $pattern',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(l,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          if (info != null && info!.tipVi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('💡 ${info!.tipVi}', style: const TextStyle(fontSize: 13)),
            if (info!.minimalPairs.isNotEmpty)
              Text(
                'Cặp từ luyện: ${info!.minimalPairs.take(3).map((e) => e.join(' – ')).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item, this.onSpeak});

  final FeedbackItem item;
  final SpeakCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final f = item;
    final speakable = <String>{...?f.minimalPair, ...f.practiceWords}
        .where((w) => w.isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PronunciationLabels.feedbackIcon(f.kind),
              color: f.kind == 'praise' ? Colors.amber.shade700 : Colors.teal,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.messageVi, style: const TextStyle(fontSize: 14)),
                if (f.messageEn.isNotEmpty && f.messageEn != f.messageVi)
                  Text(
                    f.messageEn,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                if (f.minimalPair != null && f.minimalPair!.length >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Cặp từ đối lập: ${f.minimalPair!.join(' ↔ ')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                if (speakable.isNotEmpty && onSpeak != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final w in speakable)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.volume_up, size: 16),
                            label: Text(w),
                            onPressed: () => onSpeak!(w),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
