import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await supabase
          .from('profiles')
          .select('id, full_name, email, role, is_suspended');

      if (!mounted) return;
      setState(() {
        _users = (response as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading users: $e';
      });
    }
  }

  Future<int> _getSalesCount(String sellerId) async {
    try {
      final response = await supabase
          .from('order_items')
          .select('id')
          .eq('seller_id', sellerId);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);

    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final roleFilter = args['role'] as String?;

    final title = roleFilter == null
        ? 'Users Management'
        : roleFilter == 'buyer'
            ? 'Buyers'
            : roleFilter == 'seller'
                ? 'Sellers'
                : 'Users Management';

    final filteredUsers = roleFilter == null
        ? _users
        : _users.where((u) => u['role'].toString().toLowerCase() == roleFilter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: primaryRed),
                    ),
                  ),
                )
              : filteredUsers.isEmpty
                  ? _buildEmpty(secondaryText, roleFilter)
                  : RefreshIndicator(
                      color: primaryRed,
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) =>
                            _buildUserCard(filteredUsers[index], textColor, secondaryText),
                      ),
                    ),
    );
  }

  Widget _buildEmpty(Color secondaryText, String? roleFilter) {
    final label = roleFilter == null ? 'users' : '${roleFilter}s';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline_rounded, size: 48, color: primaryRed.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            'No $label found',
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
      Map<String, dynamic> user, Color textColor, Color secondaryText) {
    final role = (user['role'] ?? 'user').toString();
    final initial = ((user['full_name'] ?? user['email'] ?? '?')
            .toString()
            .trim()
            .isNotEmpty
        ? (user['full_name'] ?? user['email']).toString().trim()[0]
        : '?').toUpperCase();

    final roleColor = role == 'admin'
        ? Colors.blue
        : role == 'seller'
            ? Colors.orange
            : role == 'buyer'
                ? Colors.green
                : secondaryText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryRed, const Color(0xFFFF6B6B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          (user['full_name'] ?? 'Unknown').toString(),
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              user['email']?.toString() ?? '',
              style: GoogleFonts.inter(color: secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (role == 'seller') ...[
                  const SizedBox(width: 8),
                  FutureBuilder<int>(
                    future: _getSalesCount(user['id'].toString()),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        '• $count Sales',
                        style: GoogleFonts.inter(
                          color: Colors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.more_vert_rounded, color: secondaryText, size: 18),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppThemeColors.surface(context),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'User Details: ${user['full_name']}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: Colors.purple),
                    title: const Text('View User Orders'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context, 
                        '/admin_orders', 
                        arguments: {'user_id': user['id']}
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}