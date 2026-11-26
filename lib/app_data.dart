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
  });

  Map<String, dynamic> toMap() => {
    'id': id,
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

  // ---- メモリ上のリスト(画面はこれを表示) ----
  List<Lesson> lessons = [];
  List<Assignment> assignments = [];
  List<Notice> notices = [];
  List<StudyLog> logs = [];
  List<Submission> submissions = [];
  List<VocabItem> vocab = [];
  List<EssayDraft> drafts = [];
  List<HelperLog> helperLogs = [];

  // ---- 設定 ----
  String userName = 'Student';
  String studentId = ''; // 学籍番号(先生が指定した番号)
  String className = ''; // クラス名・コース名(例: "N3 Evening Class 2026")
  int dailyGoalMinutes = 30; // 1日の目標(分)
  int weeklyGoalDays = 5; // 週の目標学習日数
  String contentUrl = ''; // 管理者が content.json を置いたURL(空ならアプリ内のファイルを使用)
  String lastSyncMessage = '';

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

    userName = _settingsBox.get('userName', defaultValue: 'Student');
    studentId = _settingsBox.get('studentId', defaultValue: '');
    className = _settingsBox.get('className', defaultValue: '');
    dailyGoalMinutes = _settingsBox.get('dailyGoalMinutes', defaultValue: 30);
    weeklyGoalDays = _settingsBox.get('weeklyGoalDays', defaultValue: 5);
    contentUrl = _settingsBox.get('contentUrl', defaultValue: '');

    _reload();

    // 管理者コンテンツ(授業・課題・お知らせ)を読み込んで追加する
    await syncContent();

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
  Future<void> resetAll() async {
    await _logsBox.clear();
    await _submissionsBox.clear();
    await _filesBox.clear();
    await _draftsBox.clear();
    await _helperBox.clear();
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
