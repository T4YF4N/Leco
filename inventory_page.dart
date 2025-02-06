import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.reference();
  List<Map<String, dynamic>> _productList = [];
  List<Map<String, dynamic>> _filteredProductList = [];
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    DatabaseEvent event = await _databaseReference.child('products').once();
    DataSnapshot snapshot = event.snapshot;
    Map<dynamic, dynamic> products = snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _productList = products.keys.map((key) {
        return {
          'id': key,
          'name': products[key]['name'] ?? '',
          'category': products[key]['category'] ?? '',
          'description': products[key]['description'] ?? '',
          'quantity': products[key]['quantity'] ?? 0,
          'company': products[key]['company'] ?? '',
          'symbol': products[key]['symbol'] ?? '',
        };
      }).toList();
      _filteredProductList = _productList;
    });
  }

  void _filterProducts() {
    setState(() {
      _filteredProductList = _productList.where((product) {
        final matchesCategory = _selectedCategory == null || product['category'] == _selectedCategory;
        final matchesSearchQuery = product['company'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product['symbol'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stan Magazynowy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                labelText: 'Szukaj wg nazwy firmy lub symbolu',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                  _filterProducts();
                });
              },
            ),
            SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Filtruj wg kategorii',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _selectedCategory,
              items: _productList.map((product) => product['category']).toSet().map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue;
                  _filterProducts();
                });
              },
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProductList.length,
                itemBuilder: (context, index) {
                  var product = _filteredProductList[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['company'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            product['symbol'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            '${product['quantity']} sztuk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8.0),
                          Text(
                            product['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
