import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  bool _isSaving = false;
  bool _isLoadingCategories = true;
  Product? _editingProduct;
  String _condition = 'new';
  String _status = 'active';
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

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
      _titleController.text = args.title;
      _descriptionController.text = args.description;
      _priceController.text = args.price.toStringAsFixed(0);
      _imageController.text = args.image ?? '';
      _selectedCategoryId = args.categoryId;
      _condition = args.condition.isEmpty ? 'new' : args.condition;
      _status = args.status.isEmpty ? 'active' : args.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageController.dispose();
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

    if (title.isEmpty ||
        description.isEmpty ||
        imageUrl.isEmpty ||
        price == null ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = {
        'seller_id': user.id,
        'category_id': _selectedCategoryId,
        'title': title,
        'description': description,
        'price': price,
        'condition': _condition,
        'status': _status,
        'main_image_url': imageUrl,
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

    if (_selectedCategoryId == null &&
        _categories.isNotEmpty &&
        _editingProduct == null) {
      _selectedCategoryId = _categories.first['id'] as int;
    }

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
          isEdit ? 'Edit Product' : 'Add Product',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _input('Product Title', _titleController),
                  const SizedBox(height: 14),
                  _input(
                    'Description',
                    _descriptionController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  _input(
                    'Price',
                    _priceController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  _input('Image URL', _imageController),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: _dropdownDecoration('Category'),
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
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: _dropdownDecoration('Condition'),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'used', child: Text('Used')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _condition = value;
                      });
                    },
                  ),
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
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
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
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
