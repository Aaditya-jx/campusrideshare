import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_rides.dart';
import 'my_bookings.dart';

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

  Future<void> _postRide() async {
    if (fromC.text.isEmpty || toC.text.isEmpty) return;
    setState(() => loading = true);

    await FirebaseFirestore.instance.collection("rides").add({
      "from": fromC.text,
      "to": toC.text,
      "fare": fareC.text,
      "date": dateC.text,
      "time": timeC.text,
      "createdAt": FieldValue.serverTimestamp(),
    });

    setState(() => loading = false);
    if (mounted) Navigator.pop(context); // back to previous screen
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
            TextField(controller: fromC, decoration: const InputDecoration(labelText: "From")),
            TextField(controller: toC, decoration: const InputDecoration(labelText: "To")),
            TextField(controller: fareC, decoration: const InputDecoration(labelText: "Fare")),
            TextField(controller: dateC, decoration: const InputDecoration(labelText: "Date")),
            TextField(controller: timeC, decoration: const InputDecoration(labelText: "Time")),
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
