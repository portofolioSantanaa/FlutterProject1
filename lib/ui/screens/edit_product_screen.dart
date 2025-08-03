import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Import untuk cek platform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductScreen({super.key, required this.productId, required this.productData});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  late TextEditingController _stockController;
  late TextEditingController _categoryController;

  XFile? _imageFile;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productData['name']);
    _priceController = TextEditingController(text: widget.productData['price'].toString());
    _descController = TextEditingController(text: widget.productData['description']);
    _stockController = TextEditingController(text: widget.productData['stock'].toString());
    _categoryController = TextEditingController(text: widget.productData['category']);
    _existingImageUrl = widget.productData['imageUrl'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        String imageUrl = _existingImageUrl!;
        if (_imageFile != null) {
          final fileName = DateTime.now().millisecondsSinceEpoch.toString();
          final ref = FirebaseStorage.instance.ref().child('product_images').child('$fileName.jpg');
          if (kIsWeb) {
            await ref.putData(await _imageFile!.readAsBytes());
          } else {
            await ref.putFile(File(_imageFile!.path));
          }
          imageUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update({
          'name': _nameController.text,
          'price': int.tryParse(_priceController.text) ?? 0,
          'description': _descController.text,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'category': _categoryController.text,
          'imageUrl': imageUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil diperbarui!')));
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui produk: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Produk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Produk'), validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Harga'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 3, validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _stockController, decoration: const InputDecoration(labelText: 'Stok'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Kategori'), validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 20),
              
              Container(
                height: 150,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: _imageFile != null
                    // ## PERBAIKAN DI SINI ##
                    ? (kIsWeb ? Image.network(_imageFile!.path, fit: BoxFit.cover) : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                    : Image.network(_existingImageUrl!, fit: BoxFit.cover),
              ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Ganti Gambar'),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateProduct,
                      child: const Text('Simpan Perubahan'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}