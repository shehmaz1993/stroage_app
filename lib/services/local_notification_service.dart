import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// Assuming apps_global.dart holds the navigatorKey
import '../utils/apps_global.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'transfer_channel_id';
  static const String channelName = 'File Transfers';
  static const String channelDescription = 'Notifications for file uploads and downloads';

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS);


    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId, // Must match the channelId used in showCompletionNotification
        channelName,
        description: channelDescription,
        importance: Importance.max,
      );
      // Create the channel before the general initialization
      await androidImplementation.createNotificationChannel(channel);
    }



    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? transferId = response.payload;

        if (transferId != null && navigatorKey.currentState != null) {
          // This logic is executed when the notification is tapped.

          navigatorKey.currentState!.pushNamed(
            '/transfer-detail', // Ensure this route is defined in your MaterialApp
            arguments: transferId, // Pass the ID to the screen
          );
        }
      },
    );
  }


  Future<void> showCompletionNotification({
    required String taskId,
    required String fileName,
    required bool isUpload,
    required bool isSuccess,
  }) async {
    final int notificationId = taskId.hashCode;
    final String type = isUpload ? "Upload" : "Download";
    final String title = "$type ${isSuccess ? 'Complete' : 'Failed'}";
    final String body = "$fileName ${isSuccess ? 'finished successfully.' : 'failed. Tap to retry.'}";


    final Color color = isSuccess ? Colors.green : Colors.red;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, // Must match the created channel ID
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      color: color,
      autoCancel: true,
    );

    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      notificationId,
      title,
      body,
      platformDetails,
      payload: taskId,
    );
  }
}