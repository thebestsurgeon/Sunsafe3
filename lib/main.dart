import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() => runApp(SunSafeApp());

class SunSafeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SunSafe',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double uvIndex = 8.5;
  double temp = 33;
  double humidity = 42;
  int sunMinutes = 0;
  int waterMl = 1200;
  int goalMl = 2000;
  Timer? timer;
  bool inSun = false;
  // GET FREE KEY AT openweathermap.org/api
  final String apiKey = '3e23e2da8baf97d2dc295db2a6f7f3c4';
  final notifications = FlutterLocalNotificationsPlugin();
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    initNotifications();
    getUVData();
  }

  void initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await notifications.initialize(settings);
  }

  void showAlert(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('sunsafe_channel', 'SunSafe Alerts',
          importance: Importance.high),
    );
    await notifications.show(0, title, body, details);
  }

  Future<void> getUVData() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      Position pos = await Geolocator.getCurrentPosition();
      var uviUrl = Uri.parse(
          'https://api.openweathermap.org/data/2.5/uvi?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey');
      var res = await http.get(uviUrl);
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        setState(() {
          uvIndex = (data['value'] as num).toDouble();
        });
      }
    } catch (e) {}
  }

  int getSafeMinutes() {
    if (uvIndex < 3) return 120;
    if (uvIndex < 6) return 60;
    if (uvIndex < 8) return 30;
    if (uvIndex < 11) return 15;
    return 10;
  }

  void toggleSunTimer() {
    setState(() => inSun = !inSun);
    if (inSun) {
      timer = Timer.periodic(Duration(seconds: 10), (t) {
        setState(() => sunMinutes++);
        int safe = getSafeMinutes();
        if (sunMinutes == safe - 5) {
          showAlert('Almost limit', 'UV is $uvIndex - 5 mins left.');
        }
        if (sunMinutes >= safe) {
          showAlert('UV OVEREXPOSURE!', 'Move to shade and hydrate NOW.');
        }
      });
    } else {
      timer?.cancel();
    }
  }

  void addWater(int ml) {
    setState(() {
      waterMl += ml;
      if (waterMl > goalMl) waterMl = goalMl;
    });
  }

  @override
  Widget build(BuildContext context) {
    int safe = getSafeMinutes();
    String uvRisk = uvIndex < 3 ? 'Low' : uvIndex < 6 ? 'Moderate' : uvIndex < 8 ? 'High' : uvIndex < 11 ? 'Very High' : 'Extreme';
    
    Widget page;
    if (currentIndex == 0) {
      page = ListView(padding: EdgeInsets.all(16), children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('UV Index', style: TextStyle(color: Colors.white70)),
            Text('$uvIndex - $uvRisk', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text('Stay protected • Wear SPF 50+', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [Text('Temperature'), Text('${temp.toStringAsFixed(0)}°C', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])))),
          SizedBox(width: 12),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [Text('Humidity'), Text('${humidity.toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])))),
        ]),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => setState(() => currentIndex = 1),
          icon: Icon(Icons.play_arrow),
          label: Text("I'm Outside - Start Monitoring"),
          style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.orange, foregroundColor: Colors.white),
        ),
      ]);
    } else if (currentIndex == 1) {
      page = Padding(
        padding: EdgeInsets.all(24),
        child: Column(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 220, height: 220, child: CircularProgressIndicator(value: (sunMinutes / safe).clamp(0, 1), strokeWidth: 12, color: Colors.orange)),
            Column(children: [
              Text('${(sunMinutes ~/ 60).toString().padLeft(2, '0')}:${(sunMinutes % 60).toString().padLeft(2, '0')}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
              Text('Elapsed Time'),
            ]),
          ]),
          SizedBox(height: 20),
          Text('Safe limit: $safe min • ${(safe - sunMinutes).clamp(0, safe)} min remaining'),
          SizedBox(height: 20),
          ElevatedButton(onPressed: toggleSunTimer, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: Text(inSun ? 'Stop Session' : 'Start Session')),
        ]),
      );
    } else {
      page = ListView(padding: EdgeInsets.all(16), children: [
        Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [
          Text('$waterMl ml / $goalMl ml', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          LinearProgressIndicator(value: waterMl / goalMl, color: Colors.orange),
        ]))),
        SizedBox(height: 16),
        ElevatedButton.icon(onPressed: () => addWater(250), icon: Icon(Icons.add), label: Text('Add Water'), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.orange, foregroundColor: Colors.white)),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: Text('SunSafe'), backgroundColor: Colors.transparent, elevation: 0),
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.orange,
        onTap: (i) => setState(() => currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Timer'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Water'),
        ],
      ),
    );
  }
}
