import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscrowPage extends StatefulWidget {
  final int orderId;
  final String role; // 'buyer' or 'seller'

  const EscrowPage({
    super.key,
    required this.orderId,
    required this.role,
  });

  @override
  State<EscrowPage> createState() => _EscrowPageState();
}

class _EscrowPageState extends State<EscrowPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;
  final _imageUrlController = TextEditingController();
  bool _isConfirmed = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfirmation();
  }

  Future<void> _loadExistingConfirmation() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('escrow_confirmations')
          .select()
          .eq('order_id', widget.orderId)
          .eq('role', widget.role)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _isConfirmed = data['confirmed'] ?? false;
          _imageUrlController.text = data['proof_image_url'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading confirmation: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfirmation() async {
    if (_isSaving) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final payload = {
        'order_id': widget.orderId,
        'user_id': user.id,
        'role': widget.role,
        'confirmed': _isConfirmed,
        'proof_image_url': _imageUrlController.text.trim(),
        'confirmed_at': _isConfirmed ? DateTime.now().toIso8601String() : null,
      };

      await supabase.from('escrow_confirmations').upsert(
        payload,
        onConflict: 'order_id, role',
      );

      // Website Parity: Status is NOT updated here. Admin manually marks as completed.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation saved successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
          'Order Confirmation',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.role == 'buyer'
                        ? 'Confirm Receipt of Items'
                        : 'Confirm Shipment of Items',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.role == 'buyer'
                        ? 'Please confirm that you have received all items in the order and they match the description.'
                        : 'Please confirm that you have shipped all items and provide a proof of shipment image.',
                    style: GoogleFonts.inter(
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SwitchListTile(
                    title: Text(
                      'I confirm the ${widget.role == 'buyer' ? 'receipt' : 'shipment'}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      _isConfirmed ? 'Confirmed' : 'Not yet confirmed',
                      style: TextStyle(
                        color: _isConfirmed ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: _isConfirmed,
                    activeColor: primaryRed,
                    onChanged: (val) {
                      setState(() => _isConfirmed = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: 'Proof Image URL',
                      hintText: 'Link to photo of receipt/items',
                      filled: true,
                      fillColor: AppThemeColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_imageUrlController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _imageUrlController.text,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SAVE CONFIRMATION',
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
}
