import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class IssueDevicePage extends StatefulWidget {
  @override
  _IssueDevicePageState createState() => _IssueDevicePageState();
}

class _IssueDevicePageState extends State<IssueDevicePage> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.reference();
  String? _selectedEmployee;
  Map<String, dynamic>? _selectedDevice;
  List<String> _employeeList = [];
  List<Map<String, dynamic>> _deviceList = [];
  Map<String, dynamic> _deviceMap = {};
  List<Map<String, dynamic>> _employeeDevices = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadDevices();
  }

  void _loadEmployees() async {
    DatabaseEvent event = await _databaseReference.child('employees').once();
    DataSnapshot snapshot = event.snapshot;
    Map<dynamic, dynamic> employees = snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _employeeList = employees.keys.map((key) => employees[key]['name'].toString()).toList();
    });
  }

  void _loadDevices() async {
    DatabaseEvent event = await _databaseReference.child('devices').once();
    DataSnapshot snapshot = event.snapshot;
    Map<dynamic, dynamic> devices = snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _deviceMap = devices.cast<String, dynamic>();
      _deviceList = devices.keys.map((key) {
        return {
          'id': key,
          'name': devices[key]['name'],
          'model': devices[key]['model'] ?? '',
          'description': devices[key]['description'],
          'quantity': devices[key]['quantity'],
          'category': devices[key]['category'],
          'powerType': devices[key]['powerType'],
          'available': devices[key]['available'] ?? true,
          'employee': devices[key]['employee'] ?? '',
        };
      }).toList();
    });
  }

  void _issueDevice() {
    if (_selectedEmployee != null && _selectedDevice != null) {
      if (_selectedDevice!['available']) {
        String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        int currentQuantity = int.parse(_selectedDevice!['quantity']);
        int newQuantity = currentQuantity - 1;
        bool newAvailability = newQuantity > 0;

        _databaseReference.child('issuedevices').push().set({
          'employee': _selectedEmployee,
          'device': _selectedDevice!['id'],
          'timestamp': formattedDate,
        }).then((_) {
          _databaseReference.child('devices').child(_selectedDevice!['id']).update({
            'quantity': newQuantity.toString(),
            'available': newAvailability,
            'employee': _selectedEmployee,
          });

          _databaseReference.child('deviceHistory').push().set({
            'employee': _selectedEmployee,
            'device': _selectedDevice!['id'],
            'name': _selectedDevice!['name'],
            'model': _selectedDevice!['model'],
            'issued': formattedDate,
            'returned': null,
          });

          setState(() {
            _selectedDevice = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sprzęt został wydany $_selectedEmployee!'),
            ),
          );
          _loadDevices();
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Błąd przy wydawaniu sprzętu: $error'),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sprzęt jest niedostępny.'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wybierz pracownika i sprzęt.'),
        ),
      );
    }
  }

  void _returnDevice(Map<String, dynamic> device) {
    String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    int currentQuantity = int.parse(device['quantity']);
    int newQuantity = currentQuantity + 1;

    _databaseReference.child('devices').child(device['id']).update({
      'quantity': newQuantity.toString(),
      'available': true,
      'employee': '',
    }).then((_) {
      _databaseReference.child('issuedevices').orderByChild('device').equalTo(device['id']).once().then((event) {
        Map<dynamic, dynamic> issueRecords = event.snapshot.value as Map<dynamic, dynamic>;
        issueRecords.forEach((key, value) {
          if (value['employee'] == _selectedEmployee && value['device'] == device['id']) {
            _databaseReference.child('issuedevices').child(key).remove();
            _databaseReference.child('deviceHistory').orderByChild('device').equalTo(device['id']).once().then((historyEvent) {
              Map<dynamic, dynamic> historyRecords = historyEvent.snapshot.value as Map<dynamic, dynamic>;
              historyRecords.forEach((historyKey, historyValue) {
                if (historyValue['employee'] == _selectedEmployee && historyValue['device'] == device['id'] && historyValue['returned'] == null) {
                  _databaseReference.child('deviceHistory').child(historyKey).update({
                    'returned': formattedDate,
                  });
                }
              });
            });
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sprzęt został oddany!'),
          ),
        );
        _loadDevices();
        _loadEmployeeDevices();
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przy oddawaniu sprzętu: $error')),
      );
    });
  }

  void _loadEmployeeDevices() {
    if (_selectedEmployee != null) {
      _databaseReference.child('issuedevices').orderByChild('employee').equalTo(_selectedEmployee).once().then((event) {
        DataSnapshot snapshot = event.snapshot;
        Map<dynamic, dynamic> issuedDevices = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _employeeDevices = issuedDevices.values.map((value) {
            String deviceId = value['device'];
            return {
              'id': deviceId,
              'name': _deviceMap[deviceId]['name'],
              'model': _deviceMap[deviceId]['model'],
              'description': _deviceMap[deviceId]['description'],
              'quantity': _deviceMap[deviceId]['quantity'],
            };
          }).toList();
        });
      });
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeviceSelectionDialog(
          deviceList: _deviceList.where((device) => device['available'] == true).toList(),
          onDeviceSelected: (device) {
            setState(() {
              _selectedDevice = device;
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showReturnDeviceDialog() {
    if (_selectedEmployee != null) {
      _loadEmployeeDevices();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ReturnDeviceDialog(
            deviceList: _employeeDevices,
            onDeviceReturned: (device) {
              _returnDevice(device);
              Navigator.of(context).pop();
            },
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wybierz pracownika, aby zwrócić sprzęt.'),
        ),
      );
    }
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return HistoryDialog();
      },
    );
  }

  void _showNotReturnedDevicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NotReturnedDevicesDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wydanie Sprzętu'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Wybierz pracownika',
                  border: OutlineInputBorder(),
                ),
                value: _selectedEmployee,
                items: _employeeList.map((String employee) {
                  return DropdownMenuItem<String>(
                    value: employee,
                    child: Text(employee),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedEmployee = newValue;
                    _loadEmployeeDevices();
                  });
                },
              ),
              SizedBox(height: 16.0),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(// Tło
                  borderRadius: BorderRadius.circular(5), // Zaokrąglenie krawędzi
                  border: Border.all(
                    color: Colors.black, // Kolor obramowania
                    width: 1, // Szerokość obramowania
                  ),
                ),
                child: InkWell(
                  onTap: _showDeviceSelectionDialog,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    child: Text(
                      _selectedDevice == null ? 'Wybierz sprzęt' : 'Sprzęt wybrany',
                      style: TextStyle(
                        color: Colors.black54, // Kolor tekstu
                        fontSize: 16.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.0),

              if (_selectedDevice != null) ...[
                SizedBox(height: 16.0),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wybrany sprzęt: ${_selectedDevice!['name']}',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        'Opis: ${_selectedDevice!['description']}',
                        style: TextStyle(fontSize: 14.0),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 32.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _issueDevice,
                  child: Text('Wydaj sprzęt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // background
                    foregroundColor: Colors.white, // foreground
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showReturnDeviceDialog,
                  child: Text('Oddanie sprzętu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // background
                    foregroundColor: Colors.white, // foreground
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showNotReturnedDevicesDialog,
                  child: Text('Sprawdź kto ma sprzęt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // background
                    foregroundColor: Colors.blue, // foreground
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showHistoryDialog,
                  child: Text('Historia sprzętów'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // background
                    foregroundColor: Colors.blue, // foreground
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> deviceList;
  final Function(Map<String, dynamic>) onDeviceSelected;

  DeviceSelectionDialog({required this.deviceList, required this.onDeviceSelected});

  @override
  _DeviceSelectionDialogState createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> {
  String? _selectedCategory;
  String? _selectedPowerType;
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredDeviceList = [];

  @override
  void initState() {
    super.initState();
    _filteredDeviceList = widget.deviceList;
  }

  void _filterDevices() {
    setState(() {
      _filteredDeviceList = widget.deviceList.where((device) {
        final matchesCategory = _selectedCategory == null || device['category'] == _selectedCategory;
        final matchesPowerType = _selectedCategory != 'mechaniczny' ||
            (_selectedPowerType == null || device['powerType'] == _selectedPowerType);
        final matchesSearchQuery = device['name'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesPowerType && matchesSearchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Wybierz sprzęt'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Szukaj wg nazwy',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                  _filterDevices();
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
              items: widget.deviceList.map((device) => device['category']).toSet().map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (newValue) {
                _selectedCategory = newValue;
                _selectedPowerType = null; // Reset power type filter when category changes
                _filterDevices();
              },
            ),
            if (_selectedCategory == 'mechaniczny')
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Filtruj wg typu zasilania',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedPowerType,
                items: ['elektryczny', 'spalinowy'].map((powerType) {
                  return DropdownMenuItem<String>(
                    value: powerType,
                    child: Text(powerType),
                  );
                }).toList(),
                onChanged: (newValue) {
                  _selectedPowerType = newValue;
                  _filterDevices();
                },
              ),
            SizedBox(height: 16.0),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredDeviceList.length,
                itemBuilder: (context, index) {
                  var device = _filteredDeviceList[index];
                  return ListTile(
                    title: Text(device['name']),
                    subtitle: Text(device['description']),
                    onTap: () {
                      widget.onDeviceSelected(device);
                    },
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
          child: Text('Anuluj'),
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class ReturnDeviceDialog extends StatelessWidget {
  final List<Map<String, dynamic>> deviceList;
  final Function(Map<String, dynamic>) onDeviceReturned;

  ReturnDeviceDialog({required this.deviceList, required this.onDeviceReturned});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Oddaj sprzęt'),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: deviceList.length,
          itemBuilder: (context, index) {
            var device = deviceList[index];
            return ListTile(
              title: Text(device['name']),
              subtitle: Text(device['description']),
              onTap: () {
                onDeviceReturned(device);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Anuluj'),
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class HistoryDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Historia sprzętów'),
      content: HistoryContent(),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Zamknij'),
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class HistoryContent extends StatefulWidget {
  @override
  _HistoryContentState createState() => _HistoryContentState();
}

class _HistoryContentState extends State<HistoryContent> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.reference();
  List<Map<String, dynamic>> _historyList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    DatabaseEvent event = await _databaseReference.child('deviceHistory').once();
    DataSnapshot snapshot = event.snapshot;
    Map<dynamic, dynamic> history = snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _historyList = history.values.map((value) {
        return {
          'employee': value['employee'],
          'device': value['device'],
          'name': value['name'],
          'model': value['model'],
          'issued': value['issued'],
          'returned': value['returned'],
        };
      }).toList();
    });
  }

  void _filterHistory() {
    setState(() {
      _historyList = _historyList.where((historyItem) {
        final matchesSearchQuery = historyItem['employee'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            historyItem['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            historyItem['model'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSearchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Szukaj w historii',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
                _filterHistory();
              });
            },
          ),
          SizedBox(height: 16.0),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                var historyItem = _historyList[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListTile(
                    title: Text('${historyItem['employee']} - ${historyItem['name']} (${historyItem['model']})'),
                    subtitle: Text('Data wypożyczenia: ${historyItem['issued']}\nData oddania: ${historyItem['returned'] ?? 'N/A'}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotReturnedDevicesDialog extends StatefulWidget {
  @override
  _NotReturnedDevicesDialogState createState() => _NotReturnedDevicesDialogState();
}

class _NotReturnedDevicesDialogState extends State<NotReturnedDevicesDialog> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.reference();
  List<Map<String, dynamic>> _notReturnedDevices = [];
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredNotReturnedDevices = [];

  @override
  void initState() {
    super.initState();
    _loadNotReturnedDevices();
  }

  void _loadNotReturnedDevices() async {
    DatabaseEvent event = await _databaseReference.child('deviceHistory').orderByChild('returned').equalTo(null).once();
    DataSnapshot snapshot = event.snapshot;
    Map<dynamic, dynamic> notReturnedDevices = snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _notReturnedDevices = notReturnedDevices.values.map((value) {
        return {
          'name': value['name'],
          'model': value['model'],
          'employee': value['employee'],
          'issued': value['issued'], // Include issued date
        };
      }).toList();
      _filteredNotReturnedDevices = _notReturnedDevices;
    });
  }

  void _filterNotReturnedDevices() {
    setState(() {
      _filteredNotReturnedDevices = _notReturnedDevices.where((device) {
        final matchesSearchQuery = device['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            device['model'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            device['employee'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSearchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sprzęty, które nie zostały zwrócone'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Szukaj wg nazwy, modelu lub pracownika',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                  _filterNotReturnedDevices();
                });
              },
            ),
            SizedBox(height: 16.0),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredNotReturnedDevices.length,
                itemBuilder: (context, index) {
                  var device = _filteredNotReturnedDevices[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white, // Poprawiono z fillColor na color
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListTile(
                      title: Text('${device['name']} (${device['model']})'),
                      subtitle: Text('Pracownik: ${device['employee']}\nData wydania: ${device['issued']}'),
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
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
