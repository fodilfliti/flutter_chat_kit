# Push notifications

The kit does not send or receive pushes. Your backend sends one when a
message arrives, and your app uses `firebase_messaging` (or any push
plugin) to show it and open the right room. This page lists the pieces the
kit gives you and the mistakes that most chat apps make.

## What the backend sends

Send a notification with a title and body, plus data the app can route on:

```json
{
  "notification": { "title": "Sara", "body": "See you at 8?" },
  "data": { "room_id": "r42", "message_id": "m981" },
  "apns": { "payload": { "aps": { "content-available": 1 } } }
}
```

- Keep the `notification` block. iOS throttles and often drops data-only
  pushes (`content-available` alone), and Android may delay them in Doze.
  A visible alert is the only reliable way to wake the user.
- Do not send a push to the sender, and skip muted rooms on the server.
- Put the unread total in `apns.payload.aps.badge` if you show an icon
  badge on iOS; the app cannot update it while it is killed.

## Tap on a notification

Handle both cases: the app was killed (cold start), or it was in the
background.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
  runApp(const App());
}

// Must be a top-level function, kept in release builds.
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) async {
  // Runs in its own isolate: no ChatKit here. The system already shows
  // the notification; do nothing else unless you must.
}
```

After sign-in, once the kit is open, route the tap:

```dart
final kit = ChatKit(currentUserId: user.id, source: MyChatSource());
await kit.open(); // open first: the room page needs the kit

void openFromPush(RemoteMessage message) {
  final roomId = message.data['room_id'] as String?;
  if (roomId == null) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => RoomPage(roomId: roomId)),
  );
}

// Cold start: the tap that launched the app.
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) openFromPush(initial);

// The app was in the background.
FirebaseMessaging.onMessageOpenedApp.listen(openFromPush);
```

`RoomPage` is the page from the README quick start. It creates a
`ChatRoomController`, which shows the cached messages at once and fetches
the newest page, so the message that triggered the push is on screen even
if the realtime stream is not connected yet.

## While the app is open

Android shows nothing for a push received in the foreground, and iOS shows
it only if you ask. Show your own notification, except for the room the
user is reading:

```dart
FirebaseMessaging.onMessage.listen((message) {
  final roomId = message.data['room_id'];
  if (roomId == kit.activeRoomId.value) return; // already on screen
  showLocalNotification(message); // flutter_local_notifications
});
```

`kit.activeRoomId` is the most recently opened room page that is still
alive, and null on the inbox. It is a `ValueListenable`, so you can also
listen to it, for example to tell your backend which room to stop pushing.

## Badge and unread count

`InboxController.totalUnread` is the unread total of the rooms in that
list (muted rooms excluded). Update the app icon badge from it:

```dart
inbox.addListener(() => AppBadgePlus.updateBadge(inbox.totalUnread));
```

## Catching up

The kit already catches up when the app returns from the background (after
`ChatConfig.resumeResyncAfter`) and when you call `kit.setOnline(true)`.
Call `await kit.refresh()` yourself if a push arrives while the app is open
and you want the inbox current right away. If a push carries a new name or
avatar, apply it with `kit.updateUsers([...])`.
