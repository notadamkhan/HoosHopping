import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'BusLineMapPage.dart';



class Environment {
  static const apiKey = String.fromEnvironment('GOOGLE_MAPS_KEY');
}

Future<PermissionStatus> requestLocationPermission() async {
  var status = await Permission.location.request();
  return status;
}
Future<List<BusLine>> fetchBusLines() async {
  final response = await http.get(Uri.parse('https://www.cs.virginia.edu/~pm8fc/busses/busses.json'));
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);


    // Check if the data contains 'stops' and 'routes' keys
    final stopsData = data['stops'] ?? [];
    final routesData = data['routes'] ?? [];

    List<BusStop> stops = [];
    for (var route in routesData) {
      var routeStops = route["stops"] ?? [];
      for (var stopId in routeStops) {
        var stopData = stopsData.firstWhere((stop) => stop["id"] == stopId, orElse: () => null);
        if (stopData != null) {
          stops.add(BusStop.fromJson(stopData, route["id"]));
        }
      }
    }

    List<BusLine> busLines = [];
    final linesData = data['lines'] ?? [];
    try {
      for (var line in linesData) {
        var lineStops = stops.where((stop) => stop.routeId == line["id"]).toList();
        if (lineStops.isEmpty) {
          print("No stops found for line ID: ${line["id"]}");
          continue;
        }

        busLines.add(BusLine.fromJson(line, lineStops));
      }

      print("Loop completed successfully.");
    } catch (e) {
      print("An exception occurred: $e");
    }
    return busLines;
  } else {
    throw Exception('Failed to load bus lines');
  }
}

class BusLine {
  final String longName;
  final String textColor;
  final List<double> bounds;
  final List<BusStop> stops;

  BusLine({
    required this.longName,
    required this.textColor,
    required this.bounds,
    required this.stops,
  });

  factory BusLine.fromJson(Map<String, dynamic> json, List<BusStop> stops) {
    return BusLine(
      longName: json['long_name'],
      textColor: json['text_color'],
      bounds: List<double>.from(json['bounds']),
      stops: stops,
    );
  }
}

class BusStop {
  final String code;
  final String description;
  final int id;
  final String locationType;
  final String name;
  final int? parentStationId;
  final List<double> position;
  final String url;
  final int routeId;

  BusStop({
    required this.code,
    required this.description,
    required this.id,
    required this.locationType,
    required this.name,
    this.parentStationId,
    required this.position,
    required this.url,
    required this.routeId,
  });

  factory BusStop.fromJson(Map<String, dynamic> json, int routeId) {
    return BusStop(
      code: json['code'],
      description: json['description'],
      id: json['id'],
      locationType: json['location_type'],
      name: json['name'],
      parentStationId: json['parent_station_id'],
      position: List<double>.from(json['position']),
      url: json['url'],
      routeId: routeId,
    );
  }
}


class FavoritesManager {
  static const _favoritesKey = 'favorites';

  // Save a favorite bus line
  static Future<void> toggleFavorite(String busLineName) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    if (favorites.contains(busLineName)) {
      favorites.remove(busLineName);
    } else {
      favorites.add(busLineName);
    }
    await prefs.setStringList(_favoritesKey, favorites);
  }

  // Load all favorites
  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey);
    return favorites?.toSet() ?? {};
  }
}

void main() {
  runApp(const MyApp());
  requestLocationPermission();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoosHopping',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HoosHopping 🚌'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
class _MyHomePageState extends State<MyHomePage> {
  Future<List<BusLine>> fetchAndSortBusLines() async {
    // Fetch bus lines
    final busLines = await fetchBusLines();
    // Get favorites
    final favorites = await FavoritesManager.getFavorites();
    // Sort bus lines based on favorites and then alphabetically
    busLines.sort((a, b) {
      final isAFavorite = favorites.contains(a.longName) ? 0 : 1;
      final isBFavorite = favorites.contains(b.longName) ? 0 : 1;
      if (isAFavorite == isBFavorite) {
        return a.longName.compareTo(b.longName);
      }
      return isAFavorite.compareTo(isBFavorite);
    });
    return busLines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<BusLine>>(
        future: fetchAndSortBusLines(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final busLines = snapshot.data!;
            return ListView.builder(
              itemCount: busLines.length,
              itemBuilder: (context, index) {
                final busLine = busLines[index];
                return FutureBuilder<Set<String>>(
                  future: FavoritesManager.getFavorites(),
                  builder: (context, favoriteSnapshot) {
                    if (favoriteSnapshot.hasData) {
                      final favorites = favoriteSnapshot.data!;
                      final isFavorite = favorites.contains(busLine.longName);
                      return ListTile(
                        title: Text(
                            busLine.longName,
                            style: TextStyle(
                              color: (Color(int.parse('0xFF${busLine.textColor}')) == Colors.white)
                                  ? Color(int.parse('0xFF000000')) // Use black if textColor is white
                                  : Color(int.parse('0xFF${busLine.textColor}')), // Use textColor otherwise
                            )
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ?
                            (Color(int.parse('0xFF${busLine.textColor}')) != Colors.white ? Color(int.parse('0xFF${busLine.textColor}')) : Colors.deepOrange)
                                : null,
                          ),
                          onPressed: () async {
                            await FavoritesManager.toggleFavorite(busLine.longName);
                            setState(() {}); // Refresh the UI after updating favorites
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => BusLineMapPage(busLine: busLine),
                            ),
                          );
                        },
                      );
                    } else {
//

                      return ListTile(
                        title: Text(
                          busLine.longName,
                          style: TextStyle(
                            color: (Color(int.parse('0xFF${busLine.textColor}')) == Colors.white)
                                ? Color(int.parse('0xFF000000')) // Use black if textColor is white
                                : Color(int.parse('0xFF${busLine.textColor}')), // Use textColor otherwise
                          )

                        ),
                        // Show a placeholder while favorites are loading
                        trailing: CircularProgressIndicator(),
                      );
                    }
                  },
                );
              },
            );
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          }
// By default, show a loading spinner.
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}