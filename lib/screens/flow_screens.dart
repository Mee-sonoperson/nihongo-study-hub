// =============================================================================
// flow_screens.dart - 1課の流れ(Lesson steps)
//
//   授業の画面に「Lesson steps」を表示し、ステップを順番にこなす。
//   ステップの種類(シートの steps タブの type):
//     listen       聞いてみよう(vocabulary の単語を音声で聞く)
//     video        オンデマンド視聴(lessons の動画と資料)
//     grammar      文法チェック(grammar タブの選択問題)
//     dialog       会話を聞く(dialog タブのセリフを順に再生)
//     roleplay     会話練習(A = 教科書の音声、B = 学生が録音して答える)
//     essay        作文(課題の作文画面を開く)
//     presentation 発表(課題の作文画面の Record タブを開く)
// =============================================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'essay_screen.dart';

// -----------------------------------------------------------------------------
// 共通の小さな道具
// -----------------------------------------------------------------------------

/// ステップの種類ごとのアイコンと名前
IconData stepIcon(String type) {
  switch (type) {
    case 'listen':
      return Icons.hearing_rounded;
    case 'video':
      return Icons.play_circle_outline_rounded;
    case 'grammar':
      return Icons.rule_rounded;
    case 'dialog':
      return Icons.forum_outlined;
    case 'roleplay':
      return Icons.record_voice_over_rounded;
    case 'essay':
      return Icons.edit_note_rounded;
    case 'presentation':
      return Icons.mic_rounded;
  }
  return Icons.circle_outlined;
}

String stepTypeLabel(String type) {
  switch (type) {
    case 'listen':
      return 'Listen';
    case 'video':
      return 'Video';
    case 'grammar':
      return 'Grammar check';
    case 'dialog':
      return 'Conversation';
    case 'roleplay':
      return 'Role-play';
    case 'essay':
      return 'Writing';
    case 'presentation':
      return 'Presentation';
  }
  return type;
}

/// Google ドライブの共有リンクを、そのまま再生できる URL に変える
String playableUrl(String url) {
  final u = url.trim();
  final m = RegExp(r'drive\.google\.com/(?:file/d/|open\?id=|uc\?(?:export=\w+&)?id=)([\w-]+)')
      .firstMatch(u);
  if (m != null) {
    return 'https://drive.usercontent.google.com/download?id=${m[1]}&export=download';
  }
  return u;
}

/// リンクを開く(YouTube・ドライブなど)
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      url.trim().isEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showMessage(context, 'Could not open the link.');
  }
}

/// 音声の再生(1つずつ。終わるまで待てる)
class Sound {
  static final AudioPlayer _player = AudioPlayer();
  static Completer<void>? _waiting;

  /// URL の音声を再生して、終わるまで待つ
  static Future<void> playUrl(String url) =>
      _play(UrlSource(playableUrl(url)));

  /// 自分の録音を再生(Web は blob: URL、スマホはファイル)
  static Future<void> playRecording(String path) => _play(
      kIsWeb || path.startsWith('blob:') || path.startsWith('http')
          ? UrlSource(path)
          : DeviceFileSource(path));

  static Future<void> _play(Source src) async {
    await stop();
    final done = Completer<void>();
    _waiting = done;
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(src);
    } catch (e) {
      debugPrint('audio error: $e');
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    await sub.cancel();
  }

  static Future<void> stop() async {
    final w = _waiting;
    if (w != null && !w.isCompleted) w.complete();
    await _player.stop();
  }
}

/// ステップの説明と「やり方の動画」
class _StepHeader extends StatelessWidget {
  final Map step;
  const _StepHeader(this.step);

