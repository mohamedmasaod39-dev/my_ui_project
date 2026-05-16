import 'package:shared_preferences/shared_preferences.dart';

class CheckoutInfo {
  const CheckoutInfo({
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.company = '',
    this.address = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.paymentMethod = 'Card',
    this.cardHolderName = '',
    this.cardLast4 = '',
    this.cardExpiry = '',
  });

  final String fullName;
  final String phoneNumber;
  final String email;
  final String company;
  final String address;
  final String addressLine2;
  final String city;
  final String state;
  final String zipCode;
  final String paymentMethod;
  final String cardHolderName;
  final String cardLast4;
  final String cardExpiry;

  bool get hasSavedCard => cardLast4.trim().isNotEmpty;
}

class CheckoutInfoService {
  CheckoutInfoService._();

  static final CheckoutInfoService instance = CheckoutInfoService._();

  String _key(String userId, String field) => 'checkout_info.$userId.$field';

  Future<CheckoutInfo> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    String value(String field, [String fallback = '']) =>
        prefs.getString(_key(userId, field)) ?? fallback;

    return CheckoutInfo(
      fullName: value('full_name'),
      phoneNumber: value('phone_number'),
      email: value('email'),
      company: value('company'),
      address: value('address'),
      addressLine2: value('address_line2'),
      city: value('city'),
      state: value('state'),
      zipCode: value('zip_code'),
      paymentMethod: value('payment_method', 'Card'),
      cardHolderName: value('card_holder_name'),
      cardLast4: value('card_last4'),
      cardExpiry: value('card_expiry'),
    );
  }

  Future<void> save(String userId, CheckoutInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final values = <String, String>{
      'full_name': info.fullName,
      'phone_number': info.phoneNumber,
      'email': info.email,
      'company': info.company,
      'address': info.address,
      'address_line2': info.addressLine2,
      'city': info.city,
      'state': info.state,
      'zip_code': info.zipCode,
      'payment_method': info.paymentMethod,
      'card_holder_name': info.cardHolderName,
      'card_last4': info.cardLast4,
      'card_expiry': info.cardExpiry,
    };

    for (final entry in values.entries) {
      await prefs.setString(_key(userId, entry.key), entry.value.trim());
    }
  }
}
