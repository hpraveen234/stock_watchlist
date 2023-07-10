import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(StockAdapter());

  final appDocumentDirectory = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDirectory.path);

  await Hive.close(); // Close any previously opened box
  await Hive.openBox<Stock>('watchlist');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Watchlist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
      routes: {
        '/watchlist': (context) => WatchlistScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Stock> searchResults = [];
  var _searchController = TextEditingController();
  Timer? _debounce;

  void searchCompanies(String query) async {
    final apiKey = 'https://www.alphavantage.co/';
    final url = Uri.parse(
        'https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=$query&apikey=$apiKey');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final stockData = jsonData['bestMatches'];

      if (stockData != null) {
        setState(() {
          searchResults =
              stockData.map<Stock>((data) => Stock.fromMap(data)).toList();
        });
      } else {
        setState(() {
          searchResults = [];
        });
      }
    } else {
      // Handle error case
      print('Error: ${response.statusCode}');
    }
  }

  void addToWatchlist(String symbol, String name, String price) {
    final watchlistBox = Hive.box<Stock>('watchlist');
    final stock = Stock(symbol: symbol, name: name, price: price);
    watchlistBox.add(stock);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TRADE BRAINS'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 50),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Color.fromARGB(255, 217, 212, 212),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  searchCompanies(value);
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final stock = searchResults[index];
                return ListTile(
                  title: Text(stock.symbol),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stock.name),
                      Text('Price: ${stock.price}'), // Display the share price
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      addToWatchlist(stock.symbol, stock.name, stock.price);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationWidget(),
    );
  }
}

class Stock {
  final String symbol;
  final String name;
  final String price; // New field to store the share price

  Stock({required this.symbol, required this.name, required this.price});

  factory Stock.fromMap(Map<String, dynamic> map) {
    final symbol = map['1. symbol'];
    final name = map['2. name'];
    final price = map['5. price'] ?? 'N/A'; // If price is null, set it to 'N/A'

    return Stock(
      symbol: symbol ?? 'N/A', // If symbol is null, set it to 'N/A'
      name: name ?? 'N/A', // If name is null, set it to 'N/A'
      price: price.toString(), // Convert the price to a string
    );
  }
}

class StockAdapter extends TypeAdapter<Stock> {
  @override
  final typeId = 0;

  @override
  Stock read(BinaryReader reader) {
    return Stock(
      symbol: reader.readString(),
      name: reader.readString(),
      price: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Stock obj) {
    writer.writeString(obj.symbol);
    writer.writeString(obj.name);
    writer.writeString(obj.price);
  }
}

class BottomNavigationWidget extends StatefulWidget {
  @override
  _BottomNavigationWidgetState createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index; // Update the current index
    });

    // Navigate to the corresponding screen based on the selected index
    if (index == 0) {
      Navigator.popUntil(context, ModalRoute.withName('/'));
    } else if (index == 1) {
      Navigator.pushNamed(context, '/watchlist');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex, // Set the current index
      onTap: _onTabTapped, // Handle bottom navigation bar tap
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Watchlist',
        ),
      ],
    );
  }
}

class WatchlistScreen extends StatefulWidget {
  @override
  _WatchlistScreenState createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  late Box<Stock> watchlistBox;

  @override
  void initState() {
    super.initState();
    watchlistBox = Hive.box<Stock>('watchlist');
  }

  void deleteFromWatchlist(int index) {
    if (index >= 0 && index < watchlistBox.length) {
      watchlistBox.deleteAt(index);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watchlist'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Table(
                border: TableBorder.all(width: 1.0),
                columnWidths: {
                  0: FlexColumnWidth(4),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                    ),
                    children: [
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            'Company Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            'Share Price',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TableCell(
                        child: SizedBox.shrink(),
                      ),
                    ],
                  ),
                  for (int index = 0; index < watchlistBox.length; index++)
                    TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(watchlistBox.getAt(index)!.name),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(watchlistBox.getAt(index)!.price),
                          ),
                        ),
                        TableCell(
                          child: IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () {
                              deleteFromWatchlist(index);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(),
    );
  }
}
