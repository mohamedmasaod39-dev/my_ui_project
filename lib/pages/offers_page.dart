import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfferModel {
  final int id;
  final int productId;
  final String buyerId;
  final String sellerId;
  final double offerPrice;
  final String status;
  final DateTime createdAt;
  final String productTitle;
  final String? productImage;

  const OfferModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.offerPrice,
    required this.status,
    required this.createdAt,
    required this.productTitle,
    required this.productImage,
  });

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['offer_price'];
    final product = map['products'] as Map<String, dynamic>?;
    return OfferModel(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      buyerId: (map['buyer_id'] ?? '').toString(),
      sellerId: (map['seller_id'] ?? '').toString(),
      offerPrice: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('${rawPrice ?? 0}') ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      productTitle: (product?['title'] ?? 'Unknown product').toString(),
      productImage: product?['main_image_url']?.toString(),
    );
  }
}

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCheckingOut = false;
  String? _errorMessage;
  List<OfferModel> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _offers = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('offers')
          .select('id, product_id, buyer_id, seller_id, offer_price, status, created_at, products(title, main_image_url)')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final loaded = (response as List)
          .map((item) => OfferModel.fromMap(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _offers = loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load offers';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(double price) => 'EGP ${price.toStringAsFixed(0)}';

  Future<void> _checkoutAcceptedOffer(OfferModel offer) async {
    if (_isCheckingOut) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
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

                              if (cardNameController.text.trim().isEmpty ||
                                  cardNumberController.text.trim().isEmpty ||
                                  expDateController.text.trim().isEmpty ||
                                  cvcController.text.trim().isEmpty) {
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

    if (confirmed != true) {
      nameController.dispose();
      addressController.dispose();
      cityController.dispose();
      stateController.dispose();
      zipController.dispose();
      cardNameController.dispose();
      cardNumberController.dispose();
      expDateController.dispose();
      cvcController.dispose();
      return;
    }

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
      final insertedOrder = await supabase
          .from('orders')
          .insert({
            'buyer_id': user.id,
            'total_price': offer.offerPrice,
            'shipping_address': address,
            'payment_method': paymentMethod,
            'customer_name': fullName,
            'city': city,
            'state': state,
            'zipcode': zipCode,
            'shipping_same_as_billing': useSameAddress,
            'card_holder_name': cardHolderName,
            'card_last4': cardLast4.isNotEmpty ? cardLast4 : null,
            'card_expiry': cardExpiry.isNotEmpty ? cardExpiry : null,
          })
          .select('id')
          .single();

      final orderId = insertedOrder['id'] as int;

      await supabase.from('order_items').insert({
        'order_id': orderId,
        'product_id': offer.productId,
        'seller_id': offer.sellerId,
        'price': offer.offerPrice,
        'quantity': 1,
      });

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Offers',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
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

    if (_offers.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 500,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No offers yet',
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Browse Products'),
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
      itemCount: _offers.length,
      itemBuilder: (context, index) {
        final offer = _offers[index];
        final canCheckout = offer.status == 'accepted';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: offer.productImage != null && offer.productImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(offer.productImage!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.productTitle,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(offer.offerPrice),
                          style: GoogleFonts.poppins(
                            color: primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${offer.status.toUpperCase()}',
                          style: GoogleFonts.inter(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canCheckout) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCheckingOut
                        ? null
                        : () => _checkoutAcceptedOffer(offer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _isCheckingOut ? 'PROCESSING...' : 'CHECKOUT',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
