import 'package:flutter/material.dart';
import 'package:storage_app/features/screens/upload_screen.dart';

import 'download_screen.dart';
import 'global_transfar_status.dart';
import 'home_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // List of the screens/widgets corresponding to the tabs
  final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),      // Index 0: General Home/Status View
    const UploadScreen(),    // Index 1: File Upload Interface
    const DownloadScreen(),  // Index 2: File Download Interface & Progress List
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Manager'),
        backgroundColor: Colors.blueAccent,
      ),

      // 🚨 Body Structure: Column is used to place the banner persistently
      // above the dynamically changing tab content.
      body: Column(
        children: [
          // 1. 🌐 Global Status Banner (Always visible and shows active transfers)
          const GlobalTransferStatus(),

          // 2. 📱 Swappable Content Area (Expanded to take remaining space)
          Expanded(
            child: Center(
              // The selected screen widget is displayed here
              child: _widgetOptions.elementAt(_selectedIndex),
            ),
          ),
        ],
      ),

      // --- Bottom Navigation Bar ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud_download), label: 'Download'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}