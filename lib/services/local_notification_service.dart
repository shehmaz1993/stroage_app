import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // Used for Colors

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'transfer_channel_id';
  static const String channelName = 'File Transfers';
  static const String channelDescription = 'Notifications for file uploads and downloads';

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your app icon

    // On iOS, you usually require permission first
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS);

    await notificationsPlugin.initialize(initializationSettings);
  }


  Future<void> showCompletionNotification({
    required String taskId,
    required String fileName,
    required bool isUpload,
    required bool isSuccess,
  }) async {
    final int notificationId = taskId.hashCode; // Use a hash of the ID for uniqueness
    final String type = isUpload ? "Upload" : "Download";
    final String title = "$type ${isSuccess ? 'Complete' : 'Failed'}";
    final String body = "$fileName ${isSuccess ? 'finished successfully.' : 'failed. Tap to retry.'}";
    final Color color = isSuccess ? Colors.green : Colors.red;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      color: color,
      // Setting autoCancel to true means the notification is dismissed when tapped
      autoCancel: true,
    );

    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      notificationId,
      title,
      body,
      platformDetails,
      payload: taskId, // Payload can be used to navigate the user back to the dashboard
    );
  }
}