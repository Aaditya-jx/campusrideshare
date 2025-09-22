import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_drawer.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(22.3072, 73.1812);

  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoords = [];

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  /// ✅ Fetch route using Google Directions API
  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    const apiKey = "AIzaSyBZtnkBIygYn28_bCYKCHKIwquR3Xz6ZYI"; // 🔑 your Google API key here
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      _routeCoords = _decodePolyline(points);

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          visible: true,
          width: 5,
          color: Colors.blue,
          points: _routeCoords,
        ));
      });
    }
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rider Home")),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // 🌍 Map with driver markers + route
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("drivers")
                .where("sharingLocation", isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final markers = <Marker>{};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data();
                  if (data['lat'] != null && data['lng'] != null) {
                    final driverPos = LatLng(data['lat'], data['lng']);
                    markers.add(Marker(
                      markerId: MarkerId(doc.id),
                      position: driverPos,
                      infoWindow: InfoWindow(title: data['name'] ?? "Driver"),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                    ));
                  }
                }
              }
              return GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 13),
                markers: markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              );
            },
          ),

          // 📌 Bottom sheet with rides
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Text(
                      "Available Rides",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection("rides")
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(
                                child: Text("No rides available"));
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: docs.length,
                            itemBuilder: (c, i) {
                              final ride = docs[i].data();
                              final rideId = docs[i].id;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: ListTile(
                                  leading: const Icon(Icons.directions_car,
                                      color: Colors.indigo),
                                  title:
                                      Text("${ride['from']} → ${ride['to']}"),
                                  subtitle: Text(
                                      "Fare: ₹${ride['fare']} • Time: ${ride['time']}"),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      // 1. Save booking
                                      await FirebaseFirestore.instance
                                          .collection("bookings")
                                          .add({
                                        "rideId": rideId,
                                        "status": "booked",
                                        "createdAt":
                                            FieldValue.serverTimestamp(),
                                      });

                                      // 2. Get route from pickup → drop
                                      if (ride['fromLat'] != null &&
                                          ride['fromLng'] != null &&
                                          ride['toLat'] != null &&
                                          ride['toLng'] != null) {
                                        final origin = LatLng(
                                            ride['fromLat'], ride['fromLng']);
                                        final destination =
                                            LatLng(ride['toLat'], ride['toLng']);
                                        _getRoute(origin, destination);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                    child: const Text("Book"),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
