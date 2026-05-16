import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:my_ui_project/pages/index_page.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.isDismissed,
    required this.createdAt,
    this.data = const {},
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'general').toString(),
      isRead: map['is_read'] as bool? ?? false,
      isDismissed: map['is_dismissed'] as bool? ?? false,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      data: map['data'] is Map ? Map<String, dynamic>.from(map['data']) : {},
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  RealtimeChannel? _notificationsChannel;
  bool _isLoading = true;
  bool _showHistory = false;
  String? _errorMessage;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
    _loadNotifications();
  }

  @override
  void dispose() {
    final channel = _notificationsChannel;
    _notificationsChannel = null;
    if (channel != null) {
      channel.unsubscribe();
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToNotifications() {
    _notificationsChannel = supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) { if (mounted) _loadNotifications(); },
        )
        .subscribe();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() { _notifications = []; _isLoading = false; });
        return;
      }

      final combined = <NotificationModel>[];
      try {
        final notifs = await supabase
            .from('notifications')
            .select('id, title, body, type, is_read, is_dismissed, created_at, data')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);
        combined.addAll((notifs as List)
            .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>)));
      } catch (_) {
        final notifs = await supabase
            .from('notifications')
            .select('id, title, body, type, is_read, created_at, data')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);
        combined.addAll((notifs as List)
            .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>)));
      }

      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final uniqueMap = <String, NotificationModel>{};
      for (var item in combined) {
        uniqueMap.putIfAbsent(item.id, () => item);
      }

      if (!mounted) return;
      setState(() { _notifications = uniqueMap.values.toList(); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'Failed to load notifications'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _dismissNotification(NotificationModel notification) async {
    try {
      if (!notification.id.startsWith('order_') &&
          !notification.id.startsWith('offer_')) {
        await supabase
            .from('notifications')
            .update({'is_dismissed': true})
            .eq('id', notification.id);
      }
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id == notification.id) {
            return NotificationModel(
              id: item.id, title: item.title, body: item.body,
              type: item.type, isRead: item.isRead,
              isDismissed: true, createdAt: item.createdAt,
              data: item.data,
            );
          }
          return item;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      if (!notification.id.startsWith('order_') &&
          !notification.id.startsWith('offer_')) {
        await supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notification.id);
      }
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id == notification.id) {
            return NotificationModel(
              id: item.id, title: item.title, body: item.body,
              type: item.type, isRead: true,
              isDismissed: item.isDismissed, createdAt: item.createdAt,
              data: item.data,
            );
          }
          return item;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _openNotification(NotificationModel notification) async {
    await _markAsRead(notification);
    if (!mounted) return;

    switch (notification.type) {
      case 'message':
        await Navigator.pushNamed(context, '/messages');
        break;
      case 'order':
        final user = supabase.auth.currentUser;
        if (user != null) {
          final profile = await supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          
          final role = profile?['role'];
          final orderId = notification.data['order_id'];

          if (role == 'admin') {
            await Navigator.pushNamed(
              context, 
              '/admin_orders', 
              arguments: {'order_id': orderId}
            );
          } else if (role == 'seller') {
            await Navigator.pushNamed(context, '/seller_orders');
          } else {
            await Navigator.pushNamed(context, '/orders');
          }
        }
        break;
      case 'offer':
        final user = supabase.auth.currentUser;
        if (user != null) {
          final profile = await supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          if (profile?['role'] == 'seller') {
            await Navigator.pushNamed(context, '/seller_offers');
          } else {
            await Navigator.pushNamed(context, '/offers');
          }
        }
        break;
      case 'product':
        final productId = notification.data['product_id'];
        if (productId != null) {
          try {
            final res = await supabase
                .from('products')
                .select()
                .eq('id', productId)
                .maybeSingle();
            if (res != null && mounted) {
              final product = Product.fromMap(Map<String, dynamic>.from(res));
              await Navigator.pushNamed(context, '/details', arguments: product);
            }
          } catch (_) {}
        }
        break;
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => !n.isDismissed && !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // History toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _showHistory = !_showHistory),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showHistory
                      ? primaryRed.withValues(alpha: 0.1)
                      : AppThemeColors.elevatedSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showHistory
                          ? Icons.notifications_active_rounded
                          : Icons.history_rounded,
                      color: _showHistory
                          ? primaryRed
                          : AppThemeColors.textSecondary(context),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _showHistory ? 'Active' : 'History',
                      style: GoogleFonts.inter(
                        color: _showHistory
                            ? primaryRed
                            : AppThemeColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryRed,
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryRed));
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!,
            style: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(context))),
      );
    }

    final filtered =
        _notifications.where((n) => n.isDismissed == _showHistory).toList();

    if (filtered.isEmpty) {
      return _buildEmpty();
    }

    return Column(
      children: [
        // Unread summary chip
        if (!_showHistory && _unreadCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: primaryRed, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_unreadCount unread',
                        style: GoogleFonts.inter(
                          color: primaryRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final notification = filtered[index];
              return Dismissible(
                key: Key(notification.id),
                direction: _showHistory
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
                ),
                onDismissed: (_) => _dismissNotification(notification),
                child: _buildNotificationCard(notification),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    final secondaryText = AppThemeColors.textSecondary(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: primaryRed.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _showHistory
                  ? Icons.history_rounded
                  : Icons.notifications_none_rounded,
              size: 48,
              color: primaryRed.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showHistory ? 'No notification history' : 'You\'re all caught up',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _showHistory
                ? 'Dismissed notifications will appear here'
                : 'New notifications will appear here',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppThemeColors.textMuted(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final typeColor = _colorForType(notification.type);

    return GestureDetector(
      onTap: () => _openNotification(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppThemeColors.surface(context)
              : primaryRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.isRead
                ? Colors.transparent
                : primaryRed.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? typeColor.withValues(alpha: 0.1)
                    : primaryRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconForType(notification.type),
                color: notification.isRead ? typeColor : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4, left: 6),
                          decoration: const BoxDecoration(
                              color: primaryRed, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.inter(
                          color: secondaryText, fontSize: 13, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notification.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(notification.createdAt),
                        style: GoogleFonts.inter(
                            color: AppThemeColors.textMuted(context),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dt.toLocal().toString().split(' ').first;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline_rounded;
      case 'order':   return Icons.shopping_bag_outlined;
      case 'offer':   return Icons.local_offer_outlined;
      default:        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'message': return Colors.blue;
      case 'order':   return Colors.orange;
      case 'offer':   return Colors.green;
      default:        return Colors.grey;
    }
  }
}