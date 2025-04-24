import 'package:flutter/material.dart';
import 'package:road_damage_detector/screens/login_screen.dart';
import 'package:road_damage_detector/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EngineerDashboard extends StatefulWidget {
  @override
  _EngineerDashboardState createState() => _EngineerDashboardState();
}

class _EngineerDashboardState extends State<EngineerDashboard> {
  List assignedComplaints = [];
  final baseUrl = 'http://192.168.1.7:5000';
  Map<String, String> statusUpdates = {}; // Tracks new status per complaint

  @override
  void initState() {
    super.initState();
    fetchAssignedComplaints();
  }

  Future<void> fetchAssignedComplaints() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_id');

    final res = await http.get(Uri.parse('$baseUrl/admin/complaints'));
    if (res.statusCode == 200) {
      final allComplaints = jsonDecode(res.body);
      setState(() {
        assignedComplaints =
            allComplaints
                .where((comp) => comp['assigned_to'] == email)
                .toList();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch complaints')));
    }
  }

  Future<void> updateStatus(String complaintId, String status) async {
    final res = await http.post(
      Uri.parse('$baseUrl/engineer/update-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"complaint_id": complaintId, "status": status}),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status updated successfully")));
      fetchAssignedComplaints(); // Refresh complaints after update
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update status")));
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'in-progress':
        color = Colors.blue;
        break;
      case 'pending':
      default:
        color = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Engineer Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body:
          assignedComplaints.isEmpty
              ? Center(child: Text('No assigned complaints found.'))
              : ListView.builder(
                itemCount: assignedComplaints.length,
                itemBuilder: (_, index) {
                  final comp = assignedComplaints[index];
                  final complaintId = comp['_id'];
                  final currentStatus = comp['status'];

                  if (complaintId == null) return SizedBox(); // Skip if invalid

                  return Card(
                    margin: EdgeInsets.all(10),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Location: ${comp['location'] ?? 'Unknown'}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Text("Current Status: "),
                              _buildStatusBadge(currentStatus),
                            ],
                          ),
                          SizedBox(height: 10),
                          DropdownButton<String>(
                            value: statusUpdates[complaintId],
                            hint: Text("Update status"),
                            isExpanded: true,
                            items:
                                ['in-progress', 'completed']
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() {
                                statusUpdates[complaintId] = val!;
                              });
                            },
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              final selectedStatus = statusUpdates[complaintId];
                              if (selectedStatus != null &&
                                  selectedStatus != currentStatus) {
                                updateStatus(complaintId, selectedStatus);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      selectedStatus == currentStatus
                                          ? 'Status already set.'
                                          : 'Please select a status.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text("Submit Status"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
