import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'feedback_page.dart';

class MyBookings extends StatefulWidget {
  const MyBookings({super.key});

  @override
  State<MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends State<MyBookings> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Payment Successful! Booking Confirmed.")),
    );

    // Mark the booking as paid/confirmed in Firestore
    // Find the booking document and update its status
    // This assumes you have the bookingId available
    // You may need to refactor to pass bookingId to _startPayment and _handlePaymentSuccess
    // For now, show a message to implement correct logic
    // TODO: Implement booking status update here
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Wallet Selected: ${response.walletName}")),
    );
  }

  void _startPayment(int amount) {
    var options = {
      'key': 'rzp_test_RBcLkRDIOCOnml', // 🔑 Replace with your Razorpay Test Key
      'amount': amount * 100, // Razorpay works in paise
      'name': 'Campus Ride',
      'description': 'Ride Booking Payment',
      'prefill': {'contact': '9876543210', 'email': 'test@razorpay.com'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection("bookings").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No bookings yet"));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final booking = docs[i].data();
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text("Ride: ${booking['rideId']}"),
                  subtitle: Text("Status: ${booking['status']}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      _startPayment(booking['fare'] ?? 100);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Pay Now"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
