// =============================================================================
// helpers.dart
// 色・日付の表示・小さな共通ウィジェットをまとめたファイル。
// 「色を変えたい」「日付の書き方を変えたい」ときはここを直します。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 色
// -----------------------------------------------------------------------------
const kPrimary = Color(0xFF3F51B5); // インディゴ(メインカラー)
const kSecondary = Color(0xFF5E35B1); // パープル
const kBackground = Color(0xFFF5F6FB);
const kTextDark = Color(0xFF1A1C2E);
const kOrange = Color(0xFFFF7043);
const kFlame = Color(0xFFFF9800);
const kGreen = Color(0xFF43A047);
const kRed = Color(0xFFE53935);
const kTeal = Color(0xFF00897B);

/// 学習カテゴリの一覧(順番 = 表示順)
const kCategories = [
  'Kanji',
  'Vocabulary',
  'Grammar',
  'Listening',
  'Reading',
  'Speaking',
];

Color categoryColor(String c) {
  switch (c) {
    case 'Kanji':
      return const Color(0xFFE53935);
    case 'Vocabulary':
      return const Color(0xFF1E88E5);
    case 'Grammar':
      return const Color(0xFF8E24AA);
    case 'Listening':
      return const Color(0xFF00897B);
    case 'Reading':
      return const Color(0xFFF4511E);
    case 'Speaking':
      return const Color(0xFF3949AB);
  }
  return Colors.grey;
}

IconData categoryIcon(String c) {
  switch (c) {
    case 'Kanji':
      return Icons.translate_rounded;
    case 'Vocabulary':
      return Icons.menu_book_rounded;
    case 'Grammar':
      return Icons.account_tree_outlined;
    case 'Listening':
      return Icons.headphones_rounded;
    case 'Reading':
      return Icons.chrome_reader_mode_outlined;
    case 'Speaking':
      return Icons.record_voice_over_outlined;
  }
  return Icons.school_outlined;
}

Color noticeColor(String c) {
  switch (c) {
    case 'Important':
      return kRed;
    case 'Lesson':
      return kPrimary;
    case 'Homework':
      return kTeal;
    case 'Test':
      return kSecondary;
  }
  return Colors.grey.shade700;
}

IconData noticeIcon(String c) {
  switch (c) {
    case 'Important':
      return Icons.priority_high_rounded;
    case 'Lesson':
      return Icons.play_circle_outline_rounded;
    case 'Homework':
      return Icons.edit_note_rounded;
    case 'Test':
      return Icons.quiz_outlined;
  }
  return Icons.campaign_outlined;
}

/// 課題タイプの色(Homework=teal, Test=purple)
Color assignmentColor(bool isTest) => isTest ? kSecondary : kTeal;
IconData assignmentIcon(bool isTest) =>
    isTest ? Icons.quiz_rounded : Icons.edit_note_rounded;

/// 提出ファイルの種類ごとのアイコンと色
IconData fileIcon(String type) {
  switch (type) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'audio':
      return Icons.mic_rounded;
    case 'image':
      return Icons.image_rounded;
    case 'text':
      return Icons.article_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

Color fileColor(String type) {
  switch (type) {
    case 'pdf':
      return kRed;
    case 'audio':
      return kOrange;
    case 'image':
      return const Color(0xFF1E88E5);
    case 'text':
      return kSecondary;
  }
  return Colors.grey.shade700;
}

/// 「どんなファイルを提出するか」の表示用ラベル
String submitTypeLabel(String t) {
  switch (t) {
    case 'pdf':
      return 'Submit PDF';
    case 'audio':
      return 'Submit audio recording';
    case 'image':
      return 'Submit photo / image';
    case 'essay':
      return 'Write in the app + record your reading';
    case 'none':
      return 'No upload needed';
  }
  return 'Submit a file';
}

// -----------------------------------------------------------------------------
// 日付の表示
// -----------------------------------------------------------------------------
String fmtDate(DateTime d) => DateFormat('MMM d (E)').format(d); // Nov 25 (Tue)
String fmtDateTime(DateTime d) => DateFormat('MMM d, HH:mm').format(d);
String fmtMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);

/// 締切までの表示: "Due today 23:59" / "Due tomorrow" / "3 days left" / "2 days overdue"
String dueText(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;
  if (diff < 0) return '${-diff} day${-diff == 1 ? '' : 's'} overdue';
  if (diff == 0) return 'Due today ${DateFormat('HH:mm').format(due)}';
  if (diff == 1) return 'Due tomorrow ${DateFormat('HH:mm').format(due)}';
  return '$diff days left (${DateFormat('M/d').format(due)})';
}

Color dueColor(DateTime due, bool done) {
  if (done) return kGreen;
  final now = DateTime.now();
  final diff = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff < 0) return kRed;
  if (diff <= 1) return kOrange;
  return Colors.grey.shade600;
}

/// "5 min ago" / "3 hours ago" / "Yesterday" / "Nov 20"
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('MMM d').format(d);
}

String fmtMinutes(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

String fmtBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

// -----------------------------------------------------------------------------
// 小さな共通ウィジェット
// -----------------------------------------------------------------------------

/// セクション見出し(右側に "See all" ボタンを置ける)
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: kPrimary,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// 小さな色付きラベル(例: "Homework", "Kanji")
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 丸いアイコン枠(リストの左側に使う)
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBox(this.icon, {super.key, required this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// データが無いときの表示
class EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyMessage(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 大きな角丸ボタン
class BigButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool outlined;
  const BigButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? kPrimary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return SizedBox(
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: BorderSide(color: c),
                foregroundColor: c,
              ),
              icon: Icon(icon),
              label: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: c,
                shape: shape,
              ),
              icon: Icon(icon),
              label: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

/// 画面下から出てくる簡単なメッセージ
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF303F9F),
    ),
  );
}

/// 「本当に削除しますか?」の確認ダイアログ
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('"$what" will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: kRed),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

// -----------------------------------------------------------------------------
// アプリ全体のテーマ(Material Design 3)
// -----------------------------------------------------------------------------
ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      secondary: kSecondary,
    ),
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      foregroundColor: kTextDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: kTextDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8EAF6)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kPrimary.withValues(alpha: 0.12),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? kPrimary
              : Colors.grey.shade600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
