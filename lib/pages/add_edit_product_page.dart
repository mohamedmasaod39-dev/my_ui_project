import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ui_project/theme/app_theme_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'index_page.dart';

class AddEditProductPage extends StatefulWidget {
  const AddEditProductPage({super.key});

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  static const Color primaryRed = Color(0xFFDB4444);

  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  final _stockQtyController = TextEditingController(text: '1');

  // ── Detail fields (matching website) ──
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _conditionController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _platformController = TextEditingController();
  final _genreController = TextEditingController();
  final _ageRatingController = TextEditingController();
  final _materialController = TextEditingController();
  final _colorController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _roomTypeController = TextEditingController();
  final _assemblyController = TextEditingController();
  final _sizeController = TextEditingController();
  final _sportController = TextEditingController();
  final _useTypeController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingCategories = true;
  Product? _editingProduct;
  int? _selectedCategoryId;
  String? _selectedSubcategory;
  String? _selectedGender;
  String _status = 'active';
  List<Map<String, dynamic>> _categories = [];

  // Category name lookup for conditional field display
  String get _selectedCategoryName {
    if (_selectedCategoryId == null) return '';
    final match = _categories.firstWhere(
      (c) => c['id'] == _selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );
    return (match['name'] ?? '').toString().toLowerCase();
  }

  bool get _isGaming =>
      _selectedCategoryName.contains('gaming') ||
      _selectedCategoryName.contains('game');

  bool get _isElectronics =>
      _selectedCategoryName.contains('electronic');

  bool get _isHome =>
      _selectedCategoryName.contains('home') ||
      _selectedCategoryName.contains('furniture');

  bool get _isFashion =>
      _selectedCategoryName.contains('fashion') ||
      _selectedCategoryName.contains('clothing');

