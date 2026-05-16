import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/services/checkout_info_service.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
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

  Future<void> _removeFromCart(int cartItemId) async {
    try {
      await supabase.from('cart_items').delete().eq('id', cartItemId);

      await _loadCart();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item removed from cart')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove item')));
    }
  }

  Future<void> _updateCartQuantity(CartItemModel item, int quantity) async {
    if (item.product.stockQty <= 0) return;
    final clampedQuantity = quantity.clamp(1, item.product.stockQty).toInt();
    if (clampedQuantity == item.quantity) return;

    try {
      await supabase
          .from('cart_items')
          .update({'quantity': clampedQuantity})
          .eq('id', item.id);
      await _loadCart();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update quantity')),
      );
    }
  }

  Future<bool> _validateCartStock(String userId) async {
    final unavailableItems = _cartItems
        .where((item) => !item.product.isBuyable)
        .toList();
    if (unavailableItems.isNotEmpty) {
      await supabase
          .from('cart_items')
          .delete()
          .inFilter('id', unavailableItems.map((item) => item.id).toList());
      await _loadCart();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unavailable products were removed from your cart'),
        ),
      );
      return false;
    }

    final overStockItems = _cartItems
        .where((item) => item.quantity > item.product.stockQty)
        .toList();
    if (overStockItems.isNotEmpty) {
      for (final item in overStockItems) {
        await supabase
            .from('cart_items')
            .update({'quantity': item.product.stockQty})
            .eq('id', item.id);
      }
      await _loadCart();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart quantities were adjusted to available stock'),
        ),
      );
      return false;
    }

    final ownItems = _cartItems
        .where((item) => item.product.isOwnedBy(userId))
        .toList();
    if (ownItems.isNotEmpty) {
      await supabase
          .from('cart_items')
          .delete()
          .inFilter('id', ownItems.map((item) => item.id).toList());
      await _loadCart();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your own product was removed from the cart'),
        ),
      );
      return false;
    }

    return true;
  }

  double get _subtotal {
    double total = 0;
    for (final item in _cartItems) {
      total += item.product.price * item.quantity;
    }
    return total;
  }

  double get _shippingFee {
    // Website Parity: On the cart page, shipping is displayed as "Free" (0)
    // The actual fee is calculated and added only at the final checkout step.
    return 0;
  }

  double _calculateActualShipping(double subtotal) {
    if (subtotal <= 0) return 0;
    final fee = subtotal * 0.01;
    return fee < 100 ? 100 : fee; // max(100, subtotal * 0.01)
  }

  double get _total => _subtotal + _shippingFee;

  String _formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }

  Map<String, List<CartItemModel>> _groupCartItemsBySeller() {
    final grouped = <String, List<CartItemModel>>{};

    for (final item in _cartItems) {
      final sellerId = item.product.sellerId?.trim();
      final sellerKey = sellerId != null && sellerId.isNotEmpty
          ? sellerId
          : 'unknown-seller';
      grouped.putIfAbsent(sellerKey, () => []).add(item);
    }

    return grouped;
  }

  Future<void> _checkout() async {
    if (_isCheckingOut || _cartItems.isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    await _loadCart();
    if (!mounted || _cartItems.isEmpty) return;

    final cartIsValid = await _validateCartStock(user.id);
    if (!cartIsValid) {
      return;
    }

    final savedCheckout = await CheckoutInfoService.instance.load(user.id);
    if (!mounted) return;
    final nameController = TextEditingController(text: savedCheckout.fullName);
    final phoneController = TextEditingController(
      text: savedCheckout.phoneNumber,
    );
    final emailController = TextEditingController(
      text: savedCheckout.email.isNotEmpty
          ? savedCheckout.email
          : user.email ?? '',
    );
    final companyController = TextEditingController(
      text: savedCheckout.company,
    );
    final addressController = TextEditingController(
      text: savedCheckout.address,
    );
    final addressLine2Controller = TextEditingController(
      text: savedCheckout.addressLine2,
    );
    final cityController = TextEditingController(text: savedCheckout.city);
    final stateController = TextEditingController(text: savedCheckout.state);
    final zipController = TextEditingController(text: savedCheckout.zipCode);
    final cardNameController = TextEditingController(
      text: savedCheckout.cardHolderName,
    );
    final cardNumberController = TextEditingController();
    final expDateController = TextEditingController(
      text: savedCheckout.cardExpiry,
    );
    final cvcController = TextEditingController();

    String paymentMethod = savedCheckout.paymentMethod.isNotEmpty
        ? savedCheckout.paymentMethod
        : 'Card';
    int checkoutStep = 0;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isShippingStep = checkoutStep == 0;
            final isPaymentStep = checkoutStep == 1;
            final dialogTextColor = AppThemeColors.textPrimary(dialogContext);
            final dialogSurface = AppThemeColors.elevatedSurface(dialogContext);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              backgroundColor: dialogSurface,
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
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                color: dialogTextColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              icon: Icon(Icons.close, color: dialogTextColor),
                            ),
                          ],
                        ),
                        Text(
                          'Checkout',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: dialogTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildCheckoutStepper(checkoutStep),
                        const SizedBox(height: 28),
                        if (isShippingStep) ...[
                          _buildCheckoutField(
                            controller: nameController,
                            label: 'Name',
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: phoneController,
                            label: 'Phone Number',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: companyController,
                            label: 'Company (optional)',
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: addressController,
                            label: 'Street Address',
                          ),
                          const SizedBox(height: 16),
                          _buildCheckoutField(
                            controller: addressLine2Controller,
                            label: 'Apartment, floor, etc. (optional)',
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
                        ],
                        if (isPaymentStep) ...[
                          if (savedCheckout.hasSavedCard) ...[
                            Text(
                              'Saved card ending ${savedCheckout.cardLast4}',
                              style: GoogleFonts.inter(
                                color: AppThemeColors.textSecondary(
                                  dialogContext,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildCheckoutField(
                            controller: cardNameController,
                            label: 'Name on Card',
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(3),
                                    ],
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
                              if (isShippingStep) {
                                if (nameController.text.trim().isEmpty ||
                                    phoneController.text.trim().isEmpty ||
                                    emailController.text.trim().isEmpty ||
                                    addressController.text.trim().isEmpty ||
                                    cityController.text.trim().isEmpty ||
                                    stateController.text.trim().isEmpty ||
                                    zipController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please complete your shipping details',
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
                                      expDateController.text.trim().isEmpty ||
                                      (!savedCheckout.hasSavedCard &&
                                          (cardNumberController.text
                                                  .trim()
                                                  .isEmpty ||
                                              cvcController.text
                                                  .trim()
                                                  .isEmpty)))) {
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
                              backgroundColor:
                                  AppThemeColors.isDark(dialogContext)
                                  ? Colors.white
                                  : Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isShippingStep ? 'NEXT' : 'PAY NOW',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppThemeColors.isDark(dialogContext)
                                    ? Colors.black
                                    : Colors.white,
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

    await _loadCart();
    if (!mounted || _cartItems.isEmpty) return;
    final latestCartIsValid = await _validateCartStock(user.id);
    if (!latestCartIsValid) return;

    setState(() {
      _isCheckingOut = true;
    });
    final fullName = nameController.text.trim();
    final phoneNumber = phoneController.text.trim();
    final email = emailController.text.trim();
    final company = companyController.text.trim();
    final address = addressController.text.trim();
    final addressLine2 = addressLine2Controller.text.trim();
    final city = cityController.text.trim();
    final state = stateController.text.trim();
    final zipCode = zipController.text.trim();
    final cardHolderName = cardNameController.text.trim();
    final cardDigits = cardNumberController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final cardLast4 = cardDigits.length >= 4
        ? cardDigits.substring(cardDigits.length - 4)
        : cardDigits;
    final cardExpiry = expDateController.text.trim();
    final effectiveCardLast4 = cardLast4.isNotEmpty
        ? cardLast4
        : savedCheckout.cardLast4;

    try {
      for (final item in _cartItems) {
        if (item.product.sellerId == null || item.product.sellerId!.isEmpty) {
          throw Exception(
            'One or more products are missing seller information.',
          );
        }
        if (item.product.isOwnedBy(user.id)) {
          throw Exception('You cannot buy your own product.');
        }
        if (!item.product.isBuyable) {
          throw Exception('${item.product.title} is out of stock.');
        }
        if (item.quantity > item.product.stockQty) {
          throw Exception(
            'Only ${item.product.stockQty} left for ${item.product.title}.',
          );
        }
      }

      final createdOrderIds = <int>[];
      final groupedCartItems = _groupCartItemsBySeller();

      final totalSubtotal = _subtotal;
      final totalShipping = _calculateActualShipping(totalSubtotal);
      int orderCount = 0;
      double distributedShippingSum = 0;

      for (final sellerItems in groupedCartItems.values) {
        orderCount++;
        final sellerTotal = sellerItems.fold<double>(
          0,
          (sum, item) => sum + (item.product.price * item.quantity),
        );
        
        // Distribute shipping proportionally
        double sellerShipping;
        if (orderCount == groupedCartItems.length) {
          // Last seller gets the remainder to avoid rounding issues
          sellerShipping = totalShipping - distributedShippingSum;
        } else {
          sellerShipping = (totalShipping * (sellerTotal / totalSubtotal));
          distributedShippingSum += sellerShipping;
        }

        final insertedOrder = await supabase
            .from('orders')
            .insert({
              'buyer_id': user.id,
              'seller_id': sellerItems.first.product.sellerId,
              'subtotal_price': sellerTotal,
              'shipping_price': sellerShipping,
              'total_price': sellerTotal + sellerShipping,
              'currency': sellerItems.first.product.currency,
              'shipping_address': address,
              'address_line2': addressLine2,
              'phone_number': phoneNumber,
              'customer_email': email,
              'company': company,
              'payment_method': paymentMethod,
              'customer_name': fullName,
              'city': city,
              'state': state,
              'zipcode': zipCode,
              'card_holder_name': paymentMethod == 'Card'
                  ? cardHolderName
                  : null,
              'card_last4':
                  paymentMethod == 'Card' && effectiveCardLast4.isNotEmpty
                  ? effectiveCardLast4
                  : null,
              'card_expiry': paymentMethod == 'Card' && cardExpiry.isNotEmpty
                  ? cardExpiry
                  : null,
            })
            .select('id')
            .single();

        final orderId = insertedOrder['id'] as int;
        createdOrderIds.add(orderId);

        final orderItems = sellerItems
            .map(
              (item) => {
                'order_id': orderId,
                'product_id': item.product.id,
                'seller_id': item.product.sellerId,
                'price': item.product.price,
                'quantity': item.quantity,
                'product_name': item.product.title,
                'image_url': item.product.image,
                'line_total_price': item.product.price * item.quantity,
                'currency': item.product.currency,
              },
            )
            .toList();

        await supabase.from('order_items').insert(orderItems);

        // Notify seller about new order
        try {
          await supabase.from('notifications').insert({
            'user_id': sellerItems.first.product.sellerId,
            'sender_id': user.id,
            'title': 'New Order Received',
            'body': '$fullName placed an order for ${sellerItems.length} item(s).',
            'type': 'order',
            'data': {'order_id': orderId},
          });
        } catch (_) {}

        // Notify Admins about new order
        try {
          final adminsResponse = await supabase
              .from('profiles')
              .select('id')
              .eq('role', 'admin');
          
          final adminIds = (adminsResponse as List).map((a) => a['id']).toList();
          
          for (final adminId in adminIds) {
            await supabase.from('notifications').insert({
              'user_id': adminId,
              'sender_id': user.id,
              'title': 'New Order Placed',
              'body': '$fullName placed a new order (#$orderId).',
              'type': 'order',
              'data': {'order_id': orderId},
            });
          }
        } catch (_) {}
      }

      await CheckoutInfoService.instance.save(
        user.id,
        CheckoutInfo(
          fullName: fullName,
          phoneNumber: phoneNumber,
          email: email,
          company: company,
          address: address,
          addressLine2: addressLine2,
          city: city,
          state: state,
          zipCode: zipCode,
          paymentMethod: paymentMethod,
          cardHolderName: cardHolderName,
          cardLast4: effectiveCardLast4,
          cardExpiry: cardExpiry,
        ),
      );

      await supabase
          .from('cart_items')
          .delete()
          .inFilter('id', _cartItems.map((item) => item.id).toList());

      await _loadCart();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/checkout_success',
        (route) => route.settings.name == '/home',
        arguments: createdOrderIds.length == 1
            ? createdOrderIds.first
            : createdOrderIds,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    } finally {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      companyController.dispose();
      addressController.dispose();
      addressLine2Controller.dispose();
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
    final isDark = AppThemeColors.isDark(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  color: isDark
                      ? AppThemeColors.secondarySurface(context)
                      : Colors.black,
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
                        "Shipping",
                        _shippingFee == 0 ? "Free" : _formatPrice(_shippingFee),
                        Colors.white70,
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
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                _formatPrice(_total),
                                style: GoogleFonts.poppins(
                                  color: AppThemeColors.textPrimary(context),
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
    final textColor = AppThemeColors.textPrimary(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: textColor),
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "Your Basket",
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
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
                  color: AppThemeColors.textSecondary(context),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(
              "Your Basket",
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
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
        const SliverToBoxAdapter(child: SizedBox(height: 250)),
      ],
    );
  }

  Widget _buildAnimatedCartItem(CartItemModel item) {
    final product = item.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 150,
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppThemeColors.surface(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Hero(
              tag: product.tag,
              child: product.image != null && product.image!.isNotEmpty
                  ? Image.network(
                      product.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: AppThemeColors.textMuted(context),
                        );
                      },
                    )
                  : Icon(
                      Icons.image,
                      size: 40,
                      color: AppThemeColors.textMuted(context),
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
                    color: AppThemeColors.textPrimary(context),
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
                    _quantityButton(
                      icon: Icons.remove,
                      onTap: item.quantity <= 1
                          ? null
                          : () => _updateCartQuantity(item, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.poppins(
                          color: AppThemeColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _quantityButton(
                      icon: Icons.add,
                      onTap: item.quantity >= product.stockQty
                          ? null
                          : () => _updateCartQuantity(item, item.quantity + 1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stock: ${product.stockQty}',
                      style: GoogleFonts.inter(
                        color: AppThemeColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppThemeColors.textSecondary(context),
            ),
            onPressed: () => _removeFromCart(item.id),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppThemeColors.surface(context)
              : AppThemeColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemeColors.border(context)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? AppThemeColors.textMuted(context)
              : AppThemeColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: AppThemeColors.textMuted(context)),
          ),
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
    final textColor = AppThemeColors.textPrimary(context);
    final secondaryText = AppThemeColors.textSecondary(context);
    final isDark = AppThemeColors.isDark(context);

    final labels = ['Shipping Address', 'Payment', 'Confirmation'];

    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final connectorActive = step > (index ~/ 2);
          return Expanded(
            child: Container(
              height: 1.6,
              color: connectorActive
                  ? textColor
                  : AppThemeColors.border(context),
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
                color: isActive ? textColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              labels[itemIndex],
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isActive ? textColor : secondaryText,
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
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppThemeColors.textPrimary(context),
      ),
      decoration: _checkoutInputDecoration(label),
    );
  }

  InputDecoration _checkoutInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: AppThemeColors.textSecondary(context),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppThemeColors.border(context)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppThemeColors.textPrimary(context),
          width: 1.4,
        ),
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
