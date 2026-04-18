import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/chat_identity_cache.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationPreview {
  final int id;
  final String buyerId;
  final String sellerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;

  const ConversationPreview({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
  });
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<ConversationPreview> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final email = (profile['email'] ?? '').toString().trim();
    if (email.isEmpty) return '';

    final localPart = email.split('@').first.trim();
    return localPart.isNotEmpty ? localPart : email;
  }

  String _fallbackConversationName(String otherUserId, String otherUserRole) {
    final normalizedRole = otherUserRole.trim().toLowerCase();
    if (normalizedRole == 'seller') return 'Seller';
    if (normalizedRole == 'buyer') return 'Buyer';
    if (normalizedRole == 'admin') return 'Admin';
    if (otherUserId.isEmpty) return 'Unknown';
    return 'Chat';
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _conversations = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('conversations')
          .select(
            'id, buyer_id, seller_id, last_message, last_message_at, created_at',
          )
          .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
          .order('last_message_at', ascending: false)
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final otherUserIds = rows
          .map((row) {
            final buyerId = (row['buyer_id'] ?? '').toString();
            final sellerId = (row['seller_id'] ?? '').toString();
            return buyerId == user.id ? sellerId : buyerId;
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final profileMap = <String, String>{};
      final roleMap = <String, String>{};
      if (otherUserIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, full_name, email, role')
            .inFilter('id', otherUserIds);

        for (final profile in profiles as List) {
          final profileMapEntry = Map<String, dynamic>.from(profile as Map);
          final id = profileMapEntry['id'].toString();
          roleMap[id] = (profileMapEntry['role'] ?? '').toString();
          final displayName = _profileDisplayName(profileMapEntry);
          if (displayName.isNotEmpty) {
            profileMap[id] = displayName;
            ChatIdentityCache.instance.remember(userId: id, name: displayName);
          }
        }

        final missingIds = otherUserIds
            .where((id) => !profileMap.containsKey(id))
            .toList();
        for (final id in missingIds) {
          final profile = await supabase
              .from('profiles')
              .select('id, full_name, email, role')
              .eq('id', id)
              .maybeSingle();
          if (profile == null) continue;
          roleMap[id] = (profile['role'] ?? '').toString();
          final displayName = _profileDisplayName(
            Map<String, dynamic>.from(profile),
          );
          if (displayName.isNotEmpty) {
            profileMap[id] = displayName;
            ChatIdentityCache.instance.remember(userId: id, name: displayName);
          }
        }
      }

      final conversations = rows
          .where((row) {
            final lastMessage = (row['last_message'] ?? '').toString().trim();
            return lastMessage.isNotEmpty;
          })
          .map((row) {
        final buyerId = (row['buyer_id'] ?? '').toString();
        final sellerId = (row['seller_id'] ?? '').toString();
        final otherUserId = buyerId == user.id ? sellerId : buyerId;
        final otherUserRole = roleMap[otherUserId] ?? '';
        final lastMessageAtRaw = row['last_message_at'];
        final createdAtRaw = row['created_at'];

        return ConversationPreview(
          id: row['id'] as int,
          buyerId: buyerId,
          sellerId: sellerId,
          lastMessage: row['last_message']?.toString(),
          lastMessageAt: lastMessageAtRaw != null
              ? DateTime.tryParse(lastMessageAtRaw.toString())?.toLocal()
              : null,
          createdAt:
              DateTime.tryParse(createdAtRaw.toString())?.toLocal() ??
              DateTime.now(),
          otherUserId: otherUserId,
          otherUserName:
              ChatIdentityCache.instance.nameFor(otherUserId) ??
              profileMap[otherUserId] ??
              _fallbackConversationName(otherUserId, otherUserRole),
          otherUserRole: otherUserRole,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load messages';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return '';

    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inDays == 0) {
      final hour = value.hour > 12
          ? value.hour - 12
          : (value.hour == 0 ? 12 : value.hour);
      final minute = value.minute.toString().padLeft(2, '0');
      final suffix = value.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[value.weekday - 1];
    }

    return '${value.day}/${value.month}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadConversations,
            icon: Icon(Icons.refresh, color: textColor),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: GoogleFonts.inter(color: textColor),
              ),
            )
          : _conversations.isEmpty
          ? Center(
              child: Text(
                'No conversations yet',
                style: GoogleFonts.poppins(
                  color: AppThemeColors.textSecondary(context),
                  fontSize: 18,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _conversations.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final subtitle =
                      (conversation.lastMessage ?? 'Tap to start chatting')
                          .trim();

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'conversationId': conversation.id,
                          'otherUserId': conversation.otherUserId,
                          'otherUserName': conversation.otherUserName,
                        },
                      );
                      _loadConversations();
                    },
                    child: Ink(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppThemeColors.elevatedSurface(context),
                        border: Border.all(
                          color: AppThemeColors.border(context),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(
                              0xFFDB4444,
                            ).withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.person_outline,
                              color: Color(0xFFDB4444),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.otherUserName,
                                  style: GoogleFonts.poppins(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppThemeColors.textSecondary(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTimestamp(
                              conversation.lastMessageAt ??
                                  conversation.createdAt,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppThemeColors.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
