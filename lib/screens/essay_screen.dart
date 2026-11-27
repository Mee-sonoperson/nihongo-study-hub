// =============================================================================
// essay_screen.dart - 作文ワークスペース(submitType が "essay" の課題で開く)
//
//   3つのタブ:
//     1. Write   : 作文エディタ。保存するたびに下書き(version)が残る
//     2. Recall  : Study Helper。教科書の単語を「思い出す」ための画面
//                  ★AIなし・例文なし・読み上げなし。content.json の vocabulary だけ表示
//     3. Record  : 自分の作文を朗読して録音 → 提出
//
//   すべての行動(検索・ヒント・答えを見た・思い出せた・下書き保存・録音)が
//   app_data.dart に保存され、将来の振り返り・分析に使えます。
// =============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'flow_screens.dart' show openLink, ExampleImages;
import 'portfolio_screen.dart';

class EssayScreen extends StatefulWidget {
  final String assignmentId;
  final int initialTab; // 0 = Write, 1 = Recall, 2 = Record(発表)
  const EssayScreen(this.assignmentId, {super.key, this.initialTab = 0});

  @override
  State<EssayScreen> createState() => _EssayScreenState();
}

class _EssayScreenState extends State<EssayScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  final textCtrl = TextEditingController();
  bool _loadedDraft = false;

  @override
  void initState() {
    super.initState();
    // 最後の下書きをエディタに読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final d = context.read<AppData>().latestDraft(widget.assignmentId);
      if (d != null) textCtrl.text = d.text;
      setState(() => _loadedDraft = true);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final a = data.assignment(widget.assignmentId);
    if (a == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyMessage(Icons.search_off, 'Task not found'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          labelColor: kPrimary,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Write'),
            Tab(icon: Icon(Icons.lightbulb_outline_rounded), text: 'Recall'),
            Tab(icon: Icon(Icons.mic_rounded), text: 'Record'),
          ],
        ),
      ),
      body: SafeArea(
        child: !_loadedDraft
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // やり方説明の動画(先生が assignments の videoUrl に入れたとき)
                  if (a.videoUrl.isNotEmpty)
                    Material(
                      color: kFlame.withValues(alpha: 0.12),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.smart_display_rounded,
                            color: kFlame),
                        title: const Text('How to do this homework (video)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => openLink(context, a.videoUrl),
                      ),
                    ),
                  if (a.exampleImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: ExampleImages(a.exampleImages),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _WriteTab(a: a, ctrl: textCtrl),
                        _RecallTab(a: a),
                        _RecordTab(a: a, textCtrl: textCtrl),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// 1. Write タブ
// =============================================================================
class _WriteTab extends StatefulWidget {
  final Assignment a;
  final TextEditingController ctrl;
  const _WriteTab({required this.a, required this.ctrl});

  @override
  State<_WriteTab> createState() => _WriteTabState();
}

class _WriteTabState extends State<_WriteTab> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final drafts = data.draftsFor(widget.a.id);
    final text = widget.ctrl.text;
    final chars = text.replaceAll(RegExp(r'\s'), '').length;
    final used = data.vocabUsedIn(text);
    final target = data.vocabForAssignment(widget.a);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- 課題の説明 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: kPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.a.description,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.grey.shade800)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- エディタ ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: widget.ctrl,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(fontSize: 16, height: 1.8),
              decoration: const InputDecoration(
                hintText: 'ここに作文を書いてください。\nWrite your essay here in Japanese.',
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ---- 文字数 & 使った教科書の単語 ----
        Row(
          children: [
            Tag('$chars characters', color: kPrimary, icon: Icons.text_fields),
            const SizedBox(width: 8),
            Tag('${used.length}/${target.length} textbook items used',
                color: used.isEmpty ? Colors.grey.shade600 : kGreen,
                icon: Icons.menu_book_rounded),
          ],
        ),
        if (used.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: used
                .map((v) => Tag(v.word, color: categoryColor('Vocabulary')))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: BigButton(
                text: 'Save draft',
                icon: Icons.save_outlined,
                outlined: true,
                onPressed: () async {
                  if (text.trim().isEmpty) {
                    showMessage(context, 'Write something first');
                    return;
                  }
                  final d = await data.saveDraft(widget.a.id, text);
                  if (context.mounted) {
                    showMessage(context, 'Draft v${d.version} saved');
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BigButton(
                text: 'Submit text',
                icon: Icons.send_rounded,
                onPressed: () async {
                  if (text.trim().isEmpty) {
                    showMessage(context, 'Write something first');
                    return;
                  }
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Submit your essay?'),
                      content: Text(
                          '$chars characters. Don\'t forget to record your reading in the "Record" tab too.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Submit')),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  await data.saveDraft(widget.a.id, text);
                  await data.submitEssayText(widget.a, text);
                  if (context.mounted) {
                    showMessage(context, 'Essay submitted! Saved to Portfolio.');
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ---- 下書き履歴 ----
        if (drafts.isNotEmpty) ...[
          SectionTitle('Draft history (${drafts.length})'),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < drafts.length; i++) ...[
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: kPrimary.withValues(alpha: 0.12),
                      child: Text('v${drafts[i].version}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kPrimary,
                              fontWeight: FontWeight.w700)),
                    ),
                    title: Text(
                        '${drafts[i].charCount} chars · ${drafts[i].usedVocabIds.length} textbook items',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(fmtDateTime(drafts[i].dateTime),
                        style: const TextStyle(fontSize: 11)),
                    trailing: TextButton(
                      child: const Text('Restore'),
                      onPressed: () {
                        widget.ctrl.text = drafts[i].text;
                        showMessage(context, 'Restored v${drafts[i].version}');
                      },
                    ),
                  ),
                  if (i < drafts.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 2. Recall タブ(Study Helper)
//    ★ここが重要: 意味や例文は「最初は隠す」。学生が思い出してから確認する。
// =============================================================================
class _RecallTab extends StatefulWidget {
  final Assignment a;
  const _RecallTab({required this.a});

  @override
  State<_RecallTab> createState() => _RecallTabState();
}

class _RecallTabState extends State<_RecallTab> {
  final searchCtrl = TextEditingController();
  String query = '';
  Timer? _debounce;
  // 単語ごとの表示状態: 'hidden' / 'hint' / 'revealed'
  final Map<String, String> state = {};
  String typeFilter = 'all'; // all / word / expression / grammar

  @override
  void dispose() {
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() => query = q);
    _debounce?.cancel();
    // 入力が止まってから1秒後に「検索した」記録を残す(1文字ごとに記録しない)
    _debounce = Timer(const Duration(seconds: 1), () {
      if (q.trim().length >= 2) {
        context.read<AppData>().logHelper(widget.a.id, 'search', query: q);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    var items = query.trim().isEmpty
        ? data.vocabForAssignment(widget.a)
        : data.searchVocab(query);
    if (typeFilter != 'all') {
      items = items.where((v) => v.type == typeFilter).toList();
    }
    final remembered = data
        .helperLogsFor(widget.a.id)
        .where((h) => h.action == 'remembered')
        .map((h) => h.vocabId)
        .toSet();

    return Column(
      children: [
        // ---- 説明 ----
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: kSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Try to remember words from your textbook. Tap "Hint" first, then "Show" only if you need it.',
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
        // ---- 検索 ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search: situation, English, reading...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        setState(() => query = '');
                      },
                    ),
              fillColor: Colors.white,
            ),
          ),
        ),
        // ---- 種類フィルタ ----
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('all', 'All'),
              _filterChip('word', 'Words'),
              _filterChip('expression', 'Expressions'),
              _filterChip('grammar', 'Grammar'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(
            children: [
              Text('${items.length} items',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              Text('Remembered: ${remembered.length}',
                  style: const TextStyle(
                      fontSize: 12, color: kGreen, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // ---- 単語カード ----
        Expanded(
          child: items.isEmpty
              ? const EmptyMessage(Icons.menu_book_rounded,
                  'Nothing found in your textbook list.\nTry another word, or ask your teacher.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _vocabCard(
                      context, items[i], remembered.contains(items[i].id)),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final sel = typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: kSecondary,
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
            color: sel ? Colors.white : kTextDark,
            fontWeight: FontWeight.w600,
            fontSize: 12),
        onSelected: (_) => setState(() => typeFilter = value),
      ),
    );
  }

  Widget _vocabCard(BuildContext context, VocabItem v, bool remembered) {
    final data = context.read<AppData>();
    final s = state[v.id] ?? 'hidden';
    final color = v.type == 'grammar'
        ? categoryColor('Grammar')
        : v.type == 'expression'
            ? categoryColor('Speaking')
            : categoryColor('Vocabulary');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tag(v.type, color: color),
                const SizedBox(width: 6),
                if (v.textbookRef.isNotEmpty)
                  Tag(v.textbookRef,
                      color: Colors.grey.shade700, icon: Icons.book_outlined),
                const Spacer(),
                if (remembered)
                  const Icon(Icons.check_circle, color: kGreen, size: 20),
              ],
            ),
            const SizedBox(height: 10),

            // ---- 英語の意味は常に見せる(これが「問題」)----
            Text(v.meaning,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            if (v.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(v.tags.join(' · '),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 10),

            // ---- 日本語は隠す → ヒント → 表示 ----
            if (s == 'hidden')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('？？？  Can you remember it in Japanese?',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
                ),
              )
            else if (s == 'hint')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: kOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          v.hint.isNotEmpty
                              ? v.hint
                              : 'No hint for this item. Think about ${v.textbookRef}.',
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(v.word,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    if (v.reading.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(v.reading,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade700)),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // ---- ボタン ----
            Row(
              children: [
                if (s == 'hidden')
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => state[v.id] = 'hint');
                      data.logHelper(widget.a.id, 'hint', vocabId: v.id);
                    },
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Hint'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kOrange,
                        side: const BorderSide(color: kOrange)),
                  ),
                if (s != 'revealed') ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => state[v.id] = 'revealed');
                      data.logHelper(widget.a.id, 'reveal', vocabId: v.id);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Show'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => state[v.id] = 'revealed');
                      data.logHelper(widget.a.id, 'remembered',
                          vocabId: v.id);
                      showMessage(context, 'Great! You remembered it.');
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('I remembered'),
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                  ),
                ] else ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => state[v.id] = 'hidden'),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Hide again'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. Record タブ(朗読して録音 → 提出)
// =============================================================================
class _RecordTab extends StatefulWidget {
  final Assignment a;
  final TextEditingController textCtrl; // Write タブと同じテキストを常に表示
  const _RecordTab({required this.a, required this.textCtrl});

  @override
  State<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<_RecordTab> {
  final _recorder = AudioRecorder();
  bool recording = false;
  int seconds = 0;
  Timer? _timer;
  Uint8List? recordedBytes;
  String recordedExt = 'm4a';

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) showMessage(context, 'Microphone permission is needed');
      return;
    }
    // Web では webm/opus、Android では m4a(AAC)で録音される
    const config = RecordConfig(encoder: AudioEncoder.aacLc);
    await _recorder.start(config, path: 'reading_${widget.a.id}.m4a');
    setState(() {
      recording = true;
      seconds = 0;
      recordedBytes = null;
    });
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => seconds++));
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() => recording = false);
    if (path == null) return;
    // Web: path は blob: URL。Android: ファイルパス。両方 bytes に変換する
    final bytes = await _readBytes(path);
    if (bytes != null && mounted) {
      setState(() {
        recordedBytes = bytes;
        recordedExt = path.endsWith('.webm') || path.startsWith('blob:')
            ? 'webm'
            : 'm4a';
      });
    }
  }

  /// XFile は Web(blob: URL)でも Android(ファイルパス)でも同じ書き方で読める
  Future<Uint8List?> _readBytes(String path) async {
    try {
      return await XFile(path).readAsBytes();
    } catch (e) {
      debugPrint('read recording error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final recordings = data
        .submissionsFor(widget.a.id)
        .where((s) => s.fileType == 'audio')
        .toList();
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final essayText = widget.textCtrl.text;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- 自分の作文(読みながら録音する)----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Read your essay aloud',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  essayText.trim().isEmpty
                      ? '(Write your essay in the "Write" tab first)'
                      : essayText,
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.9,
                      color: essayText.trim().isEmpty
                          ? Colors.grey
                          : kTextDark),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 録音ボタン ----
        Center(
          child: Column(
            children: [
              Text(recording ? '$mm:$ss' : (recordedBytes != null ? 'Recorded $mm:$ss' : 'Tap to record'),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: recording ? kRed : kTextDark)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: recording ? _stop : _start,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: recording ? kRed : kPrimary,
                    boxShadow: [
                      BoxShadow(
                          color: (recording ? kRed : kPrimary)
                              .withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(
                      recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 44),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                recording
                    ? 'Recording... tap to stop'
                    : 'Your voice only. No sample audio is provided.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (recordedBytes != null) ...[
          BigButton(
            text: 'Submit this recording (${fmtBytes(recordedBytes!.length)})',
            icon: Icons.upload_rounded,
            color: kGreen,
            onPressed: () async {
              await data.submitRecording(widget.a, recordedBytes!, recordedExt);
              await data.logHelper(widget.a.id, 'recording_submitted',
                  query: '${seconds}s');
              setState(() => recordedBytes = null);
              if (context.mounted) {
                showMessage(context, 'Recording submitted! Saved to Portfolio.');
              }
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => recordedBytes = null),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Discard and record again'),
          ),
          const SizedBox(height: 12),
        ],

        // ---- 提出済みの録音 ----
        if (recordings.isNotEmpty) ...[
          SectionTitle('My recordings (${recordings.length})'),
          ...recordings.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(child: SubmissionTile(s)),
              )),
        ],
      ],
    );
  }
}
