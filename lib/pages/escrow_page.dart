import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscrowPage extends StatefulWidget {
  final int orderId;
  final String role; // 'buyer' or 'seller'

  const EscrowPage({super.key, required this.orderId, required this.role});

  @override
  State<EscrowPage> createState() => _EscrowPageState();
}

class _EscrowPageState extends State<EscrowPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  final supabase = Supabase.instance.client;
  RealtimeChannel? _escrowChannel;

  final _imageUrlController = TextEditingController();
  final _reviewCommentController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmittingReview = false;

  bool _userConfirmed = false;
  Map<String, dynamic>? _orderData;
  List<dynamic> _orderItems = [];

  Map<String, dynamic>? _sellerConfirmation;
  Map<String, dynamic>? _buyerConfirmation;

  bool _alreadyReviewed = false;
  int _reviewRating = 5;

  @override
  void initState() {
    super.initState();
    _subscribeToEscrowChanges();
    _loadData();
    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    final channel = _escrowChannel;
    _escrowChannel = null;
    if (channel != null) {
      channel.unsubscribe();
      supabase.removeChannel(channel);
    }
    _imageUrlController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  String get _role => widget.role == 'seller' ? 'seller' : 'buyer';

  String get _otherRole => _role == 'seller' ? 'buyer' : 'seller';

  bool get _buyerConfirmed => _buyerConfirmation?['confirmed'] == true;

  bool get _sellerConfirmed => _sellerConfirmation?['confirmed'] == true;

  bool get _otherPartyConfirmed =>
      _otherRole == 'seller' ? _sellerConfirmed : _buyerConfirmed;

  bool get _bothConfirmed => _buyerConfirmed && _sellerConfirmed;

  Map<String, dynamic>? get _currentRoleConfirmation =>
      _role == 'seller' ? _sellerConfirmation : _buyerConfirmation;

  void _subscribeToEscrowChanges() {
    _escrowChannel = supabase
        .channel('public:escrow:${widget.orderId}:${widget.role}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'escrow_confirmations',
          callback: (_) {
            if (mounted) {
              _loadData();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) {
              _loadData();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch order details & items
      final orderRes = await supabase
          .from('orders')
          .select(
            'status, total_price, currency, order_items(product_name, quantity, price, image_url)',
          )
          .eq('id', widget.orderId)
          .maybeSingle();

      if (orderRes != null) {
        _orderData = orderRes;
        _orderItems = orderRes['order_items'] as List? ?? [];
      }

      // 2. Fetch escrow confirmations
      final confsRes = await supabase
          .from('escrow_confirmations')
          .select()
          .eq('order_id', widget.orderId);

      _sellerConfirmation = null;
      _buyerConfirmation = null;
      _userConfirmed = false;

      for (final c in confsRes as List) {
        final cMap = Map<String, dynamic>.from(c as Map);
        if (cMap['role'] == 'seller') {
          _sellerConfirmation = cMap;
          if (_role == 'seller') {
            _userConfirmed = cMap['confirmed'] == true;
            _imageUrlController.text = cMap['proof_image_url'] ?? '';
          }
        } else if (cMap['role'] == 'buyer') {
          _buyerConfirmation = cMap;
          if (_role == 'buyer') {
            _userConfirmed = cMap['confirmed'] == true;
            _imageUrlController.text = cMap['proof_image_url'] ?? '';
          }
        }
      }

      _alreadyReviewed = false;

      // 3. Fetch review if buyer & completed
      if (_role == 'buyer' && _orderData?['status'] == 'completed') {
        final reviewRes = await supabase
            .from('reviews')
            .select()
            .eq('order_id', widget.orderId)
            .eq('buyer_id', user.id)
            .maybeSingle();
        _alreadyReviewed = reviewRes != null;
      }
    } catch (e) {
      debugPrint('Error loading escrow data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConfirmation() async {
    if (_isSaving) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_userConfirmed || _currentRoleConfirmation?['confirmed'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your confirmation is already submitted and locked'),
        ),
      );
      return;
    }

    final proofUrl = _imageUrlController.text.trim();
    if (proofUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a proof image URL')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'order_id': widget.orderId,
        'user_id': user.id,
        'role': _role,
        'confirmed': true,
        'proof_image_url': proofUrl,
        'confirmed_at': DateTime.now().toIso8601String(),
      };

      final existingConfirmation = _currentRoleConfirmation;
      if (existingConfirmation == null) {
        await supabase.from('escrow_confirmations').insert(payload);
      } else {
        final updated = await supabase
            .from('escrow_confirmations')
            .update(payload)
            .eq('id', existingConfirmation['id'])
            .eq('confirmed', false)
            .select('id')
            .maybeSingle();
        if (updated == null) {
          throw Exception('Your confirmation is already locked.');
        }
      }

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit confirmation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmittingReview) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_role != 'buyer' || _orderData?['status'] != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reviews are available after order completion'),
        ),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    try {
      final itemRes = await supabase
          .from('order_items')
          .select('seller_id')
          .eq('order_id', widget.orderId)
          .limit(1)
          .maybeSingle();

      final sellerId = itemRes?['seller_id']?.toString();
      if (sellerId == null || sellerId.isEmpty) {
        throw Exception('Could not determine seller for this order.');
      }

      await supabase.from('reviews').insert({
        'order_id': widget.orderId,
        'seller_id': sellerId,
        'buyer_id': user.id,
        'rating': _reviewRating,
        'comment': _reviewCommentController.text.trim(),
      });

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully. Thank you!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  String _formatPrice(double val) {
    final currency = _orderData?['currency'] ?? 'EGP';
    return '$currency ${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final status = _orderData?['status'] ?? 'pending';

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
          'Confirm Order #${widget.orderId}',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle explanation
                    Text(
                      'Order #${widget.orderId} — Escrow Confirmation',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are confirming as the ${_role.toUpperCase()}.\nBoth parties must confirm with photo proof before the admin releases payment to the seller.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status notification banner
                    if (status == 'completed' || status == 'cancelled') ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'completed'
                              ? Colors.green.withValues(alpha: 0.08)
                              : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: status == 'completed'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              status == 'completed'
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: status == 'completed'
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status == 'completed'
                                        ? 'This order is completed.'
                                        : 'This order is cancelled.',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: status == 'completed'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    status == 'completed'
                                        ? 'Payment has been released to the seller.'
                                        : 'This order has been cancelled and no further action is needed.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: status == 'completed'
                                          ? Colors.green.withValues(alpha: 0.8)
                                          : Colors.red.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Status panel grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildActorStatusCard(
                            'Seller',
                            _sellerConfirmed,
                            _sellerConfirmation?['proof_image_url'],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActorStatusCard(
                            'Buyer',
                            _buyerConfirmed,
                            _buyerConfirmation?['proof_image_url'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Confirmation form
                    if (status != 'completed' && status != 'cancelled') ...[
                      if (_userConfirmed)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.green,
                                size: 32,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Your confirmation is submitted and locked.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _bothConfirmed
                                    ? 'Both parties have confirmed. Waiting for admin release.'
                                    : _otherPartyConfirmed
                                    ? 'The other party has also confirmed. Waiting for admin release.'
                                    : 'Waiting for the other party to confirm.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.green.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submit Your Confirmation',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Upload photo proof (URL)\n(${_role == 'seller' ? 'photo showing you shipped the item' : 'photo showing you received the item'})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: secondaryText,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _imageUrlController,
                                style: GoogleFonts.inter(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'Proof Image URL',
                                  hintText: 'https://example.com/proof.jpg',
                                  labelStyle: TextStyle(color: secondaryText),
                                  hintStyle: TextStyle(
                                    color: AppThemeColors.textMuted(context),
                                  ),
                                  filled: true,
                                  fillColor: AppThemeColors.elevatedSurface(
                                    context,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.image_outlined,
                                    color: secondaryText,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (_imageUrlController.text
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imageUrlController.text.trim(),
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, err, st) => Container(
                                      height: 160,
                                      color: AppThemeColors.elevatedSurface(
                                        context,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            size: 32,
                                            color: secondaryText,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Invalid image URL',
                                            style: TextStyle(
                                              color: secondaryText,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSaving
                                      ? null
                                      : _saveConfirmation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(
                                          'Submit Confirmation',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 24),

                    // Order summary section
                    _buildOrderSummaryCard(),

                    // Review section
                    if (_role == 'buyer' && status == 'completed') ...[
                      const SizedBox(height: 24),
                      _buildReviewSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActorStatusCard(String actor, bool confirmed, String? imageUrl) {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confirmed
            ? Colors.green.withValues(alpha: 0.05)
            : AppThemeColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: confirmed
              ? Colors.green.withValues(alpha: 0.25)
              : AppThemeColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actor.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                confirmed
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: confirmed ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                confirmed ? 'Confirmed' : 'Waiting…',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: confirmed ? Colors.green : textColor,
                ),
              ),
            ],
          ),
          if (confirmed && imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _viewProofFullScreen(imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, err, st) => Container(
                    height: 100,
                    color: AppThemeColors.elevatedSurface(context),
                    child: const Icon(Icons.broken_image, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewProofFullScreen(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Proof of Escrow',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final totalPrice = _orderData?['total_price'] is num
        ? (_orderData?['total_price'] as num).toDouble()
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderItems.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _orderItems[index];
              final productPrice = item['price'] is num
                  ? (item['price'] as num).toDouble()
                  : 0.0;
              final qty = item['quantity'] as int? ?? 1;
              final image = item['image_url']?.toString();

              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: AppThemeColors.elevatedSurface(context),
                      child: image != null && image.isNotEmpty
                          ? Image.network(image, fit: BoxFit.cover)
                          : const Icon(Icons.inventory_2_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['product_name'] ?? 'Product').toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: $qty',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPrice(productPrice * qty),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Divider(color: AppThemeColors.border(context)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                _formatPrice(totalPrice),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);

    if (_alreadyReviewed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppThemeColors.border(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.rate_review_outlined,
              color: Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'You have already reviewed this order. Thank you!',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave a Review for the Seller',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rating',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => InkWell(
                onTap: () {
                  setState(() {
                    _reviewRating = index + 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    index < _reviewRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: index < _reviewRating
                        ? Colors.amber
                        : Colors.grey.withValues(alpha: 0.5),
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Comment (optional)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewCommentController,
            maxLines: 3,
            style: GoogleFonts.inter(color: textColor),
            decoration: InputDecoration(
              hintText: 'How was your experience with this seller?',
              hintStyle: TextStyle(color: AppThemeColors.textMuted(context)),
              filled: true,
              fillColor: AppThemeColors.elevatedSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmittingReview
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
