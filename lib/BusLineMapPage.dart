import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'main.dart';

class BusLineMapPage extends StatefulWidget {
  final BusLine busLine;

  const BusLineMapPage({Key? key, required this.busLine}) : super(key: key);

  @override
  _BusLineMapPageState createState() => _BusLineMapPageState();
}

class _BusLineMapPageState extends State<BusLineMapPage> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _setMapBounds();
    _addBusStopMarkers();
  }

  void _setMapBounds() {
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(widget.busLine.bounds[0], widget.busLine.bounds[1]),
      northeast: LatLng(widget.busLine.bounds[2], widget.busLine.bounds[3]),
    );
    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _addBusStopMarkers() {
    widget.busLine.stops.forEach((busStop) {
      _markers.add(Marker(
        markerId: MarkerId(busStop.name),
        position: LatLng(busStop.position[0], busStop.position[1]),
        infoWindow: InfoWindow(title: busStop.name),
      ));
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.busLine.longName),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        mapType: MapType.terrain,
        initialCameraPosition: CameraPosition(
          target: LatLng(38.0316, -78.5108),
          zoom: 14.0,
        ),
        markers: _markers,
        myLocationEnabled: true,
      ),
    );

  }
}
class MapPage extends StatefulWidget {
  final BusLine busLine;

  const MapPage({Key? key, required this.busLine}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;

  // Function to set map bounds
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _setMapBounds();
  }

  void _setMapBounds() {
    final bounds = widget.busLine.bounds;
    final sw = LatLng(bounds[0], bounds[1]);
    final ne = LatLng(bounds[2], bounds[3]);
    mapController.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.busLine.longName),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          // Use the middle of the bounds as the initial position
          target: LatLng(
            (widget.busLine.bounds[0] + widget.busLine.bounds[2]) / 2,
            (widget.busLine.bounds[1] + widget.busLine.bounds[3]) / 2,
          ),
          zoom: 14.0,
        ),
        myLocationEnabled: true, // Enables user location dot
      ),
    );
  }

}
