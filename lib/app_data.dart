// =============================================================================
// app_data.dart
// アプリで使う「データの形」と「保存・読み込み」をすべてこのファイルにまとめています。
// 何かデータ項目を増やしたいときは、このファイルだけ見れば OK です。
//
//  - Lesson      : オンデマンド授業(管理者が content.json に追加)
//  - Assignment  : 宿題・テスト(管理者が content.json に追加)
//  - Notice      : お知らせ(管理者が content.json に追加)
//  - StudyLog    : 学習記録(学習者がアプリで追加)
//  - Submission  : 提出物(PDF / 音声 / 画像)→ ポートフォリオになる
//  - VocabItem   : 教科書に出た単語・表現(管理者が content.json に追加)← Study Helper の元データ
//  - EssayDraft  : 作文の下書き履歴(学習者が書くたびに保存)
//  - HelperLog   : Study Helper で「思い出した」「調べた」記録(学習者)
//
// 保存先はスマホ内のデータベース(Hive)。インターネット無しでも動きます。
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'sheet_loader.dart';

// -----------------------------------------------------------------------------
// 1. データの形(クラス)
//    すべて「Map(辞書)に変換して保存」「Mapから元に戻す」の2つの関数を持っています。
// -----------------------------------------------------------------------------

/// オンデマンド授業
class Lesson {
  String id; // 例: "lesson_13"  ※他と重複しない文字列
  int number; // 第◯回
  String title; // タイトル
  String teacher; // 先生の名前
  String category; // "Kanji" / "Vocabulary" / "Grammar" / "Listening" / "Reading" / "Speaking"
  int minutes; // 動画の長さ(分)
  String description; // 授業の説明
  String videoUrl; // 動画のURL(YouTube限定公開・Google Drive・Vimeo など)
  String publishedAt; // 公開日 "2026-11-25"
  String availableUntil; // 視聴期限 "2026-12-09"(空文字なら無期限)
  List<Map<String, String>> materials; // 授業資料: [{"title": "Slides", "url": "https://..."}]
  // ↓ 学習者側の状態(管理者は触らない)
  double progress; // 0.0〜1.0 視聴進捗
  bool watched; // 視聴済み?

  Lesson({
    required this.id,
    required this.number,
    required this.title,
    this.teacher = '',
    this.category = 'Grammar',
    this.minutes = 0,
    this.description = '',
    this.videoUrl = '',
    this.publishedAt = '',
    this.availableUntil = '',
    this.materials = const [],
    this.progress = 0,
    this.watched = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'title': title,
    'teacher': teacher,
    'category': category,
    'minutes': minutes,
    'description': description,
    'videoUrl': videoUrl,
    'publishedAt': publishedAt,
    'availableUntil': availableUntil,
    'materials': materials,
    'progress': progress,
    'watched': watched,
  };

  static Lesson fromMap(Map m) => Lesson(
    id: '${m['id'] ?? ''}',
    number: _int(m['number']),
    title: '${m['title'] ?? ''}',
    teacher: '${m['teacher'] ?? ''}',
    category: '${m['category'] ?? 'Grammar'}',
    minutes: _int(m['minutes']),
    description: '${m['description'] ?? ''}',
    videoUrl: '${m['videoUrl'] ?? ''}',
    publishedAt: '${m['publishedAt'] ?? ''}',
    availableUntil: '${m['availableUntil'] ?? ''}',
    materials: (m['materials'] as List? ?? [])
        .map((e) => {
              'title': '${(e as Map)['title'] ?? ''}',
              'url': '${e['url'] ?? ''}',
            })
        .toList(),
    progress: (m['progress'] as num?)?.toDouble() ?? 0,
    watched: m['watched'] == true,
  );
}

/// 宿題・テスト
class Assignment {
  String id; // 例: "hw_12"
  String title;
  String type; // "Homework" または "Test"
  String subject; // "Kanji" / "Writing" / "Grammar" など自由
  String dueDate; // 締切 "2026-11-30 23:59"
  String description;
  String submitType; // 求める提出物: "pdf" / "audio" / "image" / "any" / "none"
  int maxScore; // テストの満点(0なら未設定)
  String relatedLessonId; // 関連する授業のid(無ければ空)
  String instructions; // 手順(; 区切り)
  String criteria; // 評価のポイント(; 区切り)
  List<Map<String, String>> materials; // 課題の資料 [{"title","url"}]
  String videoUrl; // やり方説明の動画(1分ほど)
  String exampleImages; // 作文の例文の写真(ドライブのリンク。; 区切り)
  // ↓ 学習者側の状態
  bool done; // 提出済み/受験済み
  String doneAt; // 完了日時
  int score; // 得点(-1なら未入力)

  Assignment({
    required this.id,
    required this.title,
    this.type = 'Homework',
    this.subject = '',
    this.dueDate = '',
    this.description = '',
    this.submitType = 'any',
    this.maxScore = 0,
    this.relatedLessonId = '',
    this.instructions = '',
    this.criteria = '',
    this.materials = const [],
    this.videoUrl = '',
    this.exampleImages = '',
    this.done = false,
    this.doneAt = '',
    this.score = -1,
  });

  bool get isTest => type == 'Test';
  DateTime get due => DateTime.tryParse(dueDate) ?? DateTime(2100);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type,
    'subject': subject,
    'dueDate': dueDate,
    'description': description,
    'submitType': submitType,
    'maxScore': maxScore,
    'relatedLessonId': relatedLessonId,
    'instructions': instructions,
    'criteria': criteria,
    'materials': materials,
    'videoUrl': videoUrl,
    'exampleImages': exampleImages,
    'done': done,
    'doneAt': doneAt,
    'score': score,
  };

  static Assignment fromMap(Map m) => Assignment(
    id: '${m['id'] ?? ''}',
    title: '${m['title'] ?? ''}',
    type: '${m['type'] ?? 'Homework'}',
    subject: '${m['subject'] ?? ''}',
    dueDate: '${m['dueDate'] ?? ''}',
    description: '${m['description'] ?? ''}',
    submitType: '${m['submitType'] ?? 'any'}',
    maxScore: _int(m['maxScore']),
    relatedLessonId: '${m['relatedLessonId'] ?? ''}',
    instructions: '${m['instructions'] ?? ''}',
    criteria: '${m['criteria'] ?? ''}',
    materials: _materialsFrom(m['materials']),
    videoUrl: '${m['videoUrl'] ?? ''}',
    exampleImages: '${m['exampleImages'] ?? ''}',
    done: m['done'] == true,
    doneAt: '${m['doneAt'] ?? ''}',
    score: m['score'] == null ? -1 : _int(m['score']),
  );
}

/// お知らせ
class Notice {
  String id; // 例: "notice_8"
  String title;
  String body;
  String category; // "Important" / "Lesson" / "Homework" / "Test" / "General"
  String date; // "2026-11-25 09:00"
  String sender; // 送信者(先生名・事務局)
  String relatedAssignmentId; // 関連する課題のid(無ければ空)
  String relatedLessonId; // 関連する授業のid(無ければ空)
  bool read; // 学習者が読んだ?

