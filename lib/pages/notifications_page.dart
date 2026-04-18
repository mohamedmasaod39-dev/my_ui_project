import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'general').toString(),
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
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
          callback: (_) {
            if (mounted) {
              _loadNotifications();
            }
          },
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
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('notifications')
          .select('id, title, body, type, is_read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((item) => NotificationModel.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _notifications = loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load notifications';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notification.id);

      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? NotificationModel(
                      id: item.id,
                      title: item.title,
                      body: item.body,
                      type: item.type,
                      isRead: true,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<String> _homeRoute() async {
    final user = supabase.auth.currentUser;
    if (user == null) return '/login';

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final role = (profile?['role'] ?? 'buyer').toString();
    if (role == 'admin') return '/admin';
    if (role == 'seller') return '/seller_home';
    return '/home';
  }

  Future<void> _openNotification(NotificationModel notification) async {
    await _markAsRead(notification);
    if (!mounted) return;

    switch (notification.type) {
      case 'message':
        await Navigator.pushNamed(context, '/messages');
        break;
      default:
        final route = await _homeRoute();
        if (!mounted) return;
        await Navigator.pushNamed(context, route);
        break;
    }

    if (mounted) {
      _loadNotifications();
    }
  }

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
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        children: [
          SizedBox(height: 500, child: Center(child: Text(_errorMessage!))),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 500,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () async {
                      final route = await _homeRoute();
                      if (!mounted) return;
                      Navigator.pushNamed(context, route);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Back To Home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final textColor = AppThemeColors.textPrimary(context);
        return GestureDetector(
          onTap: () => _openNotification(notification),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? AppThemeColors.surface(context)
                  : primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: notification.isRead
                    ? Colors.transparent
                    : primaryRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: notification.isRead
                      ? AppThemeColors.elevatedSurface(context)
                      : primaryRed,
                  child: Icon(
                    Icons.notifications_none,
                    color: notification.isRead ? textColor : Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body.isEmpty
                            ? 'No additional details'
                            : notification.body,
                        style: GoogleFonts.inter(
                          color: AppThemeColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.createdAt
                            .toLocal()
                            .toString()
                            .split('.')
                            .first,
                        style: GoogleFonts.inter(
                          color: AppThemeColors.textMuted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
