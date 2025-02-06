import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _employeeFormKey = GlobalKey<FormState>();
  final _constructionFormKey = GlobalKey<FormState>();
  final _categoryFormKey = GlobalKey<FormState>();

  final _employeeNameController = TextEditingController();
  final _employeePositionController = TextEditingController();
  final _constructionNameController = TextEditingController();
  final _constructionLocationController = TextEditingController();
  final _categoryNameController = TextEditingController();

  final DatabaseReference _database = FirebaseDatabase.instance.reference();

  List<Map<String, String>> _employees = [];
  List<Map<String, String>> _constructions = [];
  List<Map<String, String>> _categories = []; // For storing categories

  bool _isEmployeeExpanded = false;
  bool _isConstructionExpanded = false;
  bool _isCategoryExpanded = false; // Control category expansion

  void _addEmployee() {
    if (_employeeFormKey.currentState!.validate()) {
      final name = _employeeNameController.text;
      final position = _employeePositionController.text;

      final employeeId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      _database.child('employees').child(employeeId).set({
        'name': name,
        'position': position,
      }).then((_) {
        _loadEmployees();
        _employeeFormKey.currentState!.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pracownik dodany pomyślnie')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas dodawania pracownika')),
        );
      });
    }
  }

  void _addConstruction() {
    if (_constructionFormKey.currentState!.validate()) {
      final name = _constructionNameController.text;
      final location = _constructionLocationController.text;

      final constructionId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      _database.child('constructions').child(constructionId).set({
        'name': name,
        'location': location,
      }).then((_) {
        _loadConstructions();
        _constructionFormKey.currentState!.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budowa dodana pomyślnie')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas dodawania budowy')),
        );
      });
    }
  }

  void _addCategory() {
    if (_categoryFormKey.currentState!.validate()) {
      final name = _categoryNameController.text;

      final categoryId = name.replaceAll(RegExp(r'\s+'), '_').toLowerCase();

      _database.child('categories').child(categoryId).set({
        'name': name,
      }).then((_) {
        _categoryNameController.clear();
        _loadCategories(); // Load categories after adding a new one
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategoria dodana pomyślnie')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas dodawania kategorii')),
        );
      });
    }
  }

  void _loadEmployees() {
    _database.child('employees').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final employees = data.values.map((value) => Map<String, String>.from(value)).toList();
        setState(() {
          _employees = employees;
        });
      } else {
        setState(() {
          _employees = [];
        });
      }
    });
  }

  void _loadConstructions() {
    _database.child('constructions').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final constructions = data.values.map((value) => Map<String, String>.from(value)).toList();
        setState(() {
          _constructions = constructions;
        });
      } else {
        setState(() {
          _constructions = [];
        });
      }
    });
  }

  void _loadCategories() {
    _database.child('categories').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final categories = data.entries.map((entry) => {
          'id': entry.key,
          'name': entry.value['name'] as String,
        }).toList();
        setState(() {
          _categories = categories.map((category) => category.cast<String, String>()).toList(); // Ensure correct type
        });
      } else {
        setState(() {
          _categories = [];
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadConstructions();
    _loadCategories(); // Load categories on init
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ustawienia'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Form
              Form(
                key: _employeeFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Dodaj Pracownika', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _employeeNameController,
                      decoration: InputDecoration(labelText: 'Imię i nazwisko'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Proszę podać imię i nazwisko';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _employeePositionController,
                      decoration: InputDecoration(labelText: 'Stanowisko'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Proszę podać stanowisko';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addEmployee,
                      child: Text('Dodaj Pracownika'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              if (_isEmployeeExpanded)
                Column(
                  children: [
                    Text('Lista Pracowników', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Imię i nazwisko')),
                          DataColumn(label: Text('Stanowisko')),
                        ],
                        rows: _employees.map((employee) {
                          return DataRow(cells: [
                            DataCell(Text(employee['name']!)),
                            DataCell(Text(employee['position']!)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isEmployeeExpanded = !_isEmployeeExpanded;
                  });
                },
                child: Text(_isEmployeeExpanded ? 'Ukryj Pracowników' : 'Pokaż Pracowników'),
              ),
              SizedBox(height: 40),

              // Construction Form
              Form(
                key: _constructionFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Dodaj Budowę', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _constructionNameController,
                      decoration: InputDecoration(labelText: 'Nazwa Budowy'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Proszę podać nazwę budowy';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _constructionLocationController,
                      decoration: InputDecoration(labelText: 'Lokalizacja'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Proszę podać lokalizację';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addConstruction,
                      child: Text('Dodaj Budowę'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              if (_isConstructionExpanded)
                Column(
                  children: [
                    Text('Lista Budów', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Nazwa')),
                          DataColumn(label: Text('Lokalizacja')),
                        ],
                        rows: _constructions.map((construction) {
                          return DataRow(cells: [
                            DataCell(Text(construction['name']!)),
                            DataCell(Text(construction['location']!)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isConstructionExpanded = !_isConstructionExpanded;
                  });
                },
                child: Text(_isConstructionExpanded ? 'Ukryj Budowy' : 'Pokaż Budowy'),
              ),
              SizedBox(height: 40),

              // Category Form
              Form(
                key: _categoryFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Dodaj Kategorię produktu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _categoryNameController,
                      decoration: InputDecoration(labelText: 'Nazwa kategorii'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Proszę podać nazwę kategorii';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addCategory,
                      child: Text('Dodaj Kategorię'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Show Categories Button and List
              if (_isCategoryExpanded)
                Column(
                  children: [
                    Text('Lista Kategorii', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Nazwa kategorii')),
                        ],
                        rows: _categories.map((category) {
                          return DataRow(cells: [
                            DataCell(Text(category['id']!)),
                            DataCell(Text(category['name']!)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isCategoryExpanded = !_isCategoryExpanded;
                  });
                },
                child: Text(_isCategoryExpanded ? 'Ukryj Kategorie' : 'Pokaż Kategorie'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _employeeNameController.dispose();
    _employeePositionController.dispose();
    _constructionNameController.dispose();
    _constructionLocationController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }
}