  @override
  Widget build(BuildContext context) {
    final text = '${step['instructions'] ?? ''}';
    final video = '${step['videoUrl'] ?? ''}';
    if (text.isEmpty && video.isEmpty) return const SizedBox.shrink();
    return Card(
      color: kPrimary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: kPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(text,
                          style: const TextStyle(height: 1.5, fontSize: 14))),
                ],
              ),
            if (video.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openLink(context, video),
                icon: const Icon(Icons.smart_display_outlined),
                label: const Text('How to do this step (video)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 一番下の「終わった」ボタン
Widget _doneButton(BuildContext context, Map step,
    {String text = 'I finished this step', int? score, int? total}) {
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: BigButton(
      text: text,
      icon: Icons.check_rounded,
      color: kGreen,
      onPressed: () async {
        await Sound.stop();
        if (!context.mounted) return;
        await context
            .read<AppData>()
            .completeStep('${step['id']}', score: score, total: total);
        if (context.mounted) Navigator.pop(context);
      },
    ),
  );
}

// =============================================================================
// 授業の画面に出す「Lesson steps」カード
// =============================================================================
class LessonStepsCard extends StatelessWidget {
  final String lessonId;
  const LessonStepsCard(this.lessonId, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final steps = data.stepsFor(lessonId);
    if (steps.isEmpty) return const SizedBox.shrink();
    final doneCount = steps.where(data.isStepDone).length;
    final nextIndex = steps.indexWhere((s) => !data.isStepDone(s));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: kPrimary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Lesson steps',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Text('$doneCount / ${steps.length} done',
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: steps.isEmpty ? 0 : doneCount / steps.length,
                    minHeight: 8,
                    color: kGreen,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
              for (var i = 0; i < steps.length; i++)
                _StepTile(
                  step: steps[i],
                  number: i + 1,
                  done: data.isStepDone(steps[i]),
                  isNext: i == nextIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final Map step;
  final int number;
  final bool done;
  final bool isNext;
  const _StepTile(
      {required this.step,
      required this.number,
      required this.done,
      required this.isNext});

  @override
  Widget build(BuildContext context) {
    final type = '${step['type']}';
    final progress = context.read<AppData>().stepProgress('${step['id']}');
    final score = progress?['score'];
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: done
            ? kGreen
            : (isNext ? kPrimary : Colors.grey.shade300),
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text('$number',
                style: TextStyle(
                    color: isNext ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w700)),
      ),
      title: Text('${step['title']}',
          style: TextStyle(
              fontWeight: isNext ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Row(
        children: [
          Icon(stepIcon(type), size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(stepTypeLabel(type),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (score != null) ...[
            const SizedBox(width: 8),
            Text('Score: $score / ${progress?['total'] ?? '?'}',
                style: const TextStyle(
                    fontSize: 12, color: kGreen, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
      trailing: isNext
          ? const Tag('Next', color: kPrimary)
          : const Icon(Icons.chevron_right),
      onTap: () => openStep(context, step),
    );
  }
}

/// ステップを開く
void openStep(BuildContext context, Map step) {
  final type = '${step['type']}';
  if (type == 'essay' || type == 'presentation') {
    final id = '${step['assignmentId']}';
    if (context.read<AppData>().assignment(id) == null) {
      showMessage(context, 'The homework for this step is not set yet.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EssayScreen(id, initialTab: type == 'presentation' ? 2 : 0)),
    );
    return;
  }
  Navigator.push(
      context, MaterialPageRoute(builder: (_) => StepScreen(step)));
}

// =============================================================================
// ステップの画面(種類ごとに中身が変わる)
// =============================================================================
class StepScreen extends StatelessWidget {
  final Map step;
  const StepScreen(this.step, {super.key});

  @override
  Widget build(BuildContext context) {
    final type = '${step['type']}';
    Widget body;
    switch (type) {
      case 'listen':
        body = _ListenStep(step);
        break;
      case 'video':
        body = _VideoStep(step);
        break;
      case 'grammar':
        body = _GrammarStep(step);
        break;
      case 'dialog':
        body = _DialogStep(step);
        break;
      case 'roleplay':
        body = _RoleplayStep(step);
        break;
      default:
        body = const EmptyMessage(Icons.help_outline, 'Unknown step type');
    }
    return PopScope(
      onPopInvokedWithResult: (_, __) => Sound.stop(),
      child: Scaffold(
        appBar: AppBar(title: Text('${step['title']}')),
        body: SafeArea(child: body),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. 聞いてみよう(新しい単語を聞く)
// -----------------------------------------------------------------------------
class _ListenStep extends StatefulWidget {
  final Map step;
  const _ListenStep(this.step);
  @override
  State<_ListenStep> createState() => _ListenStepState();
}

class _ListenStepState extends State<_ListenStep> {
  final shown = <String>{};
  String playing = '';

  Future<void> _play(VocabItem v) async {
    setState(() => playing = v.id);
    await Sound.playUrl(v.audioUrl);
    if (mounted) setState(() => playing = '');
  }

  @override
  Widget build(BuildContext context) {
    final words =
        context.watch<AppData>().vocabOfLesson('${widget.step['lessonId']}');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepHeader(widget.step),
        const SizedBox(height: 8),
        if (words.isEmpty)
          const EmptyMessage(Icons.hearing_disabled, 'No words yet'),
        for (final v in words)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filled(
                    iconSize: 30,
                    style: IconButton.styleFrom(
                        backgroundColor:
                            v.audioUrl.isEmpty ? Colors.grey.shade300 : kTeal),
                    onPressed: v.audioUrl.isEmpty ? null : () => _play(v),
                    icon: Icon(playing == v.id
                        ? Icons.graphic_eq_rounded
                        : Icons.volume_up_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: shown.contains(v.id)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.word,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              if (v.reading.isNotEmpty)
                                Text(v.reading,
                                    style: TextStyle(
                                        color: Colors.grey.shade700)),
                              Text(v.meaning,
                                  style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          )
                        : Text(
                            v.audioUrl.isEmpty
                                ? '(No audio yet)'
                                : 'Listen. What does it mean?',
                            style: TextStyle(color: Colors.grey.shade600)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => shown.contains(v.id)
                        ? shown.remove(v.id)
                        : shown.add(v.id)),
                    child: Text(shown.contains(v.id) ? 'Hide' : 'Show'),
                  ),
                ],
              ),
            ),
          ),
        _doneButton(context, widget.step),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 2. オンデマンド視聴
// -----------------------------------------------------------------------------
class _VideoStep extends StatelessWidget {
  final Map step;
  const _VideoStep(this.step);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final l = data.lesson('${step['lessonId']}');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepHeader(step),
        const SizedBox(height: 8),
        if (l == null)
          const EmptyMessage(Icons.videocam_off, 'Lesson not found')
        else ...[
          Text(l.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          BigButton(
            text: 'Watch video',
            icon: Icons.play_arrow_rounded,
            onPressed: () => openLink(context, l.videoUrl),
          ),
          if (l.materials.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionTitle('Lesson materials'),
            for (final m in l.materials)
              Card(
                child: ListTile(
                  leading: const IconBox(Icons.description_outlined,
                      color: kTeal),
                  title: Text(m['title'] ?? 'Material'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openLink(context, m['url'] ?? ''),
                ),
              ),
          ],
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: BigButton(
            text: 'I watched the video',
            icon: Icons.check_rounded,
            color: kGreen,
            onPressed: () async {
              if (l != null) await data.setLessonProgress(l, 1);
              await data.completeStep('${step['id']}');
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 3. 文法チェック(選択問題)
// -----------------------------------------------------------------------------
class _GrammarStep extends StatefulWidget {
  final Map step;
  const _GrammarStep(this.step);
  @override
  State<_GrammarStep> createState() => _GrammarStepState();
}

class _GrammarStepState extends State<_GrammarStep> {
  int index = 0;
  int? selected;
  bool checked = false;
  int correct = 0;

  @override
  Widget build(BuildContext context) {
    final qs =
        context.watch<AppData>().grammarFor('${widget.step['lessonId']}');
    if (qs.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _StepHeader(widget.step),
        const EmptyMessage(Icons.rule, 'No questions yet'),
      ]);
    }

    // 全問おわり
    if (index >= qs.length) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 30),
          Icon(Icons.emoji_events_rounded,
              size: 72,
              color: correct == qs.length ? kFlame : Colors.grey.shade500),
          const SizedBox(height: 12),
          Text('You got $correct / ${qs.length}',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              index = 0;
              correct = 0;
              selected = null;
              checked = false;
            }),
            icon: const Icon(Icons.replay),
            label: const Text('Try again'),
          ),
          _doneButton(context, widget.step,
              text: 'Save my score', score: correct, total: qs.length),
        ],
      );
    }

    final q = qs[index];
    final answer = int.tryParse('${q['answer']}') ?? 0;
    final choices = <int, String>{};
    for (var i = 1; i <= 4; i++) {
      final c = '${q['choice$i'] ?? ''}'.trim();
      if (c.isNotEmpty) choices[i] = c;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (index == 0) _StepHeader(widget.step),
        const SizedBox(height: 8),
        Text('Question ${index + 1} / ${qs.length}',
            style: TextStyle(
                color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${q['question']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        for (final e in choices.entries)
          Card(
            color: !checked
                ? (selected == e.key ? kPrimary.withValues(alpha: 0.12) : null)
                : (e.key == answer
                    ? kGreen.withValues(alpha: 0.18)
                    : (selected == e.key
                        ? kRed.withValues(alpha: 0.15)
                        : null)),
            child: ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: kPrimary.withValues(alpha: 0.12),
                child: Text('${e.key}',
                    style: const TextStyle(fontSize: 12, color: kPrimary)),
              ),
              title: Text(e.value, style: const TextStyle(fontSize: 18)),
              trailing: checked && e.key == answer
                  ? const Icon(Icons.check_circle, color: kGreen)
                  : (checked && selected == e.key
                      ? const Icon(Icons.cancel, color: kRed)
                      : null),
              onTap: checked ? null : () => setState(() => selected = e.key),
            ),
          ),
        if (checked && '${q['explanation'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${q['explanation']}',
                  style: const TextStyle(height: 1.5)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!checked)
          BigButton(
            text: 'Check',
            icon: Icons.fact_check_outlined,
            onPressed: () {
              if (selected == null) {
                showMessage(context, 'Choose an answer first');
                return;
              }
              setState(() {
                checked = true;
                if (selected == answer) correct++;
              });
            },
          )
        else
          BigButton(
            text: index + 1 < qs.length ? 'Next question' : 'See my score',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() {
              index++;
              selected = null;
              checked = false;
            }),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 4. 会話を聞く
// -----------------------------------------------------------------------------
class _DialogStep extends StatefulWidget {
  final Map step;
  const _DialogStep(this.step);
  @override
  State<_DialogStep> createState() => _DialogStepState();
}

class _DialogStepState extends State<_DialogStep> {
  bool showText = false;
  int playing = -1;
  bool playingAll = false;

  Future<void> _playLine(List<Map> lines, int i) async {
    setState(() => playing = i);
    await Sound.playUrl('${lines[i]['audioUrl'] ?? ''}');
    if (mounted) setState(() => playing = -1);
  }

  Future<void> _playAll(List<Map> lines) async {
    setState(() => playingAll = true);
    for (var i = 0; i < lines.length; i++) {
      if (!mounted || !playingAll) break;
      if ('${lines[i]['audioUrl'] ?? ''}'.isEmpty) continue;
      await _playLine(lines, i);
    }
    if (mounted) setState(() => playingAll = false);
  }

  @override
  void dispose() {
    playingAll = false;
    Sound.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines =
        context.watch<AppData>().dialogFor('${widget.step['lessonId']}');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepHeader(widget.step),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: lines.isEmpty
                    ? null
                    : (playingAll
                        ? () {
                            setState(() => playingAll = false);
                            Sound.stop();
                          }
                        : () => _playAll(lines)),
                icon: Icon(playingAll ? Icons.stop : Icons.play_arrow),
                label: Text(playingAll ? 'Stop' : 'Play all'),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('Show text'),
              selected: showText,
              onSelected: (v) => setState(() => showText = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lines.isEmpty)
          const EmptyMessage(Icons.forum_outlined, 'No conversation yet'),
        for (var i = 0; i < lines.length; i++)
          _LineBubble(
            line: lines[i],
            showText: showText,
            highlight: playing == i,
            trailing: '${lines[i]['audioUrl'] ?? ''}'.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => _playLine(lines, i),
                  ),
          ),
        _doneButton(context, widget.step),
      ],
    );
  }
}

/// 会話の吹き出し(A は左、B は右)
class _LineBubble extends StatelessWidget {
  final Map line;
  final bool showText;
  final bool highlight;
  final Widget? trailing;
  final String? overrideText;
  const _LineBubble(
      {required this.line,
      required this.showText,
      this.highlight = false,
      this.trailing,
      this.overrideText});

  @override
  Widget build(BuildContext context) {
    final isA = '${line['speaker']}'.toUpperCase() != 'B';
    final color = isA ? kTeal : kSecondary;
    final text = overrideText ??
        (showText ? '${line['text'] ?? ''}' : '・・・');
    final translation = '${line['translation'] ?? ''}';
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: highlight ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: highlight ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 18, height: 1.4)),
            if (showText && translation.isNotEmpty && overrideText == null)
              Text(translation,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(isA ? 'A' : 'B',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isA ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: isA
            ? [avatar, const SizedBox(width: 8), bubble, if (trailing != null) trailing!]
            : [if (trailing != null) trailing!, bubble, const SizedBox(width: 8), avatar],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. 会話練習(A = 音声が流れる、B = 学生が録音して答える)
// -----------------------------------------------------------------------------
class _RoleplayStep extends StatefulWidget {
  final Map step;
  const _RoleplayStep(this.step);
  @override
  State<_RoleplayStep> createState() => _RoleplayStepState();
}

class _RoleplayStepState extends State<_RoleplayStep> {
  final _recorder = AudioRecorder();
  int current = 0; // 今のセリフの番号
  bool busy = false; // A の音声が流れている
  bool recording = false;
  final hints = <int>{}; // ヒント(B のセリフ)を見た行
  final recordings = <int, String>{}; // 行番号 → 録音(blob: URL / パス)
  final recordedBytes = <int, Uint8List>{};
  bool saved = false;

  @override
  void dispose() {
    _recorder.dispose();
    Sound.stop();
    super.dispose();
  }

  bool _isA(Map line) => '${line['speaker']}'.toUpperCase() != 'B';

  Future<void> _playA(List<Map> lines) async {
    setState(() => busy = true);
    await Sound.playUrl('${lines[current]['audioUrl'] ?? ''}');
    if (!mounted) return;
    setState(() {
      busy = false;
      current++;
    });
  }

  Future<void> _startB() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) showMessage(context, 'Microphone permission is needed');
      return;
    }
    await Sound.stop();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: 'roleplay_$current.m4a');
    setState(() => recording = true);
  }

  Future<void> _stopB() async {
    final path = await _recorder.stop();
    if (path != null) {
      recordings[current] = path;
      try {
        recordedBytes[current] = await XFile(path).readAsBytes();
      } catch (e) {
        debugPrint('read recording error: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      recording = false;
      current++;
    });
  }

  Future<void> _playConversation(List<Map> lines) async {
    setState(() => busy = true);
    for (var i = 0; i < lines.length; i++) {
      if (!mounted) return;
      if (_isA(lines[i])) {
        await Sound.playUrl('${lines[i]['audioUrl'] ?? ''}');
      } else if (recordings[i] != null) {
        await Sound.playRecording(recordings[i]!);
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save(String lessonTitle) async {
    final data = context.read<AppData>();
    final id = data.studentId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    var n = 0;
    for (final e in recordedBytes.entries) {
      n++;
      final ext = (recordings[e.key] ?? '').endsWith('.m4a') && !kIsWeb
          ? 'm4a'
          : 'webm';
      await data.addSubmission(
        assignmentId: '',
        title: 'Role-play: $lessonTitle (B line $n)',
        fileName:
            '${id.isEmpty ? '' : '${id}_'}roleplay_${widget.step['lessonId']}_$n.$ext',
        bytes: e.value,
        note: 'Role-play practice',
      );
    }
    await data.completeStep('${widget.step['id']}');
    if (mounted) {
      setState(() => saved = true);
      showMessage(context, 'Saved to your Portfolio');
    }
  }

  void _restart() {
    Sound.stop();
    setState(() {
      current = 0;
      hints.clear();
      recordings.clear();
      recordedBytes.clear();
      saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final lessonId = '${widget.step['lessonId']}';
    final lines = data.dialogFor(lessonId);
    final lessonTitle = data.lesson(lessonId)?.title ?? lessonId;
    if (lines.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _StepHeader(widget.step),
        const EmptyMessage(Icons.forum_outlined, 'No conversation yet'),
      ]);
    }
    final finished = current >= lines.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StepHeader(widget.step),
        const SizedBox(height: 8),
        // ここまでのセリフ
        for (var i = 0; i < lines.length && i <= current; i++)
          if (i < current || finished)
            _LineBubble(
              line: lines[i],
              showText: true,
              overrideText: _isA(lines[i])
                  ? null
                  : (recordings[i] != null ? '🎙 My answer' : '(skipped)'),
              trailing: !_isA(lines[i]) && recordings[i] != null
                  ? IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => Sound.playRecording(recordings[i]!),
                    )
                  : null,
            ),

        const SizedBox(height: 12),
        if (!finished) ...[
          // 今のセリフ
          if (_isA(lines[current])) ...[
            _LineBubble(
                line: lines[current],
                showText: true,
                highlight: true),
            const SizedBox(height: 12),
            BigButton(
              text: busy ? 'A is speaking…' : '▶  Play A',
              icon: Icons.volume_up_rounded,
              color: kTeal,
              onPressed: busy ? () {} : () => _playA(lines),
            ),
          ] else ...[
            Card(
              color: kSecondary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Text('Your turn! You are B.',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (hints.contains(current))
                      Text('${lines[current]['text']}',
                          style: const TextStyle(fontSize: 18))
                    else
                      TextButton.icon(
                        onPressed: () => setState(() => hints.add(current)),
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Show hint'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BigButton(
              text: recording ? '■  Stop' : '●  B: Answer',
              icon: recording ? Icons.stop_rounded : Icons.mic_rounded,
              color: recording ? kRed : kSecondary,
              onPressed: recording ? _stopB : _startB,
            ),
            TextButton(
              onPressed: recording ? null : () => setState(() => current++),
              child: const Text('Skip this line'),
            ),
          ],
        ] else ...[
          // 全部おわり
          const Text('Great job! Listen to your conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          BigButton(
            text: busy ? 'Playing…' : 'Listen to our conversation',
            icon: Icons.headphones_rounded,
            color: kTeal,
            onPressed: busy ? () {} : () => _playConversation(lines),
          ),
          const SizedBox(height: 10),
          if (!saved)
            BigButton(
              text: 'Save to my Portfolio',
              icon: Icons.save_alt_rounded,
              color: kGreen,
              onPressed: () => _save(lessonTitle),
            )
          else
            BigButton(
              text: 'Back to the lesson',
              icon: Icons.arrow_back_rounded,
              color: kGreen,
              onPressed: () => Navigator.pop(context),
            ),
          TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}
