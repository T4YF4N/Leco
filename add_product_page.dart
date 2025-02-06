import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _symbolController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();

  String? _selectedCategory; // Initialize as null
  List<String> _categories = [];

  String _filterCategory = 'All';  // Add this field for filtering categories
  String _searchQuery = '';        // Add this field for search query

  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('products');

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _fetchCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<List<String>> _fetchCategories() async {
    final categoriesSnapshot = await FirebaseDatabase.instance.reference().child('categories').once();
    final categoriesData = categoriesSnapshot.snapshot.value as Map<dynamic, dynamic>;
    return categoriesData.values.map((category) => category['name'] as String).toList();
  }

  Future<void> _addNewProduct() async {
    if (_formKey.currentState!.validate()) {
      final company = _companyController.text.trim();
      final symbol = _symbolController.text.trim();
      final description = _descriptionController.text.trim();
      final quantity = double.parse(_quantityController.text.trim());
      final productId = '${company}_$symbol'.replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      try {
        final event = await _database.child(productId).once();
        if (event.snapshot.value != null) {
          final existingData = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
          _showUpdateDialog(existingData, productId);
        } else {
          await _database.child(productId).set({
            'company': company,
            'symbol': symbol,
            'description': description,
            'quantity': quantity,
            'category': _selectedCategory,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produkt dodany pomyślnie')),
          );
          _resetForm();
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas dodawania produktu: $error')),
        );
      }
    }
  }

  void _showUpdateDialog(Map<String, dynamic> existingData, String productId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Produkt już istnieje'),
          content: Text(
            'Firma: ${existingData['company']}\n'
                'Symbol: ${existingData['symbol']}\n'
                'Opis: ${existingData['description']}\n'
                'Kategoria: ${existingData['category']}\n'
                'Ilość: ${existingData['quantity']}\n\n'
                'Czy chcesz zaktualizować ilość produktu?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Nie'),
            ),
            TextButton(
              onPressed: () {
                final newQuantity = existingData['quantity'] + double.parse(_quantityController.text);
                _updateProductQuantity(productId, newQuantity);
                _quantityController.text = newQuantity.toString(); // Update the quantity field in the UI
                Navigator.of(context).pop();
              },
              child: Text('Tak'),
            ),
          ],
        );
      },
    );
  }

  void _updateProductQuantity(String productId, double newQuantity) {
    _database.child(productId).update({
      'quantity': newQuantity,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ilość produktu zaktualizowana pomyślnie')),
      );
      Navigator.of(context).pop(); // Close the form after updating the quantity
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wystąpił błąd podczas aktualizacji ilości produktu: $error')),
      );
    });
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _selectedCategory = null; // Reset to null
    });
  }

  Future<void> _showDeliveryDialog() async {
    final products = await _fetchProducts();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredProducts = products.where((product) {
              final matchesCategory = _filterCategory == 'All' || product['category'] == _filterCategory;
              final company = product['company'] ?? '';
              final symbol = product['symbol'] ?? '';
              final matchesQuery = company.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  symbol.toLowerCase().contains(_searchQuery.toLowerCase());
              return matchesCategory && matchesQuery;
            }).toList();

            return AlertDialog(
              title: Text('Dostawa - Wybierz produkt'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Wyszukaj',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: MediaQuery.of(context).size.width, // Pełna szerokość ekranu
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black), // Czarna obwódka
                        borderRadius: BorderRadius.circular(5), // Zaokrąglenie rogów, opcjonalnie
                      ),
                      child: DropdownButton<String>(
                        value: _filterCategory,
                        isExpanded: true, // Rozszerzenie DropdownButton na pełną szerokość
                        items: [
                          DropdownMenuItem(value: 'All', child: Text('Wybierz kategorię produktu')),
                          ..._categories.map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterCategory = value!;
                          });
                        },
                        underline: SizedBox(), // Usunięcie domyślnej linii podkreślenia
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],
                            ),
                            child: ListTile(
                              title: Text(
                                '${product['company']} - ${product['symbol']}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Ilość: ${product['quantity']}'),
                              onTap: () {
                                _showUpdateQuantityDialog(product);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Zamknij'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final event = await _database.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
    return data.entries.map((entry) {
      final product = Map<String, dynamic>.from(entry.value);
      product['productId'] = entry.key;
      return product;
    }).toList();
  }

  void _showUpdateQuantityDialog(Map<String, dynamic> product) {
    final _newQuantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Dodaj ilość dostawy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Firma: ${product['company']}'),
              Text('Symbol: ${product['symbol']}'),
              Text('Obecna ilość: ${product['quantity']}'),
              TextFormField(
                controller: _newQuantityController,
                decoration: InputDecoration(
                  labelText: 'Dodaj ilość dostawy',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Anuluj'),
            ),
            TextButton(
              onPressed: () {
                final deliveryQuantity = double.tryParse(_newQuantityController.text) ?? 0.0;
                final newQuantity = product['quantity'] + deliveryQuantity;
                _updateProductQuantity(product['productId'], newQuantity);
                Navigator.of(context).pop();
              },
              child: Text('Dodaj'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _symbolController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dodaj produkty do magazynu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Kategoria',
                      border: OutlineInputBorder(),
                    ),
                    hint: Text('Wybierz kategorię'), // Displayed when no category is selected
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                    items: _categories.map<DropdownMenuItem<String>>((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Proszę wybrać kategorię';
                      }
                      return null;
                    },
                  ),
                if (_categories.isEmpty) CircularProgressIndicator(),
                SizedBox(height: 16.0),
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: 'Firma',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać firmę';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                TextFormField(
                  controller: _symbolController,
                  decoration: InputDecoration(
                    labelText: 'Symbol produktu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać symbol produktu';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Opis',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać opis';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Ilość',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać ilość';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Proszę podać prawidłową ilość';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _addNewProduct,
                  child: Text('Dodaj produkt'),
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _showDeliveryDialog,
                  child: Text('Dostawa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
