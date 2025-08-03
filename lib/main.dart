import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'ui/screens/add_product_screen.dart';
import 'ui/screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Toko Gadget',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.tealAccent,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ProductListPage(),
        '/login': (context) => const LoginPage(),
        '/cart': (context) => const CartPage(),
      },
    );
  }
}

// --- Halaman Utama (Beranda) ---
class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  Widget _buildSectionHeader(String title, VoidCallback? onSeeMore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (onSeeMore != null) TextButton(onPressed: onSeeMore, child: const Text('Lihat Semua')),
        ],
      ),
    );
  }

  Widget _buildMostSellList() {
    return SizedBox(
      height: 255,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('soldCount', descending: true).limit(5).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada produk.'));
          
          var products = snapshot.data!.docs;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              var productData = products[index].data() as Map<String, dynamic>;
              String productId = products[index].id;
              return SizedBox(
                width: 160,
                child: ProductCard(product: productData, productId: productId),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 100,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

          var categories = snapshot.data!.docs;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              var category = categories[index].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(category['iconUrl']),
                      backgroundColor: Colors.grey[800],
                    ),
                    const SizedBox(height: 8),
                    Text(category['name']),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAllProductsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada produk.'));
        
        var products = snapshot.data!.docs;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            var productData = products[index].data() as Map<String, dynamic>;
            String productId = products[index].id;
            return ProductCard(product: productData, productId: productId);
          },
        );
      },
    );
  }

  Future<void> _checkRoleAndNavigate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!context.mounted) return;
      final role = doc.data()?['role'];
      if (role == 'admin') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat data user: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toko Gadget'),
        actions: [
          IconButton(
            tooltip: 'Keranjang Belanja',
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
               if (FirebaseAuth.instance.currentUser != null) {
                Navigator.pushNamed(context, '/cart');
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda harus login untuk melihat keranjang!')));
                 Navigator.pushNamed(context, '/login');
               }
            },
          ),
          IconButton(
            tooltip: 'Login atau Cek Profil',
            icon: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                return Icon(snapshot.hasData ? Icons.person : Icons.login);
              },
            ),
            onPressed: () {
              if (FirebaseAuth.instance.currentUser != null) {
                _checkRoleAndNavigate(context);
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Paling Laris 🔥', () {}),
            _buildMostSellList(),
            _buildSectionHeader('Kategori', () {}),
            _buildCategoryList(),
            _buildSectionHeader('Semua Produk', null),
            _buildAllProductsGrid(),
          ],
        ),
      ),
    );
  }
}

