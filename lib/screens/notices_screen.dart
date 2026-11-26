// =============================================================================
// notices_screen.dart - お知らせ
//   NoticesScreen      : 一覧(カテゴリで絞り込み)
//   NoticeTile         : 1行(ホーム・課題詳細・授業詳細でも使う)
//   NoticeDetailScreen : 詳細。関連する課題・授業へのリンク付き
//
//   ★お知らせを追加するのは assets/data/content.json の "notices" です(管理者)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'assignments_screen.dart';
import 'lessons_screen.dart';

const _categories = ['All', 'Important', 'Lesson', 'Homework', 'Test', 'General'];

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final items = filter == 'All'
        ? data.notices
        : data.notices.where((n) => n.category == filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          if (data.unreadCount > 0)
            TextButton(
              onPressed: data.markAllRead,
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await data.syncContent();
              if (context.mounted) showMessage(context, data.lastSyncMessage);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categories.map((c) {
                  final selected = filter == c;
                  final color = c == 'All' ? kPrimary : noticeColor(c);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      selectedColor: color,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          color: selected ? Colors.white : kTextDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                      onSelected: (_) => setState(() => filter = c),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyMessage(Icons.notifications_none_rounded,
                      'No notices in this category.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => Card(child: NoticeTile(items[i])),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// お知らせ1行
class NoticeTile extends StatelessWidget {
  final Notice n;
  const NoticeTile(this.n, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = noticeColor(n.category);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: IconBox(noticeIcon(n.category), color: color),
      title: Row(
        children: [
          if (!n.read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration:
                  const BoxDecoration(color: kRed, shape: BoxShape.circle),
            ),
          Expanded(
            child: Text(n.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 14)),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Tag(n.category, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${n.sender} · ${timeAgo(n.dateTime)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(n.id)),
      ),
    );
  }
}

/// お知らせ詳細
class NoticeDetailScreen extends StatefulWidget {
  final String noticeId;
  const NoticeDetailScreen(this.noticeId, {super.key});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 開いたら既読にする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = context.read<AppData>();
      final n = data.notice(widget.noticeId);
      if (n != null) data.markRead(n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final n = data.notice(widget.noticeId);
    if (n == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyMessage(Icons.search_off, 'Notice not found'));
    }
    final color = noticeColor(n.category);
    final a = data.assignment(n.relatedAssignmentId);
    final l = data.lesson(n.relatedLessonId);

    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Tag(n.category, color: color, icon: noticeIcon(n.category)),
                        const Spacer(),
                        Text(fmtDateTime(n.dateTime),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(n.title,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: kPrimary.withValues(alpha: 0.15),
                          child: Text(n.sender.substring(0, 1),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: kPrimary,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text(n.sender,
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(n.body,
                        style: TextStyle(
                            height: 1.7,
                            fontSize: 15,
                            color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ),
            if (a != null) ...[
              const SizedBox(height: 16),
              const SectionTitle('Related task'),
              Card(child: AssignmentTile(a)),
            ],
            if (l != null) ...[
              const SizedBox(height: 16),
              const SectionTitle('Related lesson'),
              LessonRow(l),
            ],
          ],
        ),
      ),
    );
  }
}