  Notice({
    required this.id,
    required this.title,
    this.body = '',
    this.category = 'General',
    this.date = '',
    this.sender = 'School Office',
    this.relatedAssignmentId = '',
    this.relatedLessonId = '',
    this.read = false,
  });

  DateTime get dateTime => DateTime.tryParse(date) ?? DateTime(2000);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'date': date,
    'sender': sender,
    'relatedAssignmentId': relatedAssignmentId,
    'relatedLessonId': relatedLessonId,
    'read': read,
  };

  static Notice fromMap(Map m) => Notice(
    id: '${m['id'] ?? ''}',
    title: '${m['title'] ?? ''}',
    body: '${m['body'] ?? ''}',
    category: '${m['category'] ?? 'General'}',
    date: '${m['date'] ?? ''}',
    sender: '${m['sender'] ?? 'School Office'}',
    relatedAssignmentId: '${m['relatedAssignmentId'] ?? ''}',
    relatedLessonId: '${m['relatedLessonId'] ?? ''}',
    read: m['read'] == true,
  );
}

/// 学習記録(学習者が追加)
class StudyLog {
  String id;
  String date; // "2026-11-25 20:30"
  int minutes;
  String category; // Kanji / Vocabulary / ...
  String note;

  StudyLog({
    required this.id,
    required this.date,
    required this.minutes,
    required this.category,
    this.note = '',
  });

  DateTime get dateTime => DateTime.tryParse(date) ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'minutes': minutes,
    'category': category,
    'note': note,
  };

  static StudyLog fromMap(Map m) => StudyLog(
    id: '${m['id'] ?? ''}',
    date: '${m['date'] ?? ''}',
    minutes: _int(m['minutes']),
    category: '${m['category'] ?? 'Vocabulary'}',
    note: '${m['note'] ?? ''}',
  );
}

/// 提出物(PDF・録音・画像)。これがポートフォリオになります。
/// ファイルの中身(bytes)は別の箱(filesBox)に保存して、一覧を軽くしています。
class Submission {
  String id;
  String assignmentId; // どの課題への提出か("" なら自由提出)
  String title; // 表示名(課題名など)
  String fileName; // "homework5.pdf"
  String fileType; // "pdf" / "audio" / "image" / "other"
  int sizeBytes;
  String submittedAt; // "2026-11-25 21:00"
  String note; // 学習者のメモ(振り返り)
  String teacherComment; // 先生からのコメント(今後の拡張用)

  Submission({
    required this.id,
    required this.assignmentId,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.sizeBytes,
    required this.submittedAt,
    this.note = '',
    this.teacherComment = '',
  });

  DateTime get dateTime => DateTime.tryParse(submittedAt) ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'assignmentId': assignmentId,
    'title': title,
    'fileName': fileName,
    'fileType': fileType,
    'sizeBytes': sizeBytes,
    'submittedAt': submittedAt,
    'note': note,
    'teacherComment': teacherComment,
  };

  static Submission fromMap(Map m) => Submission(
    id: '${m['id'] ?? ''}',
    assignmentId: '${m['assignmentId'] ?? ''}',
    title: '${m['title'] ?? ''}',
    fileName: '${m['fileName'] ?? ''}',
    fileType: '${m['fileType'] ?? 'other'}',
    sizeBytes: _int(m['sizeBytes']),
    submittedAt: '${m['submittedAt'] ?? ''}',
    note: '${m['note'] ?? ''}',
    teacherComment: '${m['teacherComment'] ?? ''}',
  );
}

/// 教科書に出た単語・表現(Study Helper が「思い出すヒント」として使う)
/// ★AIは使いません。ここに書いてあるものしか表示されないので、安全です。
class VocabItem {
  String id; // 例: "v_l5_01"
  String word; // 単語・表現: "週末"
  String reading; // 読み: "しゅうまつ"
  String meaning; // 英語の意味: "weekend"
  String type; // "word" / "expression" / "grammar"
  String lessonId; // 出てきた授業の id(無ければ空)
  String textbookRef; // 教科書の場所: "Lesson 5, p.42"
  List<String> tags; // 使える場面: ["daily life", "time"]
  String hint; // 思い出すためのヒント(意味や例文ではなく、場面・頭文字など)
  String audioUrl; // 単語の音声(「聞いてみよう」で再生)

  VocabItem({
    required this.id,
    required this.word,
    this.reading = '',
    this.meaning = '',
    this.type = 'word',
    this.lessonId = '',
    this.textbookRef = '',
    this.tags = const [],
    this.hint = '',
    this.audioUrl = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'audioUrl': audioUrl,
    'word': word,
    'reading': reading,
    'meaning': meaning,
    'type': type,
    'lessonId': lessonId,
    'textbookRef': textbookRef,
    'tags': tags,
    'hint': hint,
  };

  static VocabItem fromMap(Map m) => VocabItem(
    id: '${m['id'] ?? ''}',
    word: '${m['word'] ?? ''}',
    reading: '${m['reading'] ?? ''}',
    meaning: '${m['meaning'] ?? ''}',
    type: '${m['type'] ?? 'word'}',
    lessonId: '${m['lessonId'] ?? ''}',
    textbookRef: '${m['textbookRef'] ?? ''}',
    tags: (m['tags'] as List? ?? []).map((e) => '$e').toList(),
    hint: '${m['hint'] ?? ''}',
    audioUrl: '${m['audioUrl'] ?? ''}',
  );
}

/// 作文の下書き(保存するたびに1件増える = 書き直しの過程が残る)
class EssayDraft {
  String id;
  String assignmentId; // どの課題の作文か
  String text; // 本文
  int version; // 1, 2, 3...
  String savedAt;
  List<String> usedVocabIds; // この下書きで使えた教科書の単語(自動判定)

  EssayDraft({
    required this.id,
    required this.assignmentId,
    required this.text,
    required this.version,
    required this.savedAt,
    this.usedVocabIds = const [],
  });

  DateTime get dateTime => DateTime.tryParse(savedAt) ?? DateTime.now();
  int get charCount => text.replaceAll(RegExp(r'\s'), '').length;

  Map<String, dynamic> toMap() => {
    'id': id,
    'assignmentId': assignmentId,
    'text': text,
    'version': version,
    'savedAt': savedAt,
    'usedVocabIds': usedVocabIds,
  };

  static EssayDraft fromMap(Map m) => EssayDraft(
    id: '${m['id'] ?? ''}',
    assignmentId: '${m['assignmentId'] ?? ''}',
    text: '${m['text'] ?? ''}',
    version: _int(m['version']),
    savedAt: '${m['savedAt'] ?? ''}',
    usedVocabIds:
        (m['usedVocabIds'] as List? ?? []).map((e) => '$e').toList(),
  );
}

/// Study Helper での行動記録
///   action: "search"(検索した) / "reveal"(答えを見た) / "remembered"(見ずに思い出せた)
///           / "hint"(ヒントを求めた) / "question"(自由入力の質問)
class HelperLog {
  String id;
  String assignmentId;
  String action;
  String query; // 検索語・質問文
  String vocabId; // 対象の単語(あれば)
  String at;

