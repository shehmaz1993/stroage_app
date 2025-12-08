import 'package:flutter/material.dart';

// NOTE: You would typically use providers (like connectivity_plus or device_info_plus)
// and watch your TransferNotifier here to get real data.
// For this UI implementation, we use mock data.

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview 📊',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // --- 1. Status and Diagnostics ---

          const Text('App Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),

          // Network Connectivity Status (Mock)
          const Card(
            child: ListTile(
              leading: Icon(Icons.wifi, color: Colors.green),
              title: Text('Network Connectivity'),
              subtitle: Text('Online (Wi-Fi)'),
              trailing: Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 10),

          // Background Service Status (Mock)
          const Card(
            child: ListTile(
              leading: Icon(Icons.work, color: Colors.blue),
              title: Text('Background Service'),
              subtitle: Text('WorkManager Initialized and Active.'),
            ),
          ),

          const SizedBox(height: 30),

          // --- 2. Storage Metrics ---

          const Text('Storage Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),

          _buildStorageGauge(context, usedGB: 8.5, totalGB: 32),

          const SizedBox(height: 30),

          // --- 3. Quick Action & Recent Activity ---

          const Text('Activity & Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),

          // Mock Recent Failed Transfer
          const Card(
            color: Colors.red,
            child: ListTile(
              leading: Icon(Icons.error, color: Colors.white),
              title: Text('3 Transfers Failed Recently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Tap to review and resume.', style: TextStyle(color: Colors.white70)),
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Action Button
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined, size: 24),
              label: const Text('Start New Upload', style: TextStyle(fontSize: 16)),
              onPressed: () {
                // In the real app, this should set the parent DashboardScreen's
                // index to 1 (the Upload tab)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Switched to Upload Tab (Index 1)'))
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageGauge(BuildContext context, {required double usedGB, required double totalGB}) {
    final double percentage = usedGB / totalGB;
    final Color color = percentage > 0.8 ? Colors.red : percentage > 0.5 ? Colors.orange : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Local Device Storage', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${usedGB.toStringAsFixed(1)} GB / ${totalGB.toStringAsFixed(0)} GB',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              color: color,
              minHeight: 12,
            ),
            const SizedBox(height: 5),
            Text(
              '${((1 - percentage) * totalGB).toStringAsFixed(1)} GB Available',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}