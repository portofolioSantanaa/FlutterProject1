import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import '../../main.dart'; // Untuk mengakses ProductListPage

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
               Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ProductListPage()), (route) => false);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductScreen())),
        child: const Icon(Icons.add),
        tooltip: 'Tambah Produk',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada produk. Silakan tambahkan.'));
          }

          var products = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Memberi ruang untuk FloatingActionButton
            itemCount: products.length,
            itemBuilder: (context, index) {
              var productDoc = products[index];
              var product = productDoc.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Image.network(product['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(product['name'] ?? 'Nama Produk Tidak Ada'),
                  subtitle: Text(priceFormat.format(product['price'] ?? 0)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Edit
                      IconButton(
                        tooltip: 'Edit Produk',
                        icon: const Icon(Icons.edit, color: Colors.amber),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EditProductScreen(productId: productDoc.id, productData: product)));
                        },
                      ),
                      // Tombol Hapus
                      IconButton(
                        tooltip: 'Hapus Produk',
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          // Tampilkan dialog konfirmasi
                          showDialog(
                            context: context,
                            builder: (BuildContext ctx) {
                              return AlertDialog(
                                title: const Text('Konfirmasi Hapus'),
                                content: Text('Anda yakin ingin menghapus produk "${product['name']}"?'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Batal'),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () {
                                      // Hapus dokumen dari Firestore
                                      FirebaseFirestore.instance.collection('products').doc(productDoc.id).delete();
                                      Navigator.of(ctx).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}