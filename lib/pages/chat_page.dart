import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _didMarkRead = false;
  bool _didResolveHeaderName = false;
  int? _conversationId;
  String? _otherUserId;
  String _passedOtherUserName = 'Chat';
  String? _resolvedOtherUserName;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        const {};
    final conversationId = args['conversationId'] as int?;
    final otherUserId = args['otherUserId']?.toString();
    final passedOtherUserName = (args['otherUserName'] ?? 'Chat').toString();

    final hasRouteChange =
        _conversationId != conversationId ||
        _otherUserId != otherUserId ||
        _passedOtherUserName != passedOtherUserName;

    if (!hasRouteChange) return;

    _conversationId = conversationId;
    _otherUserId = otherUserId;
    _passedOtherUserName = passedOtherUserName;
    _didMarkRead = false;
    _didResolveHeaderName = false;
    _resolvedOtherUserName = null;

    if (otherUserId != null && !_isGenericConversationName(passedOtherUserName)) {
      ChatIdentityCache.instance.remember(
        userId: otherUserId,
        name: passedOtherUserName,
      );
    }

    if (conversationId != null) {
      _markConversationAsRead(conversationId);
    }

    if (otherUserId != null && _isGenericConversationName(passedOtherUserName)) {
      _resolveOtherUserName(otherUserId);
    }
  }

  Future<void> _markConversationAsRead(int conversationId) async {
    if (_didMarkRead) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    _didMarkRead = true;
    await supabase
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('receiver_id', user.id)
        .isFilter('read_at', null);
  }

  Future<void> _sendMessage({
    required int conversationId,
    required String receiverId,
  }) async {
    final text = _messageController.text.trim();
    final user = supabase.auth.currentUser;

    if (_isSending || text.isEmpty || user == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      var senderName = 'Someone';
      final senderProfile = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();
      if (senderProfile != null) {
        final displayName = _profileDisplayName(
          Map<String, dynamic>.from(senderProfile),
        );
        if (displayName.isNotEmpty) {
          senderName = displayName;
        }
      }

      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'receiver_id': receiverId,
        'body': text,
      });

      await supabase
          .from('conversations')
          .update({
            'last_message': text,
            'last_message_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', conversationId);

      try {
        await supabase.from('notifications').insert({
          'user_id': receiverId,
          'title': 'New message',
          'body': '$senderName sent you a message',
          'type': 'message',
        });
      } catch (_) {
        // Notifications can be protected by server-side RLS or triggers.
      }

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToLatestMessage();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _syncConversationSummary(int conversationId) async {
    final latestMessage = await supabase
        .from('messages')
        .select('body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latestMessage == null) {
      await supabase.from('conversations').update({
        'last_message': null,
        'last_message_at': null,
      }).eq('id', conversationId);
      return;
    }

    await supabase.from('conversations').update({
      'last_message': (latestMessage['body'] ?? '').toString(),
      'last_message_at': latestMessage['created_at'],
    }).eq('id', conversationId);
  }

  Future<void> _editMessage({
    required int messageId,
    required int conversationId,
    required String currentBody,
  }) async {
    final controller = TextEditingController(text: currentBody);

    try {
      final updatedBody = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppThemeColors.elevatedSurface(dialogContext),
            title: Text(
              'Edit message',
              style: GoogleFonts.poppins(
                color: AppThemeColors.textPrimary(dialogContext),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.inter(
                color: AppThemeColors.textPrimary(dialogContext),
              ),
              decoration: const InputDecoration(
                hintText: 'Update your message',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (updatedBody == null || updatedBody == currentBody.trim()) return;

      await supabase
          .from('messages')
          .update({'body': updatedBody})
          .eq('id', messageId);
      await _syncConversationSummary(conversationId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit message: $e')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteMessage({
    required int messageId,
    required int conversationId,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppThemeColors.elevatedSurface(dialogContext),
          title: Text(
            'Delete message?',
            style: GoogleFonts.poppins(
              color: AppThemeColors.textPrimary(dialogContext),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will remove the message from the conversation.',
            style: GoogleFonts.inter(
              color: AppThemeColors.textSecondary(dialogContext),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDB4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await supabase.from('messages').delete().eq('id', messageId);
      await _syncConversationSummary(conversationId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  Future<void> _showMessageActions({
    required int messageId,
    required int conversationId,
    required String body,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppThemeColors.elevatedSurface(context),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editMessage(
                    messageId: messageId,
                    conversationId: conversationId,
                    currentBody: body,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteMessage(
                    messageId: messageId,
                    conversationId: conversationId,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMessageTime(DateTime value) {
    final hour = value.hour > 12 ? value.hour - 12 : (value.hour == 0 ? 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void _scrollToLatestMessage() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool _isGenericConversationName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'chat' ||
        normalized == 'seller' ||
        normalized == 'buyer' ||
        normalized == 'user';
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (profile['email'] ?? '').toString().trim();
    if (email.isEmpty) return '';

    final localPart = email.split('@').first.trim();
    return localPart.isNotEmpty ? localPart : email;
  }

  Future<void> _resolveOtherUserName(String otherUserId) async {
    if (_didResolveHeaderName) return;
    _didResolveHeaderName = true;

    final profile = await supabase
        .from('profiles')
        .select('full_name, email')
        .eq('id', otherUserId)
        .maybeSingle();

    if (!mounted || profile == null) return;

    final resolvedName = _profileDisplayName(Map<String, dynamic>.from(profile));
    if (resolvedName.isEmpty) return;

    ChatIdentityCache.instance.remember(
      userId: otherUserId,
      name: resolvedName,
    );
    setState(() {
      _resolvedOtherUserName = resolvedName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = _conversationId;
    final otherUserId = _otherUserId;
    final passedOtherUserName = _passedOtherUserName;
    final user = supabase.auth.currentUser;
    final textColor = AppThemeColors.textPrimary(context);
    final cachedOtherUserName = otherUserId == null
        ? null
        : ChatIdentityCache.instance.nameFor(otherUserId);
    final otherUserName =
        _resolvedOtherUserName ?? cachedOtherUserName ?? passedOtherUserName;

    if (conversationId == null || otherUserId == null || user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            'Chat',
            style: GoogleFonts.poppins(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Conversation not available',
            style: GoogleFonts.inter(
              color: AppThemeColors.textSecondary(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          otherUserName,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', conversationId)
                  .order('created_at', ascending: true)
                  .map(
                    (rows) => rows
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList(),
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: GoogleFonts.inter(
                        color: AppThemeColors.textSecondary(context),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final messageId = message['id'] as int? ?? 0;
                    final senderId = (message['sender_id'] ?? '').toString();
                    final isMe = senderId == user.id;
                    final body = (message['body'] ?? '').toString();
                    final createdAt =
                        DateTime.tryParse(message['created_at'].toString())?.toLocal() ??
                        DateTime.now();

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && messageId > 0
                            ? () => _showMessageActions(
                                  messageId: messageId,
                                  conversationId: conversationId,
                                  body: body,
                                )
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFFDB4444)
                                : AppThemeColors.elevatedSurface(context),
                            border: isMe
                                ? null
                                : Border.all(
                                    color: AppThemeColors.border(context),
                                  ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                body,
                                style: GoogleFonts.inter(
                                  color: isMe
                                      ? Colors.white
                                      : AppThemeColors.textPrimary(context),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatMessageTime(createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isMe
                                      ? Colors.white70
                                      : AppThemeColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: GoogleFonts.inter(
                        color: AppThemeColors.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        hintStyle: GoogleFonts.inter(
                          color: AppThemeColors.textSecondary(context),
                        ),
                        filled: true,
                        fillColor: AppThemeColors.elevatedSurface(context),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: AppThemeColors.border(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: AppThemeColors.textSecondary(context),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSending
                          ? null
                          : () => _sendMessage(
                                conversationId: conversationId,
                                receiverId: otherUserId,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDB4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
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
