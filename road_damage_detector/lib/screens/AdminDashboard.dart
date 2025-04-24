import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:road_damage_detector/screens/login_screen.dart';
import 'dart:convert';

import 'package:road_damage_detector/services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List complaints = [];
  final baseUrl = 'http://192.168.1.7:5000';

  @override
  void initState() {
    super.initState();
    fetchComplaints();
  }

  Future<void> fetchComplaints() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/complaints'));
    if (res.statusCode == 200) {
      setState(() {
        complaints = jsonDecode(res.body);
      });
    }
  }

  Future<void> assignEngineer(String complaintId, String engineerEmail) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "complaint_id": complaintId,
        "engineer": engineerEmail,
      }),
    );

    if (res.statusCode == 200) {
      fetchComplaints(); // Refresh
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Assigned")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              await AuthService.logout(); // Log the user out
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: complaints.length,
        itemBuilder: (_, index) {
          final comp = complaints[index];
          return Card(
            margin: EdgeInsets.all(10),
            child: ListTile(
              title: Text(comp['location']),
              subtitle: Text("Status: ${comp['status']}"),
              trailing:
                  comp['status'] == 'pending'
                      ? IconButton(
                        icon: Icon(Icons.assignment_ind),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) {
                              String email = '';
                              return AlertDialog(
                                title: Text("Assign Engineer"),
                                content: TextField(
                                  decoration: InputDecoration(
                                    hintText: "Engineer Email",
                                  ),
                                  onChanged: (val) => email = val,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      assignEngineer(comp['_id'], email);
                                      Navigator.pop(context);
                                    },
                                    child: Text("Assign"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      )
                      : Text("Assigned to: ${comp['assigned_to'] ?? 'N/A'}"),
            ),
          );
        },
      ),
    );
  }
}
