import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'index_page.dart';

class CartItemModel {
  final int id;
  final int quantity;
  final Product product;

  CartItemModel({
    required this.id,
    required this.quantity,
    required this.product,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: map['id'] as int,
      quantity: map['quantity'] as int? ?? 1,
      product: Product.fromMap(
        Map<String, dynamic>.from(map['products'] as Map),
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isCheckingOut = false;
  String? _errorMessage;
  List<CartItemModel> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _cartItems = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('cart_items')
          .select('id, quantity, products(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _cartItems = items;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cart';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartItemModel item, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      await supabase
          .from('cart_items')
          .update({'quantity': newQuantity})
          .eq('id', item.id);

      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update quantity')),
      );
    }
  }

  Future<void> _removeFromCart(int cartItemId) async {
    try {
      await supabase.from('cart_items').delete().eq('id', cartItemId);

      await _loadCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed from cart')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  double get _subtotal {
    double total = 0;
    for (final item in _cartItems) {
      total += item.product.price * item.quantity;
    }
    return total;
  }

  String _formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }

  Future<void> _checkout() async {
    if (_isCheckingOut || _cartItems.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final zipController = TextEditingController();
    final cardNameController = TextEditingController();
    final cardNumberController = TextEditingController();
    final expDateController = TextEditingController();
    final cvcController = TextEditingController();

    String paymentMethod = 'Card';
    bool useSameAddress = true;
    int checkoutStep = 0;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isBillingStep = checkoutStep == 0;
            final isPaymentStep = checkoutStep == 1;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: SizedBox(
                width: 420,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (checkoutStep == 0) {
                                  Navigator.of(dialogContext).pop(false);
                                  return;
                                }
                                setDialogState(() {
                                  checkoutStep -= 1;
                                });
                              },
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              icon: const Icon(Icons.close, color: Colors.black),
                            ),
                          ],
                        ),
                        Text(
                          'Checkout',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildCheckoutStepper(checkoutStep),
                        const SizedBox(height: 28),
                        if (isBillingStep) ...[
                          _buildCheckoutField(
                            controller: nameController,
                            label: 'Name',
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: addressController,
                            label: 'Address',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCheckoutField(
                                  controller: cityController,
                                  label: 'City',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildCheckoutField(
                                  controller: stateController,
                                  label: 'State',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: zipController,
                            label: 'Zipcode',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                useSameAddress = !useSameAddress;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    useSameAddress
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    size: 20,
                                    color:
                                        useSameAddress ? primaryRed : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Shipping address is the same as billing',
                                    style: GoogleFonts.inter(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (isPaymentStep) ...[
                          _buildCheckoutField(
                            controller: cardNameController,
                            label: 'Name on Card',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: _checkoutInputDecoration(
                              'Payment Method',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Card',
                                child: Text('Card'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                paymentMethod = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (paymentMethod == 'Card') ...[
                            _buildCheckoutField(
                              controller: cardNumberController,
                              label: 'Card Number',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _CardNumberInputFormatter(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCheckoutField(
                                    controller: expDateController,
                                    label: 'Exp Date',
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildCheckoutField(
                                    controller: cvcController,
                                    label: 'CVC',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isBillingStep) {
                                if (nameController.text.trim().isEmpty ||
                                    addressController.text.trim().isEmpty ||
                                    cityController.text.trim().isEmpty ||
                                    stateController.text.trim().isEmpty ||
                                    zipController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please complete your billing details',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  checkoutStep = 1;
                                });
                                return;
                              }

                              if (paymentMethod == 'Card' &&
                                  (cardNameController.text.trim().isEmpty ||
                                      cardNumberController.text.trim().isEmpty ||
                                      expDateController.text.trim().isEmpty ||
                                      cvcController.text.trim().isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please complete your card details',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(dialogContext).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isBillingStep ? 'NEXT' : 'PAY NOW',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isCheckingOut = true;
    });
    final fullName = nameController.text.trim();
    final address = addressController.text.trim();
    final city = cityController.text.trim();
    final state = stateController.text.trim();
    final zipCode = zipController.text.trim();
    final cardHolderName = cardNameController.text.trim();
    final cardDigits = cardNumberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final cardLast4 = cardDigits.length >= 4
        ? cardDigits.substring(cardDigits.length - 4)
        : cardDigits;
    final cardExpiry = expDateController.text.trim();

    try {
      for (final item in _cartItems) {
        if (item.product.sellerId == null || item.product.sellerId!.isEmpty) {
          throw Exception('One or more products are missing seller information.');
        }
      }

      final insertedOrder = await supabase
          .from('orders')
          .insert({
            'buyer_id': user.id,
            'total_price': _subtotal,
            'shipping_address': address,
            'payment_method': paymentMethod,
            'customer_name': fullName,
            'city': city,
            'state': state,
            'zipcode': zipCode,
            'shipping_same_as_billing': useSameAddress,
            'card_holder_name': paymentMethod == 'Card' ? cardHolderName : null,
            'card_last4': paymentMethod == 'Card' && cardLast4.isNotEmpty
                ? cardLast4
                : null,
            'card_expiry': paymentMethod == 'Card' && cardExpiry.isNotEmpty
                ? cardExpiry
                : null,
          })
          .select('id')
          .single();

      final orderId = insertedOrder['id'] as int;

      final orderItems = _cartItems
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.product.id,
              'seller_id': item.product.sellerId,
              'price': item.product.price,
              'quantity': item.quantity,
            },
          )
          .toList();

      await supabase.from('order_items').insert(orderItems);

      await supabase.from('cart_items').delete().eq('user_id', user.id);

      await _loadCart();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/checkout_success',
        (route) => route.settings.name == '/home',
        arguments: orderId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    } finally {
      nameController.dispose();
      addressController.dispose();
      cityController.dispose();
      stateController.dispose();
      zipController.dispose();
      cardNameController.dispose();
      cardNumberController.dispose();
      expDateController.dispose();
      cvcController.dispose();
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBody(),
          if (!_isLoading && _errorMessage == null && _cartItems.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSummaryRow(
                        "Subtotal",
                        _formatPrice(_subtotal),
                        Colors.white70,
                      ),
                      _buildSummaryRow(
                        "Delivery",
                        "FREE",
                        Colors.greenAccent,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Divider(color: Colors.white24),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Price",
                                style: GoogleFonts.inter(color: Colors.white54),
                              ),
                              Text(
                                _formatPrice(_subtotal),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isCheckingOut ? null : _checkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 35,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isCheckingOut
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      "CHECKOUT",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCart,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "Your Basket",
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                "Your cart is empty",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          expandedHeight: 120.0,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(
              "Your Basket",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAnimatedCartItem(_cartItems[index]),
              childCount: _cartItems.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 250),
        ),
      ],
    );
  }

  Widget _buildAnimatedCartItem(CartItemModel item) {
    final product = item.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 120,
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Hero(
              tag: product.tag,
              child: product.image != null && product.image!.isNotEmpty
                  ? Image.network(
                      product.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.grey,
                        );
                      },
                    )
                  : const Icon(
                      Icons.image,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatPrice(product.price),
                  style: GoogleFonts.inter(
                    color: primaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _qtyBtn(
                      Icons.remove,
                      () => _updateQuantity(item, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "${item.quantity}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      Icons.add,
                      () => _updateQuantity(item, item.quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () => _removeFromCart(item.id),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white54)),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutStepper(int step) {
    final labels = ['Billing', 'Payment', 'Confirmation'];

    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final connectorActive = step > (index ~/ 2);
          return Expanded(
            child: Container(
              height: 1.6,
              color: connectorActive ? Colors.black : Colors.black26,
            ),
          );
        }

        final itemIndex = index ~/ 2;
        final isActive = itemIndex <= step;

        return Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isActive ? Colors.black : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[itemIndex],
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isActive ? Colors.black : Colors.black45,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCheckoutField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: _checkoutInputDecoration(label),
    );
  }

  InputDecoration _checkoutInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.black45),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black26),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final truncated = digitsOnly.length > 16
        ? digitsOnly.substring(0, 16)
        : digitsOnly;

    final buffer = StringBuffer();
    for (var i = 0; i < truncated.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(truncated[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
