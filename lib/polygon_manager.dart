import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class PolygonManager {
  // List to store all created polygons
  final List<List<LatLng>> polygons = [];
  
  // Current polygon being drawn
  List<LatLng> currentPolygon = [];
  
  // Drawing mode flag
  bool isDrawingMode = false;
  
  // Add a point to the current polygon
  void addPoint(LatLng point) {
    currentPolygon.add(point);
  }
  
  // Complete the current polygon and add it to the list of polygons
  void completePolygon() {
    if (currentPolygon.length >= 3) {
      polygons.add(List.from(currentPolygon));
    }
    currentPolygon = [];
  }
  
  // Clear the current polygon
  void clearCurrentPolygon() {
    currentPolygon = [];
  }
  
  // Toggle drawing mode
  void toggleDrawingMode() {
    isDrawingMode = !isDrawingMode;
    if (!isDrawingMode) {
      // If we exit drawing mode, complete the current polygon
      completePolygon();
    }
  }
}
