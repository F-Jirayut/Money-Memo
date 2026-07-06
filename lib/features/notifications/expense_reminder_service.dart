import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ExpenseReminderService {
  static const _notificationId = 1001;
  static const _channelId = 'money_memo_expense_reminder';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await _initialize();
    await _requestPermission();
    await _notifications.zonedSchedule(
      id: _notificationId,
      scheduledDate: _nextOccurrence(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Expense reminder',
          channelDescription: 'แจ้งเตือนให้บันทึกรายจ่ายประจำวัน',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Money Memo',
      body: 'อย่าลืมบันทึกรายจ่ายวันนี้',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() async {
    await _initialize();
    await _notifications.cancel(id: _notificationId);
  }

  Future<void> showTest() async {
    await _initialize();
    await _requestPermission();
    await _notifications.show(
      id: _notificationId + 1,
      title: 'Money Memo',
      body: 'ตัวอย่างแจ้งเตือนรายจ่าย',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Expense reminder',
          channelDescription: 'แจ้งเตือนให้บันทึกรายจ่ายประจำวัน',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );
    await _notifications.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> _requestPermission() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