  bool get _isSports =>
      _selectedCategoryName.contains('sport');

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Product && _editingProduct == null) {
      _editingProduct = args;
      final d = args.listingDetails;
      _titleController.text = args.title;
      _descriptionController.text = args.description;
      _priceController.text = args.price.toStringAsFixed(0);
      _imageController.text = args.image ?? '';
      _stockQtyController.text = args.stockQty.toString();
      _brandController.text = d['Brand']?.toString() ?? '';
      _modelController.text = d['Model']?.toString() ?? '';
      _conditionController.text = d['Condition']?.toString() ?? '';
      _warrantyController.text = d['Warranty']?.toString() ?? '';
      _platformController.text = d['Platform']?.toString() ?? '';
      _genreController.text = d['Genre']?.toString() ?? '';
      _ageRatingController.text = d['Age Rating']?.toString() ?? '';
      _materialController.text = d['Material']?.toString() ?? '';
      _colorController.text = d['Color']?.toString() ?? '';
      _dimensionsController.text = d['Dimensions']?.toString() ?? '';
      _roomTypeController.text = d['Room Type']?.toString() ?? '';
      _assemblyController.text = d['Assembly Required']?.toString() ?? '';
      _sizeController.text = d['Size']?.toString() ?? '';
      _selectedGender = d['Gender']?.toString();
      _sportController.text = d['Sport']?.toString() ?? '';
      _useTypeController.text = d['Use Type']?.toString() ?? '';
      _notesController.text = d['Notes']?.toString() ?? '';
      _selectedCategoryId = args.categoryId;
      _selectedSubcategory = d['subcategory']?.toString();
      _status = args.status.isEmpty ? 'active' : args.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _stockQtyController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _conditionController.dispose();
    _warrantyController.dispose();
    _platformController.dispose();
    _genreController.dispose();
    _ageRatingController.dispose();
    _materialController.dispose();
    _colorController.dispose();
    _dimensionsController.dispose();
    _roomTypeController.dispose();
    _assemblyController.dispose();
    _sizeController.dispose();
    _sportController.dispose();
    _useTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('id, name')
          .order('created_at');

      if (!mounted) return;
      setState(() {
        _categories = (response as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final imageUrl = _imageController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stockQty = int.tryParse(_stockQtyController.text.trim());

    if (title.isEmpty ||
        description.isEmpty ||
        imageUrl.isEmpty ||
        price == null ||
        stockQty == null ||
        stockQty < 0 ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final effectiveStatus = stockQty == 0
          ? 'sold'
          : (_status == 'sold' ? 'active' : _status);

      // Build listing_details — only include non-empty values
      final listingDetails = <String, dynamic>{};
      void addDetail(String key, String val) {
        if (val.trim().isNotEmpty) listingDetails[key] = val.trim();
      }

      addDetail('Brand', _brandController.text);
      addDetail('Model', _modelController.text);
      addDetail('Condition', _conditionController.text);
      addDetail('Warranty', _warrantyController.text);
      addDetail('Platform', _platformController.text);
      addDetail('Genre', _genreController.text);
      addDetail('Age Rating', _ageRatingController.text);
      addDetail('Material', _materialController.text);
      addDetail('Color', _colorController.text);
      addDetail('Dimensions', _dimensionsController.text);
      addDetail('Room Type', _roomTypeController.text);
      addDetail('Assembly Required', _assemblyController.text);
      addDetail('Size', _sizeController.text);
      addDetail('Sport', _sportController.text);
      addDetail('Use Type', _useTypeController.text);
      addDetail('Notes', _notesController.text);
      if ((_selectedGender ?? '').isNotEmpty) {
        listingDetails['Gender'] = _selectedGender!;
      }
      if ((_selectedSubcategory ?? '').isNotEmpty) {
        listingDetails['subcategory'] = _selectedSubcategory!;
      }

      // ── Website Compatibility: Append additional details to description ──
      String effectiveDescription = description;
      if (listingDetails.isNotEmpty) {
        final extrasText = "\n\n— Additional details —\n" + 
            listingDetails.entries
                .where((e) => e.key != 'subcategory')
                .map((e) => "${e.key}: ${e.value}")
                .join("\n");
        effectiveDescription = description + extrasText;
      }

      final slug = _slugify(title, user.id);
      final isActive = effectiveStatus == 'active';
      final priceMinor = (price * 100).round();

      final payload = {
        'seller_id': user.id,
        'category_id': _selectedCategoryId,
        'title': title,
        'name': title, // Website parity
        'description': effectiveDescription,
        'price': price,
        'price_minor': priceMinor, // Website parity
        'main_image_url': imageUrl,
        'image_url': imageUrl, // Website parity
        'stock_qty': stockQty,
        'status': effectiveStatus,
        'active': isActive, // Website parity
        'listing_details': listingDetails,
        'slug': slug,
        'validated': _editingProduct != null ? _editingProduct!.validated : false,
        'category': _selectedCategoryName, // Website parity (string)
      };

      if (_editingProduct == null) {
        await supabase.from('products').insert(payload);
      } else {
        await supabase
            .from('products')
            .update(payload)
            .eq('id', _editingProduct!.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingProduct == null
                ? 'Product added successfully'
                : 'Product updated successfully',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _editingProduct != null;
    final textColor = AppThemeColors.textPrimary(context);

    if (_selectedCategoryId == null &&
        _categories.isNotEmpty &&
        _editingProduct == null) {
      _selectedCategoryId = _categories.first['id'] as int;
    }

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
          isEdit ? 'Edit Product' : 'Add Product',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Core fields ──
                  _sectionLabel('Basic Info'),
                  const SizedBox(height: 10),
                  _input('Product Title *', _titleController),
                  const SizedBox(height: 14),
                  _input('Description *', _descriptionController, maxLines: 4),
                  const SizedBox(height: 14),
                  _input('Price (EGP) *', _priceController,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  _input('Image URL *', _imageController),
                  const SizedBox(height: 14),
                  _input('Stock Quantity *', _stockQtyController,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 14),

                  // ── Category ──
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: _dropdownDecoration('Category *'),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<int>(
                            value: category['id'] as int,
                            child: Text(category['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        if (_selectedCategoryId != value) {
                          _selectedSubcategory = null;
                          _selectedGender = null;
                        }
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Fashion subcategory
                  if (_isFashion) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSubcategory,
                      decoration: _dropdownDecoration('Subcategory (optional)'),
                      items: const [
                        DropdownMenuItem(value: 'Men', child: Text('Men')),
                        DropdownMenuItem(value: 'Women', child: Text('Women')),
                        DropdownMenuItem(value: 'Kids', child: Text('Kids')),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSubcategory = value),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── General details ──
                  _sectionLabel('Product Details'),
                  const SizedBox(height: 10),
                  _input('Brand (optional)', _brandController),
                  const SizedBox(height: 14),
                  _input('Model (optional)', _modelController),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _conditionController.text.isEmpty ? null : _conditionController.text,
                    decoration: _dropdownDecoration('Condition (optional)'),
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(value: 'Like New', child: Text('Like New')),
                      DropdownMenuItem(value: 'Good', child: Text('Good')),
                      DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                    ],
                    onChanged: (val) => setState(() => _conditionController.text = val ?? ''),
                  ),
                  const SizedBox(height: 14),
                  _input('Warranty (optional)', _warrantyController),
                  const SizedBox(height: 14),
                  _input('Color (optional)', _colorController),
                  const SizedBox(height: 14),
                  _input('Size (optional)', _sizeController),
                  const SizedBox(height: 14),

                  // ── Gaming fields ──
                  if (_isGaming) ...[
                    _sectionLabel('Gaming Details'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _platformController.text.isEmpty ? null : _platformController.text,
                      decoration: _dropdownDecoration('Platform (optional)'),
                      items: const [
                        DropdownMenuItem(value: 'PC', child: Text('PC')),
                        DropdownMenuItem(value: 'PlayStation', child: Text('PlayStation')),
                        DropdownMenuItem(value: 'Xbox', child: Text('Xbox')),
                        DropdownMenuItem(value: 'Nintendo Switch', child: Text('Nintendo Switch')),
                        DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                        DropdownMenuItem(value: 'Multi-platform', child: Text('Multi-platform')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _platformController.text = val ?? ''),
                    ),
                    const SizedBox(height: 14),
                    _input('Genre (e.g. Action, RPG)', _genreController),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _ageRatingController.text.isEmpty ? null : _ageRatingController.text,
                      decoration: _dropdownDecoration('Age Rating (optional)'),
                      items: const [
                        DropdownMenuItem(value: 'E', child: Text('Everyone')),
                        DropdownMenuItem(value: 'T', child: Text('Teen (13+)')),
                        DropdownMenuItem(value: 'M', child: Text('Mature (17+)')),
                        DropdownMenuItem(value: 'AO', child: Text('Adults Only')),
                      ],
                      onChanged: (val) => setState(() => _ageRatingController.text = val ?? ''),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Electronics fields ──
                  if (_isElectronics) ...[
                    _sectionLabel('Electronics Details'),
                    const SizedBox(height: 10),
                    _input('Dimensions (optional)', _dimensionsController),
                    const SizedBox(height: 14),
                  ],

                  // ── Home / Furniture fields ──
                  if (_isHome) ...[
                    _sectionLabel('Home & Furniture Details'),
                    const SizedBox(height: 10),
                    _input('Material (e.g. Wood, Metal)', _materialController),
                    const SizedBox(height: 14),
                    _input('Dimensions (e.g. 120×60×75 cm)', _dimensionsController),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _roomTypeController.text.isEmpty ? null : _roomTypeController.text,
                      decoration: _dropdownDecoration('Room Type (optional)'),
                      items: const [
                        DropdownMenuItem(value: 'Living Room', child: Text('Living Room')),
                        DropdownMenuItem(value: 'Bedroom', child: Text('Bedroom')),
                        DropdownMenuItem(value: 'Kitchen', child: Text('Kitchen')),
                        DropdownMenuItem(value: 'Bathroom', child: Text('Bathroom')),
                        DropdownMenuItem(value: 'Office', child: Text('Office')),
                        DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _roomTypeController.text = val ?? ''),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _assemblyController.text.isEmpty ? null : _assemblyController.text,
                      decoration: _dropdownDecoration('Assembly Required?'),
                      items: const [
                        DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                        DropdownMenuItem(value: 'No', child: Text('No')),
                      ],
                      onChanged: (val) => setState(() => _assemblyController.text = val ?? ''),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Fashion fields ──
                  if (_isFashion) ...[
                    _sectionLabel('Fashion Details'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: _dropdownDecoration('Gender (optional)'),
                      items: const [
                        DropdownMenuItem(value: 'Men', child: Text('Men')),
                        DropdownMenuItem(value: 'Women', child: Text('Women')),
                        DropdownMenuItem(value: 'Kids', child: Text('Kids')),
                        DropdownMenuItem(value: 'Unisex', child: Text('Unisex')),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 14),
                    _input('Material (optional)', _materialController),
                    const SizedBox(height: 14),
                  ],

                  // ── Sports fields ──
                  if (_isSports) ...[
                    _sectionLabel('Sports Details'),
                    const SizedBox(height: 10),
                    _input('Sport (e.g. Football, Tennis)', _sportController),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _useTypeController.text.isEmpty ? null : _useTypeController.text,
                      decoration: _dropdownDecoration('Indoor / Outdoor Use'),
                      items: const [
                        DropdownMenuItem(value: 'Indoor', child: Text('Indoor')),
                        DropdownMenuItem(value: 'Outdoor', child: Text('Outdoor')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                      onChanged: (val) => setState(() => _useTypeController.text = val ?? ''),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Notes & Status ──
                  _sectionLabel('Additional Info'),
                  const SizedBox(height: 10),
                  _input('Notes (optional)', _notesController, maxLines: 3),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _dropdownDecoration('Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                      DropdownMenuItem(value: 'sold', child: Text('Sold')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEdit ? 'UPDATE PRODUCT' : 'ADD PRODUCT',
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

  String _slugify(String title, String userId) {
    final clean = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    final shortId = userId.split('-').first;
    return '$clean-$shortId';
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppThemeColors.textSecondary(context),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: AppThemeColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppThemeColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppThemeColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
