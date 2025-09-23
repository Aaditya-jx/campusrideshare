import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_rides.dart';
import 'my_bookings.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class PostRide extends StatefulWidget {
  const PostRide({super.key});

  @override
  State<PostRide> createState() => _PostRideState();
}

class _PostRideState extends State<PostRide> {
  final fromC = TextEditingController();
  final toC = TextEditingController();
  final fareC = TextEditingController();
  final dateC = TextEditingController();
  final timeC = TextEditingController();

  bool loading = false;
  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  GoogleMapController? _mapController;
  bool selectingPickup = true;
  final costPerKmC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateC.text = DateFormat('yyyy-MM-dd').format(now);
    timeC.text = DateFormat('HH:mm').format(now);
  }

  double _calculateDistanceKm(LatLng a, LatLng b) {
    const double R = 6371; // Earth radius in km
    double dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180.0;
    double dLon = (b.longitude - a.longitude) * 3.141592653589793 / 180.0;
    double lat1 = a.latitude * 3.141592653589793 / 180.0;
    double lat2 = b.latitude * 3.141592653589793 / 180.0;
    double aVal = (sin(dLat / 2) * sin(dLat / 2)) + (sin(dLon / 2) * sin(dLon / 2)) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return R * c;
  }

  void _updateFare() {
    if (_fromLatLng != null && _toLatLng != null && costPerKmC.text.isNotEmpty) {
      double dist = _calculateDistanceKm(_fromLatLng!, _toLatLng!);
      double costPerKm = double.tryParse(costPerKmC.text) ?? 0;
      fareC.text = (dist * costPerKm).toStringAsFixed(2);
    }
  }

  Future<void> _postRide() async {
    if (_fromLatLng == null || _toLatLng == null || fareC.text.isEmpty) return;
    setState(() => loading = true);
    await FirebaseFirestore.instance.collection("rides").add({
      "from": fromC.text,
      "to": toC.text,
      "fare": fareC.text,
      "date": dateC.text,
      "time": timeC.text,
      "fromLat": _fromLatLng!.latitude,
      "fromLng": _fromLatLng!.longitude,
      "toLat": _toLatLng!.latitude,
      "toLng": _toLatLng!.longitude,
      "createdAt": FieldValue.serverTimestamp(),
    });
    setState(() => loading = false);
    if (mounted) Navigator.pop(context);
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      if (selectingPickup) {
        _fromLatLng = pos;
        fromC.text = '(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      } else {
        _toLatLng = pos;
        toC.text = '(${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      }
      _updateFare();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => child ?? const SizedBox(),
    );
    if (picked != null) {
      dateC.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => child ?? const SizedBox(),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked != null) {
      timeC.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Ride"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rides') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyRides()));
              } else if (value == 'bookings') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyBookings()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rides', child: Text("My Rides")),
              const PopupMenuItem(value: 'bookings', child: Text("My Bookings")),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(21.0, 75.0), zoom: 7,
                ),
                onMapCreated: (c) => _mapController = c,
                markers: {
                  if (_fromLatLng != null)
                    Marker(markerId: const MarkerId('from'), position: _fromLatLng!, infoWindow: const InfoWindow(title: 'Pickup')),
                  if (_toLatLng != null)
                    Marker(markerId: const MarkerId('to'), position: _toLatLng!, infoWindow: const InfoWindow(title: 'Drop')),
                },
                onTap: _onMapTap,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => selectingPickup = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectingPickup ? Colors.indigo : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Select Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => setState(() => selectingPickup = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !selectingPickup ? Colors.indigo : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Select Drop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            TextField(
              controller: costPerKmC,
              decoration: const InputDecoration(labelText: "Cost per km"),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateFare(),
            ),
            TextField(
              controller: fareC,
              decoration: const InputDecoration(labelText: "Fare (auto-calculated)"),
              readOnly: true,
            ),
            TextField(
              controller: dateC,
              decoration: const InputDecoration(labelText: "Date"),
              readOnly: true,
              onTap: _pickDate,
            ),
            TextField(
              controller: timeC,
              decoration: const InputDecoration(labelText: "Time"),
              readOnly: true,
              onTap: _pickTime,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _postRide,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Post Ride"),
            ),
          ],
        ),
      ),
    );
  }
}
