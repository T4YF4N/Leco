import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final DatabaseReference _issueProductDatabase = FirebaseDatabase.instance.reference().child('issueproducts');
  final DatabaseReference _constructionsDatabase = FirebaseDatabase.instance.reference().child('constructions');
  final DatabaseReference _productsDatabase = FirebaseDatabase.instance.reference().child('products');
  List<String> _constructionSites = [];
  String? _selectedConstructionSite;
  int _totalProductsIssued = 0;
  Map<String, int> _productsIssued = {};
  Map<String, Map<String, dynamic>> _productDetails = {};
  bool _showFullList = false;

  @override
  void initState() {
    super.initState();
    _fetchConstructionSites();
    _fetchProductDetails();
  }

  Future<void> _fetchConstructionSites() async {
    final event = await _constructionsDatabase.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
    setState(() {
      _constructionSites = data.values.map((value) => value['name'].toString()).toList();
    });
  }

  Future<void> _fetchProductDetails() async {
    final event = await _productsDatabase.once();
    final data = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
    setState(() {
      data.forEach((key, value) {
        _productDetails[key] = Map<String, dynamic>.from(value);
      });
    });
  }

  Future<void> _fetchStatistics(String constructionSite) async {
    try {
      final event = await _issueProductDatabase.orderByChild('constructionSite').equalTo(constructionSite).once();
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      int totalIssued = 0;
      Map<String, int> productsIssued = {};

      if (data != null) {
        data.forEach((key, value) {
          final entry = value as Map<dynamic, dynamic>;
          final products = entry['products'] as List<dynamic>;

          products.forEach((product) {
            final quantity = product['quantity'] as num;
            final productId = product['productId'] as String;
            if (productsIssued.containsKey(productId)) {
              productsIssued[productId] = productsIssued[productId]! + quantity.toInt();
            } else {
              productsIssued[productId] = quantity.toInt();
            }
            totalIssued += quantity.toInt();
          });
        });
      }

      setState(() {
        _totalProductsIssued = totalIssued;
        _productsIssued = productsIssued;
        _showFullList = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching statistics: $e')),
      );
      print('Error fetching statistics: $e');
    }
  }

  void _showProductListPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Podsumowanie dla budowy $_selectedConstructionSite'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: _productsIssued.length,
              itemBuilder: (context, index) {
                final productId = _productsIssued.keys.elementAt(index);
                final quantity = _productsIssued[productId]!;
                final productDetail = _productDetails[productId] ?? {};
                final brand = productDetail['company'] ?? 'Unknown';
                final symbol = productDetail['symbol'] ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('$brand - $symbol: $quantity'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Zamknij'),
            ),
            TextButton(
              onPressed: () {
                _copyProductListToClipboard();
              },
              child: Text('Kopiuj'),
            ),
          ],
        );
      },
    );
  }

  void _copyProductListToClipboard() {
    String productList = _productsIssued.entries.map((entry) {
      final productId = entry.key;
      final quantity = entry.value;
      final productDetail = _productDetails[productId] ?? {};
      final brand = productDetail['company'] ?? 'Unknown';
      final symbol = productDetail['symbol'] ?? 'Unknown';
      return '$brand - $symbol: $quantity';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: productList)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lista produktów została skopiowana do schowka')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedConstructionSite,
                  hint: Text('Wybierz budowę'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedConstructionSite = newValue;
                      if (newValue != null) {
                        _fetchStatistics(newValue);
                      }
                    });
                  },
                  items: _constructionSites.map((site) {
                    return DropdownMenuItem(
                      value: site,
                      child: Text(site),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            _selectedConstructionSite == null
                ? Center(child: Text('Proszę wybrać budowę, aby wyświetlić statystyki'))
                : _productsIssued.isEmpty && _totalProductsIssued == 0
                ? Center(child: CircularProgressIndicator())
                : Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      'Łączna liczba wydanych produktów dla budowy $_selectedConstructionSite: $_totalProductsIssued',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _productsIssued.length,
                      itemBuilder: (context, index) {
                        final productId = _productsIssued.keys.elementAt(index);
                        final quantity = _productsIssued[productId]!;
                        final productDetail = _productDetails[productId] ?? {};
                        final brand = productDetail['company'] ?? 'Unknown';
                        final symbol = productDetail['symbol'] ?? 'Unknown';
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
                          child: ListTile(
                            title: Text('$brand - $symbol', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Ilość: $quantity'),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      _showProductListPopup(context);
                    },
                    child: Text('Pokaż listę'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: StatisticsPage(),
  ));
}
