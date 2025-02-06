import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'add_product_page.dart';
import 'add_device_page.dart';
import 'inventory_page.dart';
import 'issue_product_page.dart';
import 'statistics_page.dart';
import 'issue_device_page.dart';
import 'settings_page.dart'; // Import the settings page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyCweRzNJZ9cT_TvB0DSum_J4voJJC11wtE",
          appId: '864235344189:android:f7e6324dd0f3213df43554',
          messagingSenderId: '864235344189',
          projectId: 'aleco-lezajsk-8a21b',
          databaseURL: "https://aleco-lezajsk-8a21b-default-rtdb.europe-west1.firebasedatabase.app"
      ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.lightBlueAccent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(0),
              bottomLeft: Radius.circular(0),
            ),
          ),
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightBlue).copyWith(),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (navigatorKey.currentState?.canPop() ?? false) {
          navigatorKey.currentState?.pop();
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        body: Navigator(
          key: navigatorKey,
          onGenerateRoute: (RouteSettings settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => HomePage(navigatorKey: navigatorKey));
              case '/add_product':
                return MaterialPageRoute(builder: (_) => AddProductPage());
              case '/add_device':
                return MaterialPageRoute(builder: (_) => AddDevicePage());
              case '/inventory':
                return MaterialPageRoute(builder: (_) => InventoryPage());
              case '/issue_product':
                return MaterialPageRoute(builder: (_) => IssueProductPage());
              case '/statistics':
                return MaterialPageRoute(builder: (_) => StatisticsPage());
              case '/issue_device':
                return MaterialPageRoute(builder: (_) => IssueDevicePage());
              case '/settings':
                return MaterialPageRoute(builder: (_) => SettingsPage());
              default:
                return null;
            }
          },
        ),
        appBar: CustomAppBar(),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(100);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 200,
                height: 100,
                padding: EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'lib/alecologo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const HomePage({Key? key, required this.navigatorKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: screenWidth / (screenHeight * 0.5),
      children: <Widget>[
        RoundedIconContainer(
          icon: Icons.shopping_bag,
          color: Colors.red,
          label: 'Dodaj produkty',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/add_product');
          },
        ),
        RoundedIconContainer(
          icon: Icons.assignment_turned_in,
          color: Colors.grey,
          label: 'Wydanie produktów',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/issue_product');
          },
        ),
        RoundedIconContainer(
          icon: Icons.construction_rounded,
          color: Colors.green,
          label: 'Dodaj narzędzia lub urządzenia',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/add_device');
          },
        ),
        RoundedIconContainer(
          icon: Icons.construction_rounded,
          color: Colors.purple,
          label: 'Wydanie narzędzi lub sprzętu',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/issue_device');
          },
        ),
        RoundedIconContainer(
          icon: Icons.bar_chart,
          color: Colors.orange,
          label: 'Statystyki poszczególnych budów',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/statistics');
          },
        ),
        RoundedIconContainer(
          icon: Icons.inventory,
          color: Colors.brown,
          label: 'Stan magazynowy',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/inventory');
          },
        ),
        RoundedIconContainer(
          icon: Icons.settings,
          color: Colors.blue,
          label: 'Ustawienia',
          onTap: () {
            navigatorKey.currentState?.pushNamed('/settings');
          },
        ),
      ],
    );
  }
}

class RoundedIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const RoundedIconContainer({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: Colors.white,
            ),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