// --- Widget Kartu Produk ---
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String productId;
  const ProductCard({super.key, required this.product, required this.productId});

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final price = priceFormat.format(product['price']);
    final soldCount = product['soldCount'] ?? 0;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(productId: productId))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                product['imageUrl'],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(price, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('$soldCount terjual', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Halaman Detail Produk (VERSI LEBIH AMAN) ---
// --- Halaman Detail Produk (VERSI FINAL & LENGKAP) ---
class ProductDetailPage extends StatelessWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  // Fungsi untuk menampilkan dialog tambah ke keranjang
  void _showAddToCartDialog(BuildContext context, Map<String, dynamic> product) {
    int quantity = 1;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Masukkan ke Keranjang'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product['name'] ?? 'Nama Produk', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) {
                            setDialogState(() => quantity--);
                          }
                        },
                      ),
                      Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                           if (quantity < (product['stock'] ?? 0)) {
                             setDialogState(() => quantity++);
                           } else {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak mencukupi!'), duration: Duration(seconds: 1)));
                           }
                        },
                      ),
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    await _addToCart(context, product, quantity);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fungsi untuk menyimpan ke Firestore
  Future<void> _addToCart(BuildContext context, Map<String, dynamic> product, int quantity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart').doc(productId);
    
    await cartRef.set({
      'productId': productId,
      'name': product['name'],
      'price': product['price'],
      'imageUrl': product['imageUrl'],
      'quantity': quantity,
    }, SetOptions(merge: true));

    if(!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil ditambahkan ke keranjang!'), duration: Duration(seconds: 2),));
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Produk tidak ditemukan.'));
          }
          
          var product = snapshot.data!.data() as Map<String, dynamic>;
          
          final productName = product['name'] ?? 'Nama Produk Tidak Tersedia';
          final productPrice = product['price'] ?? 0;
          final productStock = product['stock'] ?? 0;
          final productSoldCount = product['soldCount'] ?? 0;
          final productDesc = product['description'] ?? 'Tidak ada deskripsi.';
          final productImageUrl = product['imageUrl'] ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(productName, style: const TextStyle(fontSize: 16, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                  background: productImageUrl.isNotEmpty
                      ? Image.network(
                          productImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 100)),
                        )
                      : const Center(child: Icon(Icons.image_not_supported, size: 100)),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(priceFormat.format(productPrice), style: TextStyle(fontSize: 28, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(productName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Stok: $productStock'),
                            const SizedBox(width: 16),
                            const Text('|'),
                            const SizedBox(width: 16),
                            Text('$productSoldCount terjual'),
                          ],
                        ),
                        const Divider(height: 32),
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.store)),
                            title: const Text('Gadget Store Official'),
                            subtitle: const Text('Tangerang'),
                            trailing: OutlinedButton(onPressed: (){}, child: const Text('Kunjungi Toko')),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Deskripsi Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(productDesc, style: const TextStyle(fontSize: 16, height: 1.5)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  )
                ]),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox(height: 50);
              }
              var product = snapshot.data!.data() as Map<String, dynamic>;

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Keranjang'),
                      onPressed: () {
                         if (FirebaseAuth.instance.currentUser != null) {
                           _showAddToCartDialog(context, product);
                         } else {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda harus login untuk menambah barang!')));
                           Navigator.pushNamed(context, '/login');
                         }
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { /* TODO: Logika Beli Sekarang */ },
                      child: const Text('Beli Sekarang'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  )
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
// --- Halaman Keranjang Belanja ---
class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Silakan login.')));
    }
    
    final cartStream = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('cart').snapshots();
    final priceFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Saya'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Keranjang Anda masih kosong.'));
          }

          var cartItems = snapshot.data!.docs;
          
          double totalPrice = 0;
          for(var item in cartItems){
            var data = item.data() as Map<String, dynamic>;
            totalPrice += (data['price'] ?? 0) * (data['quantity'] ?? 0);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    var item = cartItems[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover),
                      title: Text(item['name']),
                      subtitle: Text('${item['quantity']} x ${priceFormat.format(item['price'])}'),
                      trailing: Text(priceFormat.format(item['price'] * item['quantity'])),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ${priceFormat.format(totalPrice)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: () { /* TODO: Proses Checkout */ },
                      child: const Text('Checkout'),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}


// --- Halaman Login & Registrasi ---
class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginPage({super.key, this.onLoginSuccess});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoginMode = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<Widget> _buildForm() {
    if (_isLoginMode) {
      return [
        const Text('Selamat Datang Kembali!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _login, child: const Text('Login')),
        TextButton(onPressed: () => setState(() => _isLoginMode = false), child: const Text('Belum punya akun? Daftar di sini')),
      ];
    } else {
      return [
        const Text('Buat Akun Baru', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _register, child: const Text('Daftar')),
        TextButton(onPressed: () => setState(() => _isLoginMode = true), child: const Text('Sudah punya akun? Login')),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoginMode ? 'Login' : 'Daftar')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/img/logo.png', height: 100, errorBuilder: (context, error, stackTrace) => const Icon(Icons.shopping_cart, size: 100)),
              const SizedBox(height: 30),
              ..._buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
          return;
        }
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        if (!mounted) return;
        if (doc.exists) {
          final role = doc.data()?['role'];
          if (role == 'admin') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data user tidak ditemukan. Silakan daftar ulang.')));
          await FirebaseAuth.instance.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    if (email.isEmpty || password.isEmpty || name.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': name, 'email': email, 'role': 'user', 'createdAt': Timestamp.now(),
        });
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// --- Halaman Pengguna (Setelah Login) ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () {
          FirebaseAuth.instance.signOut();
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ProductListPage()), (route) => false);
        }),
      ]),
      body: Center(child: Text('Selamat Datang, User!\nAnda login sebagai:\n${user?.email}')),
    );
  }
}

// --- Dashboard Admin ---
