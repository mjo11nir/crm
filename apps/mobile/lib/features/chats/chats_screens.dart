import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/components/components.dart';

/// Internal team chat + support tickets. External messengers are clearly marked as not connected.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = ref.watch(conversationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabChats),
        actions: [
          IconButton(
            tooltip: l.newChat,
            icon: Icon(Icons.add_comment_rounded, color: c.primary),
            onPressed: () async {
              final ctrl = TextEditingController();
              String kind = 'INTERNAL';
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, set) => AlertDialog(
                    title: Text(l.newChat),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: ctrl,
                          autofocus: true,
                          decoration: InputDecoration(labelText: l.name),
                        ),
                        const SizedBox(height: 12),
                        SegmentedControl<String>(
                          segments: {'INTERNAL': l.internalChat, 'SUPPORT': l.support},
                          value: kind,
                          onChanged: (v) => set(() => kind = v),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
                    ],
                  ),
                ),
              );
              if (ok == true && ctrl.text.trim().isNotEmpty) {
                try {
                  await ref.read(repositoryProvider).createConversation(bizIdOf(ref), ctrl.text.trim(), kind);
                  ref.invalidate(conversationsProvider);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: AsyncView<List<Conversation>>(
          value: v,
          onRetry: () => ref.invalidate(conversationsProvider),
          data: (list) => ListView(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: c.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.externalChannelsBlocked, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              if (list.isEmpty) EmptyState(title: l.chatsEmpty, icon: Icons.chat_bubble_outline_rounded),
              for (final conv in list)
                ListTile(
                  onTap: () => context.go('/chats/${conv.id}?title=${Uri.encodeComponent(conv.title)}'),
                  leading: ColoredIconTile(
                    icon: conv.kind == 'SUPPORT' ? Icons.support_agent_rounded : Icons.groups_rounded,
                    background: conv.kind == 'SUPPORT' ? c.green : c.primary,
                    size: 44,
                    radius: 22,
                  ),
                  title: Text(conv.title, style: TextStyle(fontWeight: conv.unread > 0 ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text(conv.lastMessage ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conv.lastAt != null)
                        Text(DateFormat('d MMM HH:mm').format(toBusinessLocal(conv.lastAt!)), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      if (conv.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                          child: Text('${conv.unread}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String bizIdOf(WidgetRef ref) => ref.read(sessionProvider).value!.businessId;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.title});
  final String conversationId, title;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(repositoryProvider).sendMessage(bizIdOf(ref), widget.conversationId, body);
      _text.clear();
      ref.invalidate(messagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final me = ref.watch(sessionProvider).value?.me.id;
    final v = ref.watch(messagesProvider(widget.conversationId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: AsyncView<List<Message>>(
              value: v,
              onRetry: () => ref.invalidate(messagesProvider(widget.conversationId)),
              data: (msgs) => msgs.isEmpty
                  ? EmptyState(title: l.nothingHere)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[msgs.length - 1 - i];
                        final mine = m.senderUserId == me;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(color: mine ? c.primary : c.surface, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(m.body, style: TextStyle(color: mine ? Colors.white : c.textPrimary, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(hhmm(m.createdAt), style: TextStyle(color: mine ? Colors.white70 : c.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(hintText: l.typeMessage, isDense: true),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    tooltip: l.send,
                    onPressed: _sending ? null : _send,
                    icon: Icon(Icons.send_rounded, color: c.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
