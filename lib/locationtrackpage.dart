import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_distance_app/Screens.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';

class loctrack extends StatefulWidget {
  const loctrack({super.key});

  @override
  State<loctrack> createState() => _loctrackState();
}

class _loctrackState extends State<loctrack> with WidgetsBindingObserver {
  Location location = Location();
  LocationData? _currentLocation;
  LocationData? _previousLocation;
  double totalDistance = 0.0;
  double _currentZoom = 14.0;
  List<Map<String, dynamic>> locationData = [];
  Set<Marker> _markers = {};
  bool isTracking = false;
  GoogleMapController? _mapController;
  final double thresholdDistance = 0.0018;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // initLocationTracking();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (isTracking) {
        await location.enableBackgroundMode(enable: true);
        print(":AppLifecycleState.resumed");
        initLocationTracking();
      }
    } else if (state == AppLifecycleState.paused) {
      if (isTracking) {
        await location.enableBackgroundMode(enable: true);
        print(":AppLifecycleState.paused");
        initLocationTracking();
      }
    }
  }

  clearAll() {
    setState(() {
      isTracking = false;
      totalDistance = 0.0;
      locationData.clear();
      _markers.clear();
      _polylineCoordinates.clear();
      // thresholdDistance = 0.00045;
    });
  }

  Future<void> initLocationTracking() async {
    // Check if location service is enabled
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    // Check for location permissions
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
      //  await location.enableBackgroundMode(enable: true);
    }
    location.changeSettings(
      accuracy: LocationAccuracy.high, // Use high accuracy
      interval: 1000, // Interval in milliseconds
      distanceFilter: 10, // Minimum distance in meters for updates
    );
    bool backgroundModeEnabled =
        await location.enableBackgroundMode(enable: true);
    if (!backgroundModeEnabled) {
      print("Failed to enable background mode");
    } else {
      print("pass to enable background mode");
    }
    // Start listening to location changes
    location.onLocationChanged.listen((LocationData currentLocation) {
      print(
          "currentLocation.longitude::" + currentLocation.longitude.toString());
      if (_previousLocation != null) {
        double distance = calculateDistance(
          _previousLocation!.latitude!,
          _previousLocation!.longitude!,
          currentLocation.latitude!,
          currentLocation.longitude!,
        );

        if (distance > thresholdDistance) {
          setState(() {
            _currentLocation = currentLocation;
            totalDistance += distance;

            // Save location data with timestamp
            locationData.add({
              'latitude': currentLocation.latitude!,
              'longitude': currentLocation.longitude!,
              'time': DateTime.now().toIso8601String(),
              'distance': distance,
            });

            _polylineCoordinates.add(
              LatLng(currentLocation.latitude!, currentLocation.longitude!),
            );
            _setPolylines();
            _mapController?.getZoomLevel().then((currentZoom) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                    LatLng(
                        currentLocation.latitude!, currentLocation.longitude!),
                    currentZoom),
              );
            });
            _markers.add(
              Marker(
                markerId: MarkerId(DateTime.now().toString()),
                position: LatLng(
                    currentLocation.latitude!, currentLocation.longitude!),
                infoWindow: InfoWindow(
                  title:
                      "Lat: ${currentLocation.latitude!}, Lon: ${currentLocation.longitude!}",
                  snippet: "Distance: ${distance.toStringAsFixed(2)} km",
                ),
              ),
            );

            // Update the previous location to the current location
            _previousLocation = currentLocation;
          });
        }
      } else {
        setState(() {
          _previousLocation = currentLocation;
          _currentLocation = currentLocation;
          _mapController?.getZoomLevel().then((currentZoom) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                  LatLng(currentLocation.latitude!, currentLocation.longitude!),
                  currentZoom),
            );
          });

          locationData.add({
            'latitude': currentLocation.latitude!,
            'longitude': currentLocation.longitude!,
            'time': DateTime.now().toIso8601String(),
            'distance': 0.0,
          });
          _markers.add(Marker(
            markerId: MarkerId(DateTime.now().toString()),
            position:
                LatLng(currentLocation.latitude!, currentLocation.longitude!),
            infoWindow: InfoWindow(
              title:
                  "Lat: ${currentLocation.latitude!}, Lon: ${currentLocation.longitude!}",
              snippet: "Distance: 0 km",
            ),
          ));
        });
      }
    });
  }

  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  void _setPolylines() {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_1'),
          points: _polylineCoordinates,
          color: Colors.blue,
          width: 5,
        ),
      );
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6378; // Earth's radius in kilometers
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = R * c;
    print('Distance calculated: $distance km');
    return distance;
  }

  Future<void> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['test'];
    List<CellValue?> rowfinal = [
      TextCellValue('Latitude'),
      TextCellValue('Longitude'),
      TextCellValue('Distance'),
      TextCellValue('Time'),
    ];
    // Add headers
    sheetObject.appendRow(rowfinal);

    // Add location data
    for (var data in locationData) {
      sheetObject.appendRow([
        TextCellValue(data['latitude'].toString()),
        TextCellValue(data['longitude'].toString()),
        TextCellValue(data['distance'].toStringAsFixed(2)),
        TextCellValue(data['time']),
      ]);
    }

    // Save to a file
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/TravelData.xlsx';
    print("jjjj" + path);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data exported to $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          clearAll();
                          initLocationTracking();
                          isTracking = true;
                        });
                      },
                      child: const Text("Start Track")),
                ),
                Container(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          exportToExcel();
                          isTracking = false;
                          clearAll();
                        });

                        // initLocationTracking();
                      },
                      child: const Text("End Track")),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.all(5),
                width: Screens.width(context),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        child: Text(
                            "Current Lattitude :${locationData.isNotEmpty ? _currentLocation?.latitude.toString() : ''}")),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                        child: Text(
                            "Current Langtitude :${locationData.isNotEmpty ? _currentLocation?.longitude.toString() : ""}")),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                        child: Text(
                            "Distance :${totalDistance.toStringAsFixed(2)} km")),
                  ],
                ),
              ),
            ),
            Container(
              width: Screens.width(context),
              height: Screens.padingHeight(context) * 0.5,
              child: InkWell(
                onTap: () {},
                child: GoogleMap(
                  myLocationEnabled: true,
                  // scrollGesturesEnabled: true,  // Disable map interactions while traveling
                  // zoomGesturesEnabled: true,    // Disable zooming while traveling
                  // rotateGesturesEnabled: true,  // Disable rotation while traveling
                  // tiltGesturesEnabled: true,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(0, 0),
                    zoom: 14,
                  ),
                  markers: _markers,

                  myLocationButtonEnabled: true,
                  onCameraMove: (position) {
                    setState(() {
                      _currentZoom = position.zoom;
                    });
                  },
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
            ),
            locationData.isEmpty
                ? Container()
                : Expanded(
                    child: ListView.builder(
                        itemCount: locationData.length,
                        itemBuilder: (context, ind) {
                          return Container(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                        width: Screens.width(context) * 0.1,
                                        child: Text("${ind + 1}")),
                                    Container(
                                        width: Screens.width(context) * 0.2,
                                        child: Text(
                                            "${locationData[ind]['latitude']}")),
                                    Container(
                                        width: Screens.width(context) * 0.2,
                                        child: Text(
                                            "${locationData[ind]['longitude']}")),
                                    Container(
                                        width: Screens.width(context) * 0.2,
                                        child: Text(
                                            "${locationData[ind]['time']}")),
                                    Container(
                                        width: Screens.width(context) * 0.2,
                                        child: Text(
                                            "${locationData[ind]['distance'].toStringAsFixed(2)}"))
                                  ],
                                ),
                              ],
                            ),
                          );
                        }))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          exportToExcel();
        },
        foregroundColor: Colors.red,
        child: const Icon(
          Icons.save,
          color: Colors.white,
        ),
      ),
    );
  }
}
