import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Product {
  final String name;
  final String price;
  final String image;
  final String tag;

  Product({
    required this.name,
    required this.price,
    required this.image,
    required this.tag,
  });
}

// THE BEAST LIST
final List<Product> products = [
  Product(
    name: "The North Coat",
    price: "EGP 2,600",
    tag: "p1",
    image: "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400",
  ),
  Product(
    name: "Gucci Duffle Bag",
    price: "EGP 5,600",
    tag: "p2",
    image: "https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400",
  ),
  Product(
    name: "RGB CPU Cooler",
    price: "EGP 1,200",
    tag: "p3",
    image: "https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=400",
  ),
  Product(
    name: "Comfort Chair",
    price: "EGP 3,750",
    tag: "p4",
    image: "https://images.unsplash.com/photo-1595514535402-da78c187b5a8?w=400",
  ),
];

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  static const Color primaryRed = Color(0xFFDB4444);
  static const Color offWhite = Color(0xFFF5F5F5);
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Listables",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            // BEAST FIX: Navigation to Wishlist Page added
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBody: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(),
            _buildSectionHeader("Categories", "Browse By Style"),
            _buildCategoryList(),
            _buildSectionHeader("Best Selling", "This Month's Top Picks"),
            _buildProductGrid(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.home_filled, 0),
          _navIcon(Icons.grid_view_rounded, 1),
          _navIcon(Icons.notifications_none, 2),
          _navIcon(Icons.person_outline, 3),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        // BEAST NAVIGATION LOGIC
        if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/search');
        } else if (index == 2) {
          // You could link this to a notification page later
        }
      },
      child: Icon(
        icon,
        color: isActive ? primaryRed : Colors.white60,
        size: 28,
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "iPhone 17 Pro",
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  Text(
                    "The Future Is Here",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                    ),
                    child: const Text(
                      "Pre-order Now",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Hero(
            tag: 'product_hero',
            child: Image.network(
              "https://images.unsplash.com/photo-1616348436168-de43ad0db179?w=300",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String tag, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                tag,
                style: GoogleFonts.inter(
                  color: primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        children: [
          _catItem(Icons.phone_iphone, "Phones"),
          _catItem(Icons.laptop_mac, "Computers"),
          _catItem(Icons.watch, "Watches"),
          _catItem(Icons.camera_alt, "Cameras"),
        ],
      ),
    );
  }

  Widget _catItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: offWhite,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.black),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/details', arguments: product),
          child: _buildModernProductCard(product),
        );
      },
    );
  }

  Widget _buildModernProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Hero(
                      tag: product.tag,
                      child: Image.network(product.image, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 15,
                    child: Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.price,
                  style: GoogleFonts.poppins(
                    color: primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
