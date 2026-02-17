import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math' as math;

import 'package:mptrack3/src/constants/color.dart';

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationsService._internal()
      : _plugin = FlutterLocalNotificationsPlugin();

  static NotificationsService getInstance() => _instance;

  Future<void> init() async {
    AndroidInitializationSettings androidInitializationSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    await _plugin.initialize(initializationSettings);
  }

  Future<void> show({required String title, required String body}) async {
    AndroidNotificationDetails adDetails = const AndroidNotificationDetails(
      '_mptrack3_notifications_channel_id',
      'MPTRACK3 NOTIFICATIONS',
      ongoing: true,
      color: AppColors.background,
      colorized: true,
    );

    NotificationDetails notificationDetails =
        NotificationDetails(android: adDetails);
    int id = math.Random().nextInt(1000);

    await _plugin.show(id, title, body, notificationDetails);
    return;
  }
}
