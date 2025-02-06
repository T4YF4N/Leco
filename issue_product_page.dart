import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class IssueProductPage extends StatefulWidget {
  @override
  _IssueProductPageState createState() => _IssueProductPageState();
}

class _IssueProductPageState extends State<IssueProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _constructionSiteController = TextEditingController();
  final _receivingPersonController = TextEditingController();

  String? _selectedConstructionSite;
  String? _selectedReceivingPerson;
  final List<Map<String, dynamic>?> _selectedProducts = [];

  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('products');
  final DatabaseReference _issueProductDatabase = FirebaseDatabase.instance.reference().child('issueproducts');
  final DatabaseReference _constructionsDatabase = FirebaseDatabase.instance.reference().child('constructions');
  final DatabaseReference _employeesDatabase = FirebaseDatabase.instance.reference().child('employees');

  List<String> _constructionSites = [];
  List<String> _employees = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, List<Map<String, dynamic>>> _productsByCategory = {};

  Set<String> _selectedProductIds = {};

  String? _filterEmployee;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _selectedProducts.add(null); // Start with one product selection field
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchProducts(), _fetchConstructionSites(), _fetchEmployees()]);
  }

  Future<void> _fetchProducts() async {
    final event = await _database.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
    setState(() {
      _products = data.entries.map((entry) {
        final product = Map<String, dynamic>.from(entry.value);
        product['productId'] = entry.key;
        product['quantity'] = (product['quantity'] is int)
            ? (product['quantity'] as int).toDouble()
            : (product['quantity'] ?? 0.0);
        return product;
      }).toList();
      _groupProductsByCategory();
    });
  }

  Future<void> _fetchConstructionSites() async {
    final event = await _constructionsDatabase.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
    setState(() {
      _constructionSites = data.values.map((value) => value['name'].toString()).toList();
    });
  }

  Future<void> _fetchEmployees() async {
    final event = await _employeesDatabase.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
    setState(() {
      _employees = data.values.map((value) => value['name'].toString()).toList();
    });
  }

  void _groupProductsByCategory() {
    _productsByCategory.clear();
    for (var product in _products) {
      final category = product['category'] ?? 'Uncategorized';
      if (!_productsByCategory.containsKey(category)) {
        _productsByCategory[category] = [];
      }
      _productsByCategory[category]!.add(product);
    }
  }

  Future<void> _issueProduct() async {
    if (_formKey.currentState!.validate()) {
      final currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      for (var product in _selectedProducts) {
        if (product != null) {
          final productId = product['productId'];
          final issuedQuantity = product['quantity'] as double;

          final event = await _database.child(productId).once();
          final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
          final availableQuantity = (data['quantity'] is int)
              ? (data['quantity'] as int).toDouble()
              : (data['quantity'] ?? 0.0);

          if (issuedQuantity <= availableQuantity) {
            await _database.child(productId).update({
              'quantity': availableQuantity - issuedQuantity,
            });
          }
        }
      }

      List<Map<String, dynamic>> issuedProducts = _selectedProducts.where((product) => product != null).map((product) => {
        'productId': product!['productId'],
        'quantity': product['quantity'],
      }).toList();

      final issueData = {
        'constructionSite': _selectedConstructionSite,
        'receivingPerson': _selectedReceivingPerson,
        'products': issuedProducts,
        'date': currentDate,
      };

      await _issueProductDatabase.push().set(issueData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt wydany pomyślnie')),
      );

      _resetForm();
      _fetchProducts(); // Refresh product data
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _selectedConstructionSite = null;
      _selectedReceivingPerson = null;
      _selectedProducts.clear();
      _selectedProductIds.clear();
      _constructionSiteController.clear();
    });
  }

  Future<void> _selectProduct(int index) async {
    String? selectedCategory = await _showCategoryDialog();
    if (selectedCategory == null) return;

    Map<String, dynamic>? selectedProduct = await _showProductDialog(selectedCategory);
    if (selectedProduct == null || _selectedProductIds.contains(selectedProduct['productId'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produkt już został wybrany')),
      );
      return;
    }

    double? quantity = await _showQuantityDialog(selectedProduct['quantity'] ?? 0.0);
    if (quantity == null) return;

    setState(() {
      _selectedProducts[index] = {...selectedProduct, 'quantity': quantity};
      _selectedProductIds.add(selectedProduct['productId']);
    });
  }

  Future<String?> _showCategoryDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Wybierz kategorię'),
          content: SingleChildScrollView(
            child: Column(
              children: _productsByCategory.keys.map((category) {
                return ListTile(
                  title: Text(category),
                  onTap: () {
                    Navigator.of(context).pop(category);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showProductDialog(String category) {
    final products = _productsByCategory[category]!..sort((a, b) => a['symbol'].compareTo(b['symbol']));
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Wybierz produkt'),
          content: SingleChildScrollView(
            child: Column(
              children: products.map((product) {
                return ListTile(
                  title: Text('${product['company']} - ${product['symbol']}'),
                  onTap: () {
                    Navigator.of(context).pop(product);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<double?> _showQuantityDialog(double availableQuantity) {
    final _quantityController = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Podaj ilość'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dostępna ilość: $availableQuantity'),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Ilość',
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
                final quantity = double.tryParse(_quantityController.text);
                if (quantity != null && quantity > 0 && quantity <= availableQuantity) {
                  Navigator.of(context).pop(quantity);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Proszę podać prawidłową ilość')),
                  );
                }
              },
              child: Text('Potwierdź'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReturnProductPopup() async {
    if (_selectedReceivingPerson == null || _selectedConstructionSite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proszę wybrać osobę odbierającą i budowę')),
      );
      return;
    }

    final issuedProducts = await _fetchIssuedProductsForEmployeeAndSite(_selectedReceivingPerson!, _selectedConstructionSite!);

    if (issuedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brak wydanych produktów do zwrotu')),
      );
      return;
    }

    List<Map<String, dynamic>> selectedReturnProducts = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Zwrot produktów'),
              content: SingleChildScrollView(
                child: Column(
                  children: issuedProducts.map((product) {
                    final productId = product['productId'];
                    final company = _products.firstWhere((p) => p['productId'] == productId, orElse: () => {})['company'] ?? 'Unknown';
                    final symbol = _products.firstWhere((p) => p['productId'] == productId, orElse: () => {})['symbol'] ?? 'Unknown';
                    final availableQuantity = product['quantity'];
                    final TextEditingController quantityController = TextEditingController();

                    return ListTile(
                      title: Text('$company - $symbol'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dostępna ilość: $availableQuantity'),
                          TextFormField(
                            controller: quantityController,
                            decoration: InputDecoration(
                              labelText: 'Ilość do zwrotu',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              final returnQuantity = double.tryParse(value) ?? 0;
                              if (selectedReturnProducts.any((p) => p['productId'] == productId)) {
                                selectedReturnProducts.firstWhere((p) => p['productId'] == productId)['returnQuantity'] = returnQuantity;
                              } else {
                                selectedReturnProducts.add({
                                  ...product,
                                  'returnQuantity': returnQuantity,
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
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
                    Navigator.of(context).pop();
                    _processReturnProducts(selectedReturnProducts);
                  },
                  child: Text('Zatwierdź'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchIssuedProductsForEmployeeAndSite(String employee, String site) async {
    final event = await _issueProductDatabase.orderByChild('receivingPerson').equalTo(employee).once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});

    List<Map<String, dynamic>> issuedProducts = [];
    data.forEach((key, value) {
      if (value != null && value['constructionSite'] == site) {
        final products = List<Map<String, dynamic>>.from((value['products'] as List).map((product) => Map<String, dynamic>.from(product)));
        products.forEach((product) {
          product['issueKey'] = key; // Adding key to reference later
        });
        issuedProducts.addAll(products);
      }
    });

    return issuedProducts;
  }

  Future<void> _processReturnProducts(List<Map<String, dynamic>> returnProducts) async {
    for (var product in returnProducts) {
      final productId = product['productId'];
      final returnQuantity = product['returnQuantity'];
      final issueKey = product['issueKey'];

      // Update products in the main inventory
      final event = await _database.child(productId).once();
      final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
      final availableQuantity = (data['quantity'] is int)
          ? (data['quantity'] as int).toDouble()
          : (data['quantity'] ?? 0.0);

      await _database.child(productId).update({
        'quantity': availableQuantity + returnQuantity,
      });

      // Update or remove products in the issued products
      final issuedEvent = await _issueProductDatabase.child(issueKey).once();
      final issuedData = Map<String, dynamic>.from(issuedEvent.snapshot.value as Map<dynamic, dynamic>? ?? {});
      final products = List<Map<String, dynamic>>.from((issuedData['products'] as List).map((product) => Map<String, dynamic>.from(product)));
      final index = products.indexWhere((p) => p['productId'] == productId);

      if (index != -1) {
        if (products[index]['quantity'] > returnQuantity) {
          products[index]['quantity'] -= returnQuantity;
        } else {
          products.removeAt(index);
        }
        await _issueProductDatabase.child(issueKey).update({'products': products});
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Produkt zwrócony pomyślnie')),
    );

    _fetchProducts(); // Refresh product data
  }

  void _addProductSelection() {
    setState(() {
      _selectedProducts.add(null);
    });
  }

  Future<void> _showSummary() async {
    final event = await _issueProductDatabase.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>? ?? {});
    List<Map<String, dynamic>> filteredData = data.entries.map((entry) {
      final issueData = Map<String, dynamic>.from(entry.value);
      issueData['id'] = entry.key;
      return issueData;
    }).toList();

    if (_filterEmployee != null) {
      filteredData = filteredData.where((entry) {
        return entry['receivingPerson'] == _filterEmployee;
      }).toList();
    }

    if (_selectedConstructionSite != null) {
      filteredData = filteredData.where((entry) {
        return entry['constructionSite'] == _selectedConstructionSite;
      }).toList();
    }

    filteredData.sort((a, b) {
      DateTime dateA = DateFormat('yyyy-MM-dd HH:mm:ss').parse(a['date']);
      DateTime dateB = DateFormat('yyyy-MM-dd HH:mm:ss').parse(b['date']);
      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Podsumowanie wydanych produktów'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _filterEmployee,
                      decoration: InputDecoration(
                        labelText: 'Filtruj według pracownika',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _filterEmployee = newValue;
                        });
                        _showSummary();
                      },
                      items: [
                        DropdownMenuItem(value: null, child: Text('Wszyscy')),
                        ..._employees.map((employee) => DropdownMenuItem(value: employee, child: Text(employee))).toList(),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _selectedConstructionSite,
                      decoration: InputDecoration(
                        labelText: 'Filtruj według budowy',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedConstructionSite = newValue;
                        });
                        _showSummary();
                      },
                      items: [
                        DropdownMenuItem(value: null, child: Text('Wszystkie')),
                        ..._constructionSites.map((site) => DropdownMenuItem(value: site, child: Text(site))).toList(),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    ...filteredData.map((entry) {
                      final products = (entry['products'] as List<dynamic>)
                          .map((product) => Map<String, dynamic>.from(product))
                          .toList();
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
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Budowa: ${entry['constructionSite']}'),
                            Text('Data: ${entry['date']}'),
                            Text('Odbierający: ${entry['receivingPerson']}'),
                            ...products.map((product) {
                              final company = _products.firstWhere((p) => p['productId'] == product['productId'], orElse: () => {})['company'] ?? 'Unknown';
                              final symbol = _products.firstWhere((p) => p['productId'] == product['productId'], orElse: () => {})['symbol'] ?? 'Unknown';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(), // Adding a divider between products
                                  Text('Produkt: $company, $symbol'),
                                  Text('Ilość: ${product['quantity']}'),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
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

  @override
  void dispose() {
    _constructionSiteController.dispose();
    _receivingPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wydanie produktu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedConstructionSite,
                  decoration: InputDecoration(
                    labelText: 'Budowa',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedConstructionSite = newValue;
                    });
                  },
                  items: _constructionSites.map((site) => DropdownMenuItem(value: site, child: Text(site))).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę wybrać budowę';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  value: _selectedReceivingPerson,
                  decoration: InputDecoration(
                    labelText: 'Osoba odbierająca',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedReceivingPerson = newValue;
                    });
                  },
                  items: _employees.map((employee) => DropdownMenuItem(value: employee, child: Text(employee))).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę wybrać osobę odbierającą';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
                ..._selectedProducts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: product == null ? Colors.grey[0] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(5), // Zaokrąglenie krawędzi
                          border: Border.all(
                            color: Colors.black, // Kolor obramowania
                            width: 1, // Szerokość obramowania
                          ),
                        ),
                        child: ListTile(
                          title: Text(product == null
                              ? 'Kliknij aby wybrać produkt nr. ${index + 1}'
                              : '${product['company']} - ${product['symbol']} (Ilość: ${product['quantity']})'),
                          onTap: () => _selectProduct(index),
                        ),
                      ),
                      SizedBox(height: 16.0),
                    ],
                  );
                }).toList(),
                ElevatedButton(
                  onPressed: _addProductSelection,
                  child: Text('Dodaj produkt'),
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _issueProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Zielony kolor
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Wydaj produkt'),
                ),

                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _showReturnProductPopup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Czerwony kolor
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Zwróć produkt'),

                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _showSummary,
                  child: Text('Podsumowanie'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
