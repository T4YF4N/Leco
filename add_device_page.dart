import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AddDevicePage extends StatefulWidget {
  @override
  _AddDevicePageState createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  String _selectedCategory = 'Sprzęt ręczny';
  String _selectedPowerType = '';
  String _selectedFuelType = '';

  final DatabaseReference _database = FirebaseDatabase.instance.reference().child('devices');

  String _sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
  }

  void _addDevice() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final description = _descriptionController.text;
      final category = _selectedCategory;
      final powerType = _selectedPowerType;
      final fuelType = _selectedFuelType;
      final brand = _brandController.text;
      final model = _modelController.text;

      final deviceId = _sanitizeInput('${brand}_${model}');

      _database.child(deviceId).once().then((DatabaseEvent event) {
        if (event.snapshot.exists) {
          final existingData = Map<String, dynamic>.from(event.snapshot.value as Map);
          final existingQuantity = int.parse(existingData['quantity']);
          _showUpdateDialog(existingData, deviceId, existingQuantity + 1);
        } else {
          _database.child(deviceId).set({
            'name': name,
            'description': description,
            'quantity': '1', // Assuming quantity is always 1
            'category': category,
            'powerType': powerType,
            'fuelType': fuelType,
            'brand': brand.isEmpty ? null : brand,
            'model': model.isEmpty ? null : model,
          }).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Urządzenie dodane pomyślnie')),
            );
            _formKey.currentState!.reset();
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Wystąpił błąd podczas dodawania urządzenia')),
            );
          });
        }
      });
    }
  }

  void _showUpdateDialog(Map<dynamic, dynamic> existingData, String deviceId, int newQuantity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sprzęt już istnieje'),
          content: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Nazwa: ${existingData['name']}\nOpis: ${existingData['description']}\nIlość: ${existingData['quantity']}\nKategoria: ${existingData['category']}\nTyp napędu: ${existingData['powerType']}\nRodzaj paliwa: ${existingData['fuelType']}\n\nCzy chcesz zwiększyć ilość o 1?',
              ),
            ),
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
                _updateDeviceQuantity(deviceId, newQuantity.toString());
                Navigator.of(context).pop();
              },
              child: Text('Tak'),
            ),
          ],
        );
      },
    );
  }

  void _updateDeviceQuantity(String deviceId, String newQuantity) {
    _database.child(deviceId).update({
      'quantity': newQuantity,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ilość urządzenia zaktualizowana pomyślnie')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wystąpił błąd podczas aktualizacji ilości urządzenia')),
      );
    });
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value!;
      if (_selectedCategory == 'Sprzęt ręczny') {
        _selectedPowerType = '';
        _selectedFuelType = '';
      } else {
        _selectedPowerType = 'Sprzęt spalinowy';
        _selectedFuelType = 'Benzyna';
      }
    });
  }

  void _onPowerTypeChanged(String? value) {
    setState(() {
      _selectedPowerType = value!;
      if (_selectedPowerType == 'Sprzęt elektryczny') {
        _selectedFuelType = '';
      } else if (_selectedFuelType.isEmpty) {
        _selectedFuelType = 'Benzyna';
      }
    });
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dodawanie sprzętów'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(labelText: 'Marka'),
                  // No validator needed as it's optional
                ),
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(labelText: 'Model'),
                  // No validator needed as it's optional
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Nazwa urządzenia'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać nazwę urządzenia';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Opis urządzenia'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Proszę podać opis urządzenia';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(labelText: 'Kategoria'),
                  items: [
                    DropdownMenuItem(child: Text('Sprzęt ręczny'), value: 'Sprzęt ręczny'),
                    DropdownMenuItem(child: Text('Sprzęt mechaniczny'), value: 'Sprzęt mechaniczny'),
                  ],
                  onChanged: _onCategoryChanged,
                ),
                if (_selectedCategory != 'Sprzęt ręczny')
                  DropdownButtonFormField<String>(
                    value: _selectedPowerType,
                    decoration: InputDecoration(labelText: 'Typ napędu'),
                    items: [
                      DropdownMenuItem(child: Text('Sprzęt spalinowy'), value: 'Sprzęt spalinowy'),
                      DropdownMenuItem(child: Text('Sprzęt elektryczny'), value: 'Sprzęt elektryczny'),
                    ],
                    onChanged: _onPowerTypeChanged,
                  ),
                if (_selectedCategory != 'Sprzęt ręczny' && _selectedPowerType != 'Sprzęt elektryczny')
                  DropdownButtonFormField<String>(
                    value: _selectedFuelType,
                    decoration: InputDecoration(labelText: 'Rodzaj paliwa'),
                    items: [
                      DropdownMenuItem(child: Text('Benzyna'), value: 'Benzyna'),
                      DropdownMenuItem(child: Text('Diesel'), value: 'Diesel'),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFuelType = value!;
                      });
                    },
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addDevice,
                  child: Text('Dodaj urządzenie'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}