// lib/screens/supervisor/supervisor_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:steganograph/steganograph.dart';

import 'package:jalnetra01/common/firebase_service.dart';
import 'package:jalnetra01/models/reading_model.dart';
import 'package:jalnetra01/screens/auth/role_selection_screen.dart';
import 'package:jalnetra01/screens/common/profile_screen.dart';
import 'package:jalnetra01/screens/supervisor/supervisor_map_view.dart';
import 'package:jalnetra01/screens/supervisor/supervisor_alerts_view.dart';
import 'package:jalnetra01/screens/common/water_level_trend_charts.dart';

import '../../jalnetra_storage_image.dart';

enum DateFilter { all, today, week, month }

const List<String> kWaterSites = [
  'PUZHAL',
  'VEERANAM',
  'CHEMBARAMBAKAM',
  'CHOLAVARAM',
  'POONDI',
];

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  int _selectedIndex = 0;
  DateFilter _currentFilter = DateFilter.all;
  String _currentSiteFilter = kWaterSites.first;

  final List<String> _pageTitles = [
    'Community Inputs',
    'Verification History',
    'Map View',
    'Alerts & Incidents',
    'Water Level Trends',
  ];

  final List<IconData> _pageIcons = [
    Icons.people,
    Icons.history,
    Icons.map,
    Icons.warning_amber,
    Icons.show_chart,
  ];

  // ───────── URL FIX ─────────
  String _fixImageUrl(String url) {
    return url.replaceAll('firebasestorage.app', 'appspot.com');
  }

  // ───────── DATE FILTER ─────────
  List<WaterReading> _applyFilter(List<WaterReading> readings) {
    final now = DateTime.now();
    return readings.where((r) {
      final diff = now.difference(r.timestamp).inDays;
      switch (_currentFilter) {
        case DateFilter.today:
          return diff == 0;
        case DateFilter.week:
          return diff < 7;
        case DateFilter.month:
          return diff < 30;
        case DateFilter.all:
        default:
          return true;
      }
    }).toList();
  }

  // ───────── BODY SWITCH ─────────
  Widget _getBodyWidget() {
    switch (_selectedIndex) {
      case 0:
        return _buildCommunityInputs();
      case 1:
        return _buildHistory();
      case 2:
        return const SupervisorMapView();
      case 3:
        return const SupervisorAlertsView();
      case 4:
        return _buildTrends();
      default:
        return _buildCommunityInputs();
    }
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JALNETRA - Supervisor (${_pageTitles[_selectedIndex]})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseService().signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _getBodyWidget(),
    );
  }

  // ───────── DRAWER ─────────
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Text(
              'Supervisor Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (int i = 0; i < _pageTitles.length; i++)
            ListTile(
              leading: Icon(_pageIcons[i]),
              title: Text(_pageTitles[i]),
              selected: _selectedIndex == i,
              onTap: () {
                setState(() => _selectedIndex = i);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  // ───────── COMMUNITY INPUTS ─────────
  Widget _buildCommunityInputs() {
    return StreamBuilder<List<WaterReading>>(
      stream: FirebaseService().getCommunityInputs(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = _applyFilter(snap.data!);
        return _buildList(filtered, true);
      },
    );
  }

  // ───────── HISTORY ─────────
  Widget _buildHistory() {
    return StreamBuilder<List<WaterReading>>(
      stream: FirebaseService().getAllVerifiedReadings(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = _applyFilter(snap.data!);
        return _buildList(filtered, false);
      },
    );
  }

  // ───────── TRENDS ─────────
  Widget _buildTrends() {
    return StreamBuilder<List<WaterReading>>(
      stream: FirebaseService().getAllVerifiedReadings(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButton<String>(
                value: _currentSiteFilter,
                onChanged: (v) => setState(() => _currentSiteFilter = v!),
                items: kWaterSites
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
              WaterLevelTrendCharts(
                allReadings: snap.data!,
                selectedSite: _currentSiteFilter,
                title: "Water Level Trends",
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────── LIST BUILDER ─────────
  Widget _buildList(List<WaterReading> readings, bool pending) {
    if (readings.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: readings.length,
      itemBuilder: (_, i) => _buildReadingCard(readings[i], pending),
    );
  }

  // ───────── CARD ─────────
  Widget _buildReadingCard(WaterReading r, bool pending) {
    final date = DateFormat('yyyy-MM-dd hh:mm a').format(r.timestamp);
    final statusColor = pending
        ? Colors.orange
        : (r.isVerified ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            color: statusColor,
            child: Text(
              pending ? "PENDING" : (r.isVerified ? "APPROVED" : "REJECTED"),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          JalnetraStorageImage(
            imagePath: r.imagePath,
            width: double.infinity,
            height: 180,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Site: ${r.siteId}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("Level: ${r.waterLevel.toStringAsFixed(2)} m"),
                Text("Officer: ${r.officerId}"),
                Text("Time: $date"),
                const SizedBox(height: 8),
                if (pending)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => FirebaseService()
                              .updateVerificationStatus(r.id, true),
                          child: const Text("APPROVE"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => FirebaseService()
                              .updateVerificationStatus(r.id, false),
                          child: const Text("REJECT"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