  HelperLog({
    required this.id,
    required this.assignmentId,
    required this.action,
    this.query = '',
    this.vocabId = '',
    required this.at,
  });

  DateTime get dateTime => DateTime.tryParse(at) ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'assignmentId': assignmentId,
    'action': action,
    'query': query,
    'vocabId': vocabId,
    'at': at,
  };

  static HelperLog fromMap(Map m) => HelperLog(
    id: '${m['id'] ?? ''}',
    assignmentId: '${m['assignmentId'] ?? ''}',
    action: '${m['action'] ?? ''}',
    query: '${m['query'] ?? ''}',
    vocabId: '${m['vocabId'] ?? ''}',
    at: '${m['at'] ?? ''}',
  );
}

/// [{"title","url"}] のリスト(シート・Hive どちらの形でも読める)
List<Map<String, String>> _materialsFrom(dynamic v) => (v as List? ?? [])
    .map((e) => {
          'title': '${(e as Map)['title'] ?? ''}',
          'url': '${e['url'] ?? ''}',
        })
    .toList();

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

// -----------------------------------------------------------------------------
// 2. AppData : アプリ全体のデータを持ち、保存・読み込み・計算をする中心クラス
//    画面側は context.watch<AppData>() で読み、data.xxx() で変更します。
// -----------------------------------------------------------------------------
class AppData extends ChangeNotifier {
  // ---- 保存箱(Hive) ----
  late Box _lessonsBox;
  late Box _assignmentsBox;
  late Box _noticesBox;
  late Box _logsBox;
  late Box _submissionsBox;
  late Box _filesBox; // 提出ファイルの中身(bytes)
  late Box _vocabBox;
  late Box _draftsBox;
  late Box _helperBox;
  late Box _settingsBox;
  late Box _flowBox; // 1課の流れ(steps / grammar / dialog)
  late Box _progressBox; // 学生のステップ進み具合

  // ---- メモリ上のリスト(画面はこれを表示) ----
  List<Lesson> lessons = [];
  List<Assignment> assignments = [];
  List<Notice> notices = [];
  List<StudyLog> logs = [];
  List<Submission> submissions = [];
  List<VocabItem> vocab = [];
  List<EssayDraft> drafts = [];
  List<HelperLog> helperLogs = [];
  List<Map> steps = []; // 1課の流れのステップ
  List<Map> grammarQs = []; // 文法チェックの問題
  List<Map> dialogLines = []; // 会話のセリフ

  // ---- 設定 ----
  String userName = 'Student';
  String studentId = ''; // 学籍番号(先生が指定した番号)
  String className = ''; // クラス名・コース名(例: "N3 Evening Class 2026")
  int dailyGoalMinutes = 30; // 1日の目標(分)
  int weeklyGoalDays = 5; // 週の目標学習日数
  String contentUrl = ''; // 管理者が content.json を置いたURL(空ならアプリ内のファイルを使用)
  String lastSyncMessage = '';
  String recordUrl = ''; // 学校のサーバー(Apps Script)の URL(シートの admin タブ recordUrl)
  String pin = ''; // ログインの暗証番号
  String syncStatus = ''; // 'saved' / 'saving' / 'offline'
  Timer? _syncTimer;
  bool _syncing = false;
  bool _restoring = false; // ログイン中(サーバーから読み込み中)は保存しない

  bool ready = false;

  // ===========================================================================
  // 起動時の処理
  // ===========================================================================
  Future<void> init() async {
    await Hive.initFlutter();
    _lessonsBox = await Hive.openBox('lessons');
    _assignmentsBox = await Hive.openBox('assignments');
    _noticesBox = await Hive.openBox('notices');
    _logsBox = await Hive.openBox('logs');
    _submissionsBox = await Hive.openBox('submissions');
    _filesBox = await Hive.openBox('files');
    _vocabBox = await Hive.openBox('vocab');
    _draftsBox = await Hive.openBox('drafts');
    _helperBox = await Hive.openBox('helper');
    _settingsBox = await Hive.openBox('settings');
    _flowBox = await Hive.openBox('flow');
    _progressBox = await Hive.openBox('progress');

    userName = _settingsBox.get('userName', defaultValue: 'Student');
    studentId = _settingsBox.get('studentId', defaultValue: '');
    className = _settingsBox.get('className', defaultValue: '');
    dailyGoalMinutes = _settingsBox.get('dailyGoalMinutes', defaultValue: 30);
    weeklyGoalDays = _settingsBox.get('weeklyGoalDays', defaultValue: 5);
    contentUrl = _settingsBox.get('contentUrl', defaultValue: '');
    recordUrl = _settingsBox.get('recordUrl', defaultValue: '');
    pin = _settingsBox.get('pin', defaultValue: '');

    _reload();

    // 管理者コンテンツ(授業・課題・お知らせ)を読み込んで追加する
    await syncContent();
    // 送れていない受講記録・ファイルがあれば送る(待たずに裏で)
    if (loggedIn) {
      sendPendingRecords();
      uploadPendingFiles();
    }

    // 初回起動のときだけ、サンプルの学習記録を入れる(動作イメージ用)
    if (kSeedSampleLogs && _settingsBox.get('seeded') != true) {
      _seedSampleLogs();
      await _settingsBox.put('seeded', true);
    }

    ready = true;
    notifyListeners();
  }

