// M4 – Result History: danh sách các lần chấm (phân trang), âm vị yếu nhất,
// và xem lại chi tiết từng lần chấm.

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../models/assessment.dart';
import '../services/pronunciation_api.dart';
import '../services/pronunciation_engine.dart';
import '../services/pronunciation_labels.dart';
import '../widgets/assessment_result_view.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({super.key, required this.engine});

  final PronunciationEngine engine;

  @override
  State<AssessmentHistoryScreen> createState() =>
      _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  final List<AssessmentSummary> _items = [];
  List<PhonemeStat> _weak = const [];
  Map<String, PhonemeInfo> _catalog = const {};
  String? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await Future.wait([_loadMore(), _loadWeak()]);
  }

  Future<void> _loadWeak() async {
    try {
      final weak = await widget.engine.weakPhonemes(limit: 5);
      final catalog = await widget.engine.phonemeCatalog();
      if (mounted) {
        setState(() {
          _weak = weak;
          _catalog = catalog;
        });
      }
    } on PronunciationApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await widget.engine.history(limit: 20, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on PronunciationApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chấm phát âm')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.engine.hasRemoteHistory)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Đang ở chế độ dự phòng: lịch sử chỉ lưu trong phiên này. '
                  'Kết nối Pronunciation API để lưu lịch sử chi tiết lâu dài.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
              ),
            if (_error != null)
              Card(
                color: Colors.red.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.redAccent),
                  title: Text(_error!),
                  trailing: TextButton(
                      onPressed: _refresh, child: const Text('Thử lại')),
                ),
              ),
            _WeakPhonemesCard(stats: _weak, catalog: _catalog),
            const SizedBox(height: 16),
            const Text('Các lần chấm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_items.isEmpty && !_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có lần chấm nào. Hãy thu âm câu đầu tiên!'),
                ),
              ),
            for (final s in _items)
              _SummaryTile(summary: s, onTap: () => _open(s)),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
            if (_hasMore && !_loading && _items.isNotEmpty)
              TextButton(onPressed: _loadMore, child: const Text('Tải thêm')),
          ],
        ),
      ),
    );
  }

  void _open(AssessmentSummary s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          AssessmentDetailScreen(engine: widget.engine, assessmentId: s.id),
    ));
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.summary, required this.onTap});

  final AssessmentSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PronunciationLabels.levelColor(summary.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(summary.referenceText,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${PronunciationLabels.level(summary.level)} · '
          '${DateFormat('dd/MM/yyyy HH:mm').format(summary.createdAt.toLocal())}',
        ),
        trailing: CircleAvatar(
          backgroundColor: color,
          child: Text(
            '${summary.scores.pronunciation.round()}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _WeakPhonemesCard extends StatelessWidget {
  const _WeakPhonemesCard({required this.stats, required this.catalog});

  final List<PhonemeStat> stats;
  final Map<String, PhonemeInfo> catalog;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Âm bạn hay sai',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (stats.isEmpty)
              const Text(
                  'Chưa đủ dữ liệu. Luyện thêm vài câu để AI tìm ra âm yếu của bạn.')
            else
              for (final s in stats) _row(context, s),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, PhonemeStat s) {
    final color = PronunciationLabels.scoreColor(s.avgAccuracy);
    final tip = catalog[s.phoneme]?.tipVi;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('/${s.phoneme}/',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: color)),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: (s.avgAccuracy / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                  '${s.avgAccuracy.round()} · sai ${s.errorCount}/${s.attempts}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (tip != null && tip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 2),
              child: Text(tip,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class AssessmentDetailScreen extends StatefulWidget {
  const AssessmentDetailScreen(
      {super.key, required this.engine, required this.assessmentId});

  final PronunciationEngine engine;
  final String assessmentId;

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  late Future<(Assessment?, Map<String, PhonemeInfo>)> _future = _load();

  Future<(Assessment?, Map<String, PhonemeInfo>)> _load() async {
    final a = await widget.engine.getAssessment(widget.assessmentId);
    final catalog = await widget.engine.phonemeCatalog();
    return (a, catalog);
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lần chấm')),
      body: FutureBuilder<(Assessment?, Map<String, PhonemeInfo>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e is PronunciationApiException
                      ? e.userMessage
                      : 'Không tải được kết quả.'),
                  TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final (a, catalog) = snap.data!;
          if (a == null) {
            return const Center(
                child: Text('Không tìm thấy kết quả (có thể đã hết phiên).'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(a.referenceText,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(a.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              AssessmentResultView(
                  assessment: a, onSpeak: _speak, catalog: catalog),
            ],
          );
        },
      ),
    );
  }
}
