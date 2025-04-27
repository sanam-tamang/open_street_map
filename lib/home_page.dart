import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_learning/get_user_current_position.dart';
import 'package:map_learning/polygon_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _currentUserLocation;
  MapController controller = MapController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Polygon drawing
  final PolygonManager _polygonManager = PolygonManager();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await _getCurrentLocation();

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _updateLocation(position);
      },
      onError: (error) {
        print('Error getting location updates: $error');
      },
    );
  }

  void _updateLocation(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentUserLocation = newLocation;
    });

    controller.move(newLocation, 15);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final Position position = await getUserCurrentPosition();
      _updateLocation(position);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final Position position = await getUserCurrentPosition();
      controller.move(LatLng(position.latitude, position.longitude), 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error centering on location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(value);
    });
  }

  void _moveToLocation(dynamic location) {
    final lat = double.parse(location['lat']);
    final lon = double.parse(location['lon']);
    final newLocation = LatLng(lat, lon);

    setState(() {
      _searchResults = [];
      _searchController.clear();
    });

    controller.move(newLocation, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialZoom: 15,
              initialCenter: _currentUserLocation ?? const LatLng(0, 0),
              onPositionChanged: (camera, bool hasGesture) {
                if (hasGesture) {}
              },
              onTap: (tapPosition, point) {
                if (_polygonManager.isDrawingMode) {
                  setState(() {
                    _polygonManager.addPoint(point);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.test.app",
              ),
              // Display completed polygons
              if (_polygonManager.polygons.isNotEmpty)
                PolygonLayer(
                  polygons:
                      _polygonManager.polygons
                          .map(
                            (points) => Polygon(
                              points: points,
                              color: Colors.blue.withAlpha(128),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 2,
                            ),
                          )
                          .toList(),
                ),
              // Display current polygon being drawn
              if (_polygonManager.currentPolygon.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _polygonManager.currentPolygon,
                      color: Colors.red.withAlpha(76),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // Display markers for current polygon points
              if (_polygonManager.currentPolygon.isNotEmpty)
                MarkerLayer(
                  markers:
                      _polygonManager.currentPolygon
                          .map(
                            (point) => Marker(
                              point: point,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              if (_currentUserLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentUserLocation!,
                      width: 80,
                      height: 80,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue, size: 40),
                          PulsingCircle(),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (_polygonManager.isDrawingMode)
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Polygon Drawing Mode: Tap on the map to add points. Complete with ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon:
                          _isSearching
                              ? Container(
                                width: 24,
                                height: 24,
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(result['display_name']),
                          onTap: () => _moveToLocation(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on current location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _polygonManager.toggleDrawingMode();
                // If we exit drawing mode and have an incomplete polygon, complete it
                if (!_polygonManager.isDrawingMode &&
                    _polygonManager.currentPolygon.length >= 3) {
                  _polygonManager.completePolygon();
                }
              });
            },
            backgroundColor: _polygonManager.isDrawingMode ? Colors.red : null,
            tooltip: 'Toggle polygon drawing mode',
            child: const Icon(Icons.edit),
          ),
          const SizedBox(height: 16),
          if (_polygonManager.isDrawingMode &&
              _polygonManager.currentPolygon.isNotEmpty)
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_polygonManager.currentPolygon.length >= 3) {
                    _polygonManager.completePolygon();
                  } else {
                    _polygonManager.clearCurrentPolygon();
                  }
                });
              },
              backgroundColor: Colors.green,
              tooltip: 'Complete current polygon',
              child: const Icon(Icons.check),
            ),
          if (_polygonManager.isDrawingMode &&
              _polygonManager.currentPolygon.isNotEmpty)
            const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              // Toggle location updates
              if (_positionStreamSubscription == null) {
                _startLocationUpdates();
              } else {
                _positionStreamSubscription?.cancel();
                _positionStreamSubscription = null;
              }
            },
            tooltip: 'Toggle location updates',
            child: Icon(
              _positionStreamSubscription == null
                  ? Icons.location_disabled
                  : Icons.location_on,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}

class PulsingCircle extends StatefulWidget {
  const PulsingCircle({super.key});

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withAlpha(
              ((1 - _controller.value) * 255).toInt(),
            ),
            border: Border.all(color: Colors.blue),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
