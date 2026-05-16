import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _prefillUserInfo();
  }

  void _prefillUserInfo() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      // We could also fetch full_name from profiles if needed
    }
  }

  Future<void> _sendTicket() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await supabase.from('contact_tickets').insert({
        'name': name,
        'email': email,
        'phone': phone,
        'message': message,
        'user_id': supabase.auth.currentUser?.id,
      });

      // Notify admin
      try {
        final admins = await supabase.from('profiles').select('id').eq('role', 'admin');
        for (final admin in (admins as List)) {
          await supabase.from('notifications').insert({
            'user_id': admin['id'],
            'title': 'New Support Ticket',
            'body': 'A new support message from $name ($email).',
            'type': 'admin',
          });
        }
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent successfully! The admin will contact you soon.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
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
          'Contact Us',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get in touch',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fill out the form below and we will contact you within 24 hours.',
              style: GoogleFonts.inter(
                color: AppThemeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _nameController,
              label: 'Your Name *',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Your Email *',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Your Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 6,
              style: GoogleFonts.inter(color: textColor),
              decoration: InputDecoration(
                labelText: 'Your Message *',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppThemeColors.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'SEND MESSAGE',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final textColor = AppThemeColors.textPrimary(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppThemeColors.textSecondary(context), size: 20),
        filled: true,
        fillColor: AppThemeColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
