import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Import untuk cek platform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController(); // Controller untuk kategori

  XFile? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile;
    });
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate() && _imageFile != null) {
      setState(() => _isLoading = true);
      
      try {
        // 1. Upload gambar ke Firebase Storage
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child('product_images').child('$fileName.jpg');
        
        // Logika upload yang berbeda untuk web dan mobile
        if (kIsWeb) {
  await ref.putData(await _imageFile!.readAsBytes());
} else {
  // --- TAMBAHKAN 2 BARIS INI UNTUK DEBUGGING ---
  final file = File(_imageFile!.path);
  print('Mencoba upload file dari path: ${file.path}');
  print('Apakah file ada di path tersebut? ${await file.exists()}');
  // --------------------------------------------

  await ref.putFile(file); // Pastikan menggunakan variabel 'file'
}
        
        final imageUrl = await ref.getDownloadURL();

        // 2. Simpan data produk ke Firestore
        await FirebaseFirestore.instance.collection('products').add({
          'name': _nameController.text,
          'price': int.tryParse(_priceController.text) ?? 0,
          'description': _descController.text,
          'stock': int.tryParse(_stockController.text) ?? 0,
          'soldCount': 0, // Inisialisasi terjual
          'category': _categoryController.text,
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil disimpan!')));
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan produk: $e')));
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua field dan pilih gambar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Produk Baru')),
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
              TextFormField(controller: _stockController, decoration: const InputDecoration(labelText: 'Stok Awal'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Kategori (contoh: Handphone)'), validator: (v) => v!.isEmpty ? 'Tidak boleh kosong' : null),
              const SizedBox(height: 20),
              
              Container(
                height: 150,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: _imageFile == null
                    ? const Center(child: Text('Belum ada gambar dipilih.'))
                    // ## PERBAIKAN DI SINI ##
                    // Tampilkan gambar sesuai platform
                    : kIsWeb 
                      ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                      : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
              ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pilih Gambar'),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveProduct,
                      child: const Text('Simpan Produk'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}