  /// Hive の箱からメモリ上のリストへ読み直す
  void _reload() {
    lessons = _lessonsBox.values.map((e) => Lesson.fromMap(e)).toList()
      ..sort((a, b) => b.number.compareTo(a.number));
    assignments = _assignmentsBox.values
        .map((e) => Assignment.fromMap(e))
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    notices = _noticesBox.values.map((e) => Notice.fromMap(e)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    logs = _logsBox.values.map((e) => StudyLog.fromMap(e)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    submissions = _submissionsBox.values
        .map((e) => Submission.fromMap(e))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    vocab = _vocabBox.values.map((e) => VocabItem.fromMap(e)).toList();
    drafts = _draftsBox.values.map((e) => EssayDraft.fromMap(e)).toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    helperLogs = _helperBox.values.map((e) => HelperLog.fromMap(e)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    // シートの順番を保ったまま、order 列があればその順に並べる
    List<Map> flow(String key) {
      final list = (_flowBox.get(key) as List? ?? [])
          .map((e) => Map.of(e as Map))
          .toList();
      for (var i = 0; i < list.length; i++) {
        list[i]['_row'] = i;
      }
      list.sort((a, b) {
        final c = _int(a['order']).compareTo(_int(b['order']));
        return c != 0 ? c : _int(a['_row']).compareTo(_int(b['_row']));
      });
      return list;
    }

    steps = flow('steps');
    grammarQs = flow('grammar');
    dialogLines = flow('dialog');
  }

  // ===========================================================================
  // 管理者コンテンツの読み込み(content.json)
  //   1) contentUrl が設定されていれば、そのURLからダウンロード
  //   2) 無ければ assets/data/content.json(アプリに同梱)を使用
  //   同じ id があれば「内容だけ更新」し、学習者の進捗(done/watched/read)は残す
  // ===========================================================================
  Future<void> syncContent() async {
    Map data;
    bool fromSheet = false;
    try {
      if (contentUrl.trim().isNotEmpty) {
        // (上級者向け)Settings で content.json の URL を指定した場合
        final res = await http
            .get(Uri.parse(contentUrl.trim()))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        data = jsonDecode(utf8.decode(res.bodyBytes));
        lastSyncMessage = 'Updated from server';
      } else if (kSheetId.isNotEmpty) {
        // ふつうはこちら: 教材入力シート(Google スプレッドシート)から読む
        data = await loadContentFromSheet(kSheetId);
        fromSheet = true;
        final settings = await loadSettingsFromSheet(kSheetId);
        recordUrl = settings['recordUrl'] ?? '';
        await _settingsBox.put('recordUrl', recordUrl);
        lastSyncMessage = 'Updated from the course sheet';
      } else {
        data = jsonDecode(
            await rootBundle.loadString('assets/data/content.json'));
        lastSyncMessage = 'Using built-in content';
      }
    } catch (e) {
      debugPrint('syncContent error: $e');
      // 読めない時(オフラインなど): 前回保存した内容があればそれを表示
      if (_lessonsBox.isNotEmpty || _assignmentsBox.isNotEmpty) {
        lastSyncMessage = 'Offline: showing saved content';
        _reload();
        notifyListeners();
        return;
      }
      data = jsonDecode(
          await rootBundle.loadString('assets/data/content.json'));
      lastSyncMessage = 'Could not load the course sheet ($e)';
    }

    // シートから消された授業・課題・お知らせ・単語は、アプリからも消す
    if (fromSheet) {
      Set<String> ids(String key) =>
          (data[key] as List? ?? []).map((m) => '${m['id']}').toSet();
      Future<void> prune(Box box, Set<String> keep) async {
        // 'my_' で始まるもの = 学生が自分で追加した課題なので消さない
        final remove = box.keys
            .where((k) => !keep.contains('$k') && !'$k'.startsWith('my_'))
            .toList();
        await box.deleteAll(remove);
      }
      await prune(_lessonsBox, ids('lessons'));
      await prune(_assignmentsBox, ids('assignments'));
      await prune(_noticesBox, ids('notices'));
      await prune(_vocabBox, ids('vocabulary'));
    }

    for (final m in (data['lessons'] as List? ?? [])) {
      final fresh = Lesson.fromMap(m);
      final old = _lessonsBox.get(fresh.id);
      if (old != null) {
        // 学習者の進捗は残す
        fresh.progress = (old['progress'] as num?)?.toDouble() ?? 0;
        fresh.watched = old['watched'] == true;
      }
      await _lessonsBox.put(fresh.id, fresh.toMap());
    }
    for (final m in (data['assignments'] as List? ?? [])) {
      final fresh = Assignment.fromMap(m);
      final old = _assignmentsBox.get(fresh.id);
      if (old != null) {
        fresh.done = old['done'] == true;
        fresh.doneAt = '${old['doneAt'] ?? ''}';
        fresh.score = old['score'] == null ? -1 : _int(old['score']);
      }
      await _assignmentsBox.put(fresh.id, fresh.toMap());
    }
    for (final m in (data['notices'] as List? ?? [])) {
      final fresh = Notice.fromMap(m);
      final old = _noticesBox.get(fresh.id);
      if (old != null) fresh.read = old['read'] == true;
      await _noticesBox.put(fresh.id, fresh.toMap());
    }
    // 1課の流れ(シートの steps / grammar / dialog タブ)
    for (final key in ['steps', 'grammar', 'dialog']) {
      await _flowBox.put(key, (data[key] as List? ?? []).toList());
    }
    // 教科書の単語・表現(学習者の状態は無いのでそのまま上書き)
    for (final m in (data['vocabulary'] as List? ?? [])) {
      final v = VocabItem.fromMap(m);
      await _vocabBox.put(v.id, v.toMap());
    }
    _reload();
    notifyListeners();
  }

  // ===========================================================================
  // 設定
  // ===========================================================================
  Future<void> saveSettings({
    String? name,
    String? studentIdValue,
    String? classNameValue,
    int? dailyGoal,
    int? weeklyDays,
    String? url,
  }) async {
    if (name != null) await _settingsBox.put('userName', userName = name);
    if (studentIdValue != null) {
      await _settingsBox.put('studentId', studentId = studentIdValue.trim());
    }
    if (classNameValue != null) {
      await _settingsBox.put('className', className = classNameValue.trim());
    }
    if (dailyGoal != null) {
      await _settingsBox.put('dailyGoalMinutes', dailyGoalMinutes = dailyGoal);
    }
    if (weeklyDays != null) {
      await _settingsBox.put('weeklyGoalDays', weeklyGoalDays = weeklyDays);
    }
    if (url != null) await _settingsBox.put('contentUrl', contentUrl = url);
    notifyListeners();
  }

  // ===========================================================================
  // 学習記録(Study log)と連続学習日数(Streak)
  // ===========================================================================
  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  int minutesOn(DateTime day) {
    final d = _dayOf(day);
    return logs
        .where((l) => _dayOf(l.dateTime) == d)
        .fold(0, (sum, l) => sum + l.minutes);
  }

  int get todayMinutes => minutesOn(DateTime.now());
  bool get studiedToday => todayMinutes > 0;
  int get totalMinutes => logs.fold(0, (s, l) => s + l.minutes);

  /// 連続学習日数(今日まだ未学習なら、昨日までの連続をカウント)
  int get streak {
    final days = logs.map((l) => _dayOf(l.dateTime)).toSet();
    var cursor = _dayOf(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get longestStreak {
    final days = logs.map((l) => _dayOf(l.dateTime)).toSet().toList()..sort();
    int best = 0, cur = 0;
    for (int i = 0; i < days.length; i++) {
      cur = (i > 0 && days[i].difference(days[i - 1]).inDays == 1) ? cur + 1 : 1;
      if (cur > best) best = cur;
    }
    return best;
  }

  /// 今週の月曜日
  DateTime get thisMonday {
    final t = _dayOf(DateTime.now());
    return t.subtract(Duration(days: t.weekday - 1));
  }

  int get weekStudyDays {
    int c = 0;
    for (int i = 0; i < 7; i++) {
      if (minutesOn(thisMonday.add(Duration(days: i))) > 0) c++;
    }
    return c;
  }

  int get weekMinutes {
    int s = 0;
    for (int i = 0; i < 7; i++) {
      s += minutesOn(thisMonday.add(Duration(days: i)));
    }
    return s;
  }

  Map<String, int> get minutesByCategory {
    final m = <String, int>{};
    for (final l in logs) {
      m[l.category] = (m[l.category] ?? 0) + l.minutes;
    }
    return m;
  }

  Future<void> addLog(int minutes, String category, String note,
      {DateTime? date}) async {
    final log = StudyLog(
      id: 'log_${DateTime.now().microsecondsSinceEpoch}',
      date: (date ?? DateTime.now()).toIso8601String(),
      minutes: minutes,
      category: category,
      note: note,
    );
    await _logsBox.put(log.id, log.toMap());
    _reload();
    notifyListeners();
  }

  Future<void> deleteLog(String id) async {
    await _logsBox.delete(id);
    _reload();
    notifyListeners();
  }

  // ===========================================================================
  // 課題(Assignments)
  // ===========================================================================
  Assignment? assignment(String id) {
    for (final a in assignments) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<Assignment> get pendingAssignments =>
      assignments.where((a) => !a.done).toList();

  List<Assignment> get doneAssignments =>
      assignments.where((a) => a.done).toList()
        ..sort((a, b) => b.due.compareTo(a.due));

  /// ホーム用: 2日以内に締切の未完了課題
  List<Assignment> get upcoming {
    final limit = DateTime.now().add(const Duration(days: 2));
    return assignments.where((a) => !a.done && a.due.isBefore(limit)).toList();
  }

  Future<void> toggleDone(Assignment a) async {
    a.done = !a.done;
    a.doneAt = a.done ? DateTime.now().toIso8601String() : '';
    await _assignmentsBox.put(a.id, a.toMap());
    notifyListeners();
  }

  Future<void> setScore(Assignment a, int score, int maxScore) async {
    a.score = score;
    a.maxScore = maxScore;
    a.done = true;
    if (a.doneAt.isEmpty) a.doneAt = DateTime.now().toIso8601String();
    await _assignmentsBox.put(a.id, a.toMap());
    notifyListeners();
  }

  /// 学習者が自分で課題を追加する場合
  Future<void> addAssignment(Assignment a) async {
    await _assignmentsBox.put(a.id, a.toMap());
    _reload();
    notifyListeners();
  }

  Future<void> deleteAssignment(String id) async {
    await _assignmentsBox.delete(id);
    _reload();
    notifyListeners();
  }

  // ===========================================================================
  // 提出物(Submissions)= ポートフォリオ
  // ===========================================================================
  List<Submission> submissionsFor(String assignmentId) =>
      submissions.where((s) => s.assignmentId == assignmentId).toList();

  /// ファイルを提出(保存)する。課題に紐づく場合は自動で「提出済み」にする。
  Future<void> addSubmission({
    required String assignmentId,
    required String title,
    required String fileName,
    required Uint8List bytes,
    String note = '',
  }) async {
    final sub = Submission(
      id: 'sub_${DateTime.now().microsecondsSinceEpoch}',
      assignmentId: assignmentId,
      title: title,
      fileName: fileName,
      fileType: fileTypeOf(fileName),
      sizeBytes: bytes.length,
      submittedAt: DateTime.now().toIso8601String(),
      note: note,
    );
    await _filesBox.put(sub.id, bytes);
    await _submissionsBox.put(sub.id, sub.toMap());
    await _queueUpload(sub.id);

    final a = assignment(assignmentId);
    if (a != null && !a.done) {
      a.done = true;
      a.doneAt = sub.submittedAt;
      await _assignmentsBox.put(a.id, a.toMap());
    }
    _reload();
    notifyListeners();
  }

  Future<void> updateSubmissionNote(Submission s, String note) async {
    s.note = note;
    await _submissionsBox.put(s.id, s.toMap());
    notifyListeners();
  }

  Future<void> deleteSubmission(String id) async {
    await _submissionsBox.delete(id);
    await _filesBox.delete(id);
    _reload();
    notifyListeners();
  }

  /// 提出ファイルの中身を取り出す(画像プレビューやダウンロード用)
  Uint8List? fileBytes(String submissionId) {
    final v = _filesBox.get(submissionId);
    return v is Uint8List ? v : null;
  }

  /// ファイル名の拡張子から種類を判定
  static String fileTypeOf(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'pdf') return 'pdf';
    if (['mp3', 'm4a', 'wav', 'aac', 'ogg', 'webm'].contains(ext)) return 'audio';
    if (['jpg', 'jpeg', 'png', 'gif', 'heic', 'webp'].contains(ext)) {
      return 'image';
    }
    if (['txt', 'md'].contains(ext)) return 'text';
    return 'other';
  }

  // ===========================================================================
  // Study Helper(教科書の単語を思い出す)
  //   ★ AI・例文生成・読み上げは一切行いません。
  //   表示するのは content.json の "vocabulary" に先生が書いたものだけです。
  // ===========================================================================

  /// 課題に関係する単語: 関連授業の単語 + 課題の subject と同じ tag の単語
  List<VocabItem> vocabForAssignment(Assignment a) {
    final list = vocab.where((v) {
      if (a.relatedLessonId.isNotEmpty && v.lessonId == a.relatedLessonId) {
        return true;
      }
      return v.tags.any((t) => t.toLowerCase() == a.subject.toLowerCase());
    }).toList();
    // 関連が無ければ全単語を対象にする
    return list.isEmpty ? List.of(vocab) : list;
  }

  /// 単語検索(日本語・読み・英語の意味・タグのどれかに一致)
  List<VocabItem> searchVocab(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return [];
    return vocab.where((v) {
      return v.word.contains(s) ||
          v.reading.contains(s) ||
          v.meaning.toLowerCase().contains(s) ||
          v.tags.any((t) => t.toLowerCase().contains(s)) ||
          v.textbookRef.toLowerCase().contains(s);
    }).toList();
  }

  /// 作文の中で使われている教科書の単語を探す
  List<VocabItem> vocabUsedIn(String text) =>
      vocab.where((v) => v.word.isNotEmpty && text.contains(v.word)).toList();

  Future<void> logHelper(String assignmentId, String action,
      {String query = '', String vocabId = ''}) async {
    final h = HelperLog(
      id: 'h_${DateTime.now().microsecondsSinceEpoch}',
      assignmentId: assignmentId,
      action: action,
      query: query,
      vocabId: vocabId,
      at: DateTime.now().toIso8601String(),
    );
    await _helperBox.put(h.id, h.toMap());
    helperLogs.insert(0, h);
    notifyListeners();
  }

  List<HelperLog> helperLogsFor(String assignmentId) =>
      helperLogs.where((h) => h.assignmentId == assignmentId).toList();

  // ===========================================================================
  // 作文の下書き(Essay drafts)
  // ===========================================================================
  List<EssayDraft> draftsFor(String assignmentId) =>
      drafts.where((d) => d.assignmentId == assignmentId).toList();

  EssayDraft? latestDraft(String assignmentId) {
    final list = draftsFor(assignmentId);
    return list.isEmpty ? null : list.first;
  }

  Future<EssayDraft> saveDraft(String assignmentId, String text) async {
    final version = draftsFor(assignmentId).length + 1;
    final d = EssayDraft(
      id: 'd_${DateTime.now().microsecondsSinceEpoch}',
      assignmentId: assignmentId,
      text: text,
      version: version,
      savedAt: DateTime.now().toIso8601String(),
      usedVocabIds: vocabUsedIn(text).map((v) => v.id).toList(),
    );
    await _draftsBox.put(d.id, d.toMap());
    _reload();
    notifyListeners();
    return d;
  }

  /// 学籍番号をファイル名に入れる(先生が回収したときに詰人sと課題がすぐ分かる)
  String _idPrefix() {
    final id = studentId.trim();
    // ファイル名に使えない文字は _ に
    return id.isEmpty
        ? ''
        : '${id.replaceAll(RegExp(r"[^A-Za-z0-9_\-]"), "_")}_';
  }

  /// 作文テキストを提出物(.txt)として保存
  Future<void> submitEssayText(Assignment a, String text) async {
    await addSubmission(
      assignmentId: a.id,
      title: a.title,
      fileName: '${_idPrefix()}essay_${a.id}.txt',
      bytes: Uint8List.fromList(utf8.encode(text)),
      note: 'Essay text (${draftsFor(a.id).length} drafts)',
    );
  }

  /// 録音を提出物として保存
  Future<void> submitRecording(Assignment a, Uint8List bytes, String ext) async {
    await addSubmission(
      assignmentId: a.id,
      title: a.title,
      fileName:
          '${_idPrefix()}reading_${a.id}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      bytes: bytes,
      note: 'My reading of the essay',
    );
  }

  // ===========================================================================
  // 学習データの書き出し(将来の分析・LLM wiki 用)
  // ===========================================================================
  String exportAllAsJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'studentId': studentId,
      'className': className,
      'userName': userName,
      'studyLogs': logs.map((e) => e.toMap()).toList(),
      'assignments': assignments.map((e) => e.toMap()).toList(),
      'submissions': submissions.map((e) => e.toMap()).toList(),
      'essayDrafts': drafts.map((e) => e.toMap()).toList(),
      'helperLogs': helperLogs.map((e) => e.toMap()).toList(),
      'lessons': lessons
          .map((e) => {'id': e.id, 'progress': e.progress, 'watched': e.watched})
          .toList(),
    });
  }

  // ===========================================================================
  // 受講(Start / Completed)
  //   progress の箱に 'lesson_<id>' で保存し、先生の受講記録シートにも送る
  // ===========================================================================
  Map? lessonRecord(String lessonId) {
    final r = _progressBox.get('lesson_$lessonId');
    return r is Map ? r : null;
  }

  bool lessonStarted(String lessonId) =>
      '${lessonRecord(lessonId)?['startedAt'] ?? ''}'.isNotEmpty;
  bool lessonCompleted(String lessonId) =>
      '${lessonRecord(lessonId)?['completedAt'] ?? ''}'.isNotEmpty;

  /// Completed を押せるか: ステップ(無ければ関連する課題)がすべて終わっている
  bool lessonReadyToComplete(String lessonId) {
    final st = stepsFor(lessonId);
    if (st.isNotEmpty) return st.every(isStepDone);
    final tasks = assignments.where((a) => a.relatedLessonId == lessonId);
    return tasks.every((a) => a.done);
  }

  /// 期間内に終わったか(終了日の 23:59 まで OK)
  bool lessonOnTime(Lesson l) {
    final done = '${lessonRecord(l.id)?['completedAt'] ?? ''}';
    if (done.isEmpty || l.availableUntil.isEmpty) return true;
    return done.substring(0, 10).compareTo(l.availableUntil) <= 0;
  }

  Future<void> startLesson(Lesson l) => _lessonAction(l, 'start');
  Future<void> completeLesson(Lesson l) => _lessonAction(l, 'complete');

  Future<void> _lessonAction(Lesson l, String action) async {
    final key = 'lesson_${l.id}';
    final r = Map.of(lessonRecord(l.id) ?? {});
    final field = action == 'start' ? 'startedAt' : 'completedAt';
    if ('${r[field] ?? ''}'.isEmpty) r[field] = _stamp(DateTime.now());
    r['${action}Sent'] = false;
    await _progressBox.put(key, r);
    notifyListeners();
    await sendPendingRecords();
  }

  /// まだ先生に届いていない記録を送る(オフラインのときは後で再送)
  Future<void> sendPendingRecords() async {
    if (recordUrl.isEmpty || studentId.isEmpty) return;
    for (final l in lessons) {
      final r = lessonRecord(l.id);
      if (r == null) continue;
      for (final action in ['start', 'complete']) {
        final at = '${r[action == 'start' ? 'startedAt' : 'completedAt'] ?? ''}';
        if (at.isEmpty || r['${action}Sent'] == true) continue;
        final ok = await _postRecord({
          'studentId': studentId,
          'pin': pin,
          'name': userName,
          'className': className,
          'lessonId': l.id,
          'lessonTitle': 'Lesson ${l.number}: ${l.title}',
          'action': action,
          'at': at,
          'periodStart': l.publishedAt,
          'periodEnd': l.availableUntil,
        });
        if (ok) {
          final fresh = Map.of(lessonRecord(l.id) ?? r);
          fresh['${action}Sent'] = true;
          await _progressBox.put('lesson_${l.id}', fresh);
        }
      }
    }
    notifyListeners();
  }

  Future<bool> _postRecord(Map<String, dynamic> body) async {
    try {
      final res = await _call(body);
      return res != null && res['ok'] == true;
    } catch (e) {
      debugPrint('record send error: $e');
      return false;
    }
  }

  /// "2026-12-01 19:02" の形
  String _stamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  // ===========================================================================
  // 1課の流れ(Lesson steps)
  // ===========================================================================
  List<Map> stepsFor(String lessonId) =>
      steps.where((s) => '${s['lessonId']}' == lessonId).toList();
  List<Map> grammarFor(String lessonId) =>
      grammarQs.where((q) => '${q['lessonId']}' == lessonId).toList();
  List<Map> dialogFor(String lessonId) =>
      dialogLines.where((d) => '${d['lessonId']}' == lessonId).toList();
  List<VocabItem> vocabOfLesson(String lessonId) =>
      vocab.where((v) => v.lessonId == lessonId).toList();

  /// ステップが終わっているか(作文・発表は課題の提出で判定)
  bool isStepDone(Map step) {
    final type = '${step['type']}';
    if (type == 'essay' || type == 'presentation') {
      return assignment('${step['assignmentId']}')?.done ?? false;
    }
    final p = _progressBox.get('${step['id']}');
    return p is Map && p['done'] == true;
  }

  /// 文法チェックの点数など(無ければ null)
  Map? stepProgress(String stepId) {
    final p = _progressBox.get(stepId);
    return p is Map ? p : null;
  }

  Future<void> completeStep(String stepId, {int? score, int? total}) async {
    await _progressBox.put(stepId, {
      'done': true,
      'at': DateTime.now().toIso8601String(),
      if (score != null) 'score': score,
      if (total != null) 'total': total,
    });
    notifyListeners();
  }

  // ===========================================================================
  // 授業(Lessons)
  // ===========================================================================
  Lesson? lesson(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<Lesson> get unwatchedLessons => lessons.where((l) => !l.watched).toList();

  Future<void> setLessonProgress(Lesson l, double progress) async {
    l.progress = progress.clamp(0, 1);
    if (l.progress >= 0.99) {
      l.progress = 1;
      l.watched = true;
    }
    await _lessonsBox.put(l.id, l.toMap());
    notifyListeners();
  }

  Future<void> setWatched(Lesson l, bool watched) async {
    l.watched = watched;
    l.progress = watched ? 1 : 0;
    await _lessonsBox.put(l.id, l.toMap());
    notifyListeners();
  }

  // ===========================================================================
  // お知らせ(Notices)
  // ===========================================================================
  Notice? notice(String id) {
    for (final n in notices) {
      if (n.id == id) return n;
    }
    return null;
  }

  int get unreadCount => notices.where((n) => !n.read).length;

  Future<void> markRead(Notice n) async {
    if (n.read) return;
    n.read = true;
    await _noticesBox.put(n.id, n.toMap());
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final n in notices) {
      n.read = true;
      await _noticesBox.put(n.id, n.toMap());
    }
    notifyListeners();
  }

  // ===========================================================================
  // サンプルの学習記録(初回のみ)
  // ===========================================================================
  void _seedSampleLogs() {
    const cats = ['Kanji', 'Vocabulary', 'Grammar', 'Listening', 'Reading'];
    final now = DateTime.now();
    for (int i = 1; i <= 12; i++) {
      final d = DateTime(now.year, now.month, now.day - i, 20);
      final log = StudyLog(
        id: 'log_sample_$i',
        date: d.toIso8601String(),
        minutes: 20 + (i * 7) % 40,
        category: cats[i % cats.length],
        note: i == 1 ? 'Reviewed kanji from Lesson 5' : '',
      );
      _logsBox.put(log.id, log.toMap());
    }
    _reload();
  }

  /// すべての学習者データを消す(設定画面から)
  // ===========================================================================
  // ログイン・ログアウト・同期(学校のサーバー = 先生の Apps Script)
  //   学生のデータ(進み具合・作文・記録)は先生のドライブにも保存され、
  //   別のスマホでログインしても続きから使える。
  // ===========================================================================
  bool get loggedIn => studentId.isNotEmpty && pin.isNotEmpty;
  bool get serverReady => recordUrl.isNotEmpty;

  /// サーバーに送って JSON の返事をもらう(つながらなければ null)
  Future<Map?> _call(Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (recordUrl.isEmpty) return null;
    try {
      final res = await http
          .post(Uri.parse(recordUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: jsonEncode(body))
          .timeout(timeout);
      if (res.statusCode >= 400) return null;
      final v = jsonDecode(utf8.decode(res.bodyBytes));
      return v is Map ? v : null;
    } catch (e) {
      debugPrint('server error: $e');
      return null;
    }
  }

  /// ログイン。うまくいけば null、だめならエラーの文を返す
  Future<String?> login(String id, String pinInput) async {
    if (!serverReady) {
      await syncContent(); // サーバーの URL をもう一度読む
      if (!serverReady) return 'The school server is not ready yet. Ask your teacher.';
    }
    final idT = id.trim();
    final pinT = pinInput.trim();
    final res = await _call({'action': 'login', 'studentId': idT, 'pin': pinT});
    if (res == null) return 'Could not connect. Check your internet.';
    if (res['ok'] != true) return '${res['error'] ?? 'Login failed'}';

    // サーバーに保存されたデータを先に読む(読めなければログインしない)
    final loaded = await _call({'action': 'load', 'studentId': idT, 'pin': pinT});
    if (loaded == null || loaded['ok'] != true) {
      return 'Could not load your saved work. Please try again.';
    }
    final sameUser = studentId == idT;
    _restoring = true;
    _syncTimer?.cancel();
    studentId = idT;
    pin = pinT;
    userName = '${res['name'] ?? ''}'.isEmpty ? idT : '${res['name']}';
    className = '${res['className'] ?? ''}';
    await _settingsBox.put('studentId', studentId);
    await _settingsBox.put('pin', pin);
    await _settingsBox.put('userName', userName);
    await _settingsBox.put('className', className);

    final text = '${loaded['state'] ?? ''}';
    if (text.isNotEmpty && text != 'null') {
      try {
        await _importState(jsonDecode(text) as Map);
      } catch (e) {
        debugPrint('import error: $e');
      }
    } else if (!sameUser) {
      // サーバーに何も無く、前の人のデータが残っていたら消す
      await _clearStudentData();
    }
    _restoring = false;
    _reload();
    super.notifyListeners();
    await pushState();
    sendPendingRecords();
    uploadPendingFiles();
    return null;
  }

  /// ログアウト。サーバーに保存できなかったら false(データは消さない)
  Future<bool> logout({bool force = false}) async {
    final ok = await pushState();
    final filesOk = await uploadPendingFiles();
    if (!force && (!ok || !filesOk)) return false;
    await _clearStudentData();
    studentId = '';
    pin = '';
    userName = 'Student';
    className = '';
    for (final k in ['studentId', 'pin', 'userName', 'className']) {
      await _settingsBox.delete(k);
    }
    syncStatus = '';
    _reload();
    super.notifyListeners();
    return true;
  }

  /// この端末の学生データを消す(授業・課題の内容は残し、進み具合だけ戻す)
  Future<void> _clearStudentData() async {
    await _logsBox.clear();
    await _submissionsBox.clear();
    await _filesBox.clear();
    await _draftsBox.clear();
    await _helperBox.clear();
    await _progressBox.clear();
    await _settingsBox.delete('pendingUploads');
    for (final k in _assignmentsBox.keys.toList()) {
      if ('$k'.startsWith('my_')) {
        await _assignmentsBox.delete(k);
        continue;
      }
      final a = Assignment.fromMap(_assignmentsBox.get(k));
      a.done = false;
      a.doneAt = '';
      a.score = -1;
      await _assignmentsBox.put(k, a.toMap());
    }
    for (final k in _lessonsBox.keys.toList()) {
      final l = Lesson.fromMap(_lessonsBox.get(k));
      l.progress = 0;
      l.watched = false;
      await _lessonsBox.put(k, l.toMap());
    }
    for (final k in _noticesBox.keys.toList()) {
      final n = Notice.fromMap(_noticesBox.get(k));
      n.read = false;
      await _noticesBox.put(k, n.toMap());
    }
  }

  /// この端末の学生データを1つの JSON にまとめる(ファイルの中身は別に送る)
  Map<String, dynamic> _exportState() => {
        'savedAt': DateTime.now().toIso8601String(),
        'logs': _logsBox.values.toList(),
        'submissions': _submissionsBox.values.toList(),
        'drafts': _draftsBox.values.toList(),
        'helper': _helperBox.values.toList(),
        'progress': {for (final k in _progressBox.keys) '$k': _progressBox.get(k)},
        'myTasks': _assignmentsBox.keys
            .where((k) => '$k'.startsWith('my_'))
            .map((k) => _assignmentsBox.get(k))
            .toList(),
        'assignmentState': {
          for (final a in assignments)
            a.id: {'done': a.done, 'doneAt': a.doneAt, 'score': a.score}
        },
        'lessonState': {
          for (final l in lessons)
            l.id: {'progress': l.progress, 'watched': l.watched}
        },
        'noticeRead': notices.where((n) => n.read).map((n) => n.id).toList(),
        'goals': {'daily': dailyGoalMinutes, 'weekly': weeklyGoalDays},
      };

  Future<void> _importState(Map st) async {
    await _clearStudentData();
    Future<void> fill(Box box, String key) async {
      for (final m in (st[key] as List? ?? [])) {
        await box.put('${(m as Map)['id']}', m);
      }
    }

    await fill(_logsBox, 'logs');
    await fill(_submissionsBox, 'submissions');
    await fill(_draftsBox, 'drafts');
    await fill(_helperBox, 'helper');
    await fill(_assignmentsBox, 'myTasks');
    final pr = st['progress'];
    if (pr is Map) {
      for (final e in pr.entries) {
        await _progressBox.put('${e.key}', e.value);
      }
    }
    final asg = st['assignmentState'];
    if (asg is Map) {
      for (final e in asg.entries) {
        final raw = _assignmentsBox.get('${e.key}');
        if (raw == null) continue;
        final a = Assignment.fromMap(raw);
        final v = e.value as Map;
        a.done = v['done'] == true;
        a.doneAt = '${v['doneAt'] ?? ''}';
        a.score = v['score'] == null ? -1 : _int(v['score']);
        await _assignmentsBox.put(a.id, a.toMap());
      }
    }
    final ls = st['lessonState'];
    if (ls is Map) {
      for (final e in ls.entries) {
        final raw = _lessonsBox.get('${e.key}');
        if (raw == null) continue;
        final l = Lesson.fromMap(raw);
        final v = e.value as Map;
        l.progress = (v['progress'] as num?)?.toDouble() ?? 0;
        l.watched = v['watched'] == true;
        await _lessonsBox.put(l.id, l.toMap());
      }
    }
    for (final id in (st['noticeRead'] as List? ?? [])) {
      final raw = _noticesBox.get('$id');
      if (raw == null) continue;
      final n = Notice.fromMap(raw);
      n.read = true;
      await _noticesBox.put(n.id, n.toMap());
    }
    final g = st['goals'];
    if (g is Map) {
      dailyGoalMinutes = _int(g['daily']) == 0 ? 30 : _int(g['daily']);
      weeklyGoalDays = _int(g['weekly']) == 0 ? 5 : _int(g['weekly']);
      await _settingsBox.put('dailyGoalMinutes', dailyGoalMinutes);
      await _settingsBox.put('weeklyGoalDays', weeklyGoalDays);
    }
  }

  /// 変更があったら、少し待ってからサーバーに保存する
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (loggedIn && serverReady && ready) {
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(seconds: 4), pushState);
    }
  }

  /// 今のデータをサーバーに保存する
  Future<bool> pushState() async {
    if (!loggedIn || !serverReady || _restoring) return false;
    if (_syncing) return false;
    _syncing = true;
    syncStatus = 'saving';
    super.notifyListeners();
    final res = await _call({
      'action': 'save',
      'studentId': studentId,
      'pin': pin,
      'state': jsonEncode(_exportState()),
    });
    _syncing = false;
    final ok = res != null && res['ok'] == true;
    syncStatus = ok ? 'saved' : 'offline';
    super.notifyListeners();
    return ok;
  }

  Future<void> _queueUpload(String submissionId) async {
    final list = List<String>.from(
        _settingsBox.get('pendingUploads', defaultValue: <String>[]) as List);
    if (!list.contains(submissionId)) list.add(submissionId);
    await _settingsBox.put('pendingUploads', list);
    uploadPendingFiles();
  }

  /// まだ送っていない提出ファイルを先生のドライブに送る。全部送れたら true
  Future<bool> uploadPendingFiles() async {
    if (!loggedIn || !serverReady) return false;
    final list = List<String>.from(
        _settingsBox.get('pendingUploads', defaultValue: <String>[]) as List);
    final left = <String>[];
    for (final id in list) {
      final raw = _submissionsBox.get(id);
      final bytes = fileBytes(id);
      if (raw == null || bytes == null) continue; // 消された
      final sub = Submission.fromMap(raw);
      final res = await _call({
        'action': 'upload',
        'studentId': studentId,
        'pin': pin,
        'submissionId': id,
        'fileName': sub.fileName,
        'mimeType': _mimeOf(sub.fileName),
        'data': base64Encode(bytes),
      }, timeout: const Duration(minutes: 3));
      if (res == null || res['ok'] != true) left.add(id);
    }
    await _settingsBox.put('pendingUploads', left);
    return left.isEmpty;
  }

  /// この端末に無いファイル(別のスマホで提出したもの)をサーバーから取る
  final _fetching = <String, Future<Uint8List?>>{};
  final fetchFailed = <String>{};
  Future<Uint8List?> fetchFile(String submissionId) {
    final local = fileBytes(submissionId);
    if (local != null) return Future.value(local);
    return _fetching[submissionId] ??= _download(submissionId)
        .whenComplete(() => _fetching.remove(submissionId));
  }

  Future<Uint8List?> _download(String submissionId) async {
    if (!loggedIn || !serverReady) return null;
    final res = await _call({
      'action': 'download',
      'studentId': studentId,
      'pin': pin,
      'submissionId': submissionId,
    }, timeout: const Duration(minutes: 3));
    if (res == null || res['ok'] != true || res['data'] == null) {
      fetchFailed.add(submissionId);
      super.notifyListeners();
      return null;
    }
    final bytes = base64Decode('${res['data']}');
    await _filesBox.put(submissionId, bytes);
    super.notifyListeners();
    return bytes;
  }

  String _mimeOf(String name) {
    final ext = name.split('.').last.toLowerCase();
    const m = {
      'pdf': 'application/pdf',
      'm4a': 'audio/mp4',
      'mp3': 'audio/mpeg',
      'webm': 'audio/webm',
      'wav': 'audio/wav',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'txt': 'text/plain',
    };
    return m[ext] ?? 'application/octet-stream';
  }

  Future<void> resetAll() async {
    await _logsBox.clear();
    await _submissionsBox.clear();
    await _filesBox.clear();
    await _draftsBox.clear();
    await _helperBox.clear();
    await _progressBox.clear();
    await _lessonsBox.clear();
    await _assignmentsBox.clear();
    await _noticesBox.clear();
    await _settingsBox.delete('seeded');
    await syncContent();
    if (kSeedSampleLogs) _seedSampleLogs();
    await _settingsBox.put('seeded', true);
    notifyListeners();
  }
}
