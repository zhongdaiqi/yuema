import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/cloud_log_service.dart'; // 引入云日志服务
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:async';

void main() {
  // 设置全局异常捕获，确保在应用启动前就生效
  WidgetsFlutterBinding.ensureInitialized();
  
  // 鸿蒙环境不支持模拟值，移除此调用
  
  // 捕获Flutter框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🐛 Flutter错误: ${details.exception}');
    if (details.stack != null) {
      print('堆栈跟踪: ${details.stack}');
    }
    // 记录Flutter错误到云端
    try {
      CloudLogService().logCrashException(details.exception, details.stack ?? StackTrace.empty);
    } catch (e) {
      print('记录Flutter错误失败: $e');
    }
  };
  
  // 捕获Dart异步异常
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    print('🐛 平台错误: $error');
    print('堆栈跟踪: $stack');
    // 记录平台错误到云端
    try {
      CloudLogService().logCrashException(error, stack);
    } catch (e) {
      print('记录平台错误失败: $e');
    }
    return true; // 防止应用崩溃
  };
  
  // 捕获Dart同步异常
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    print('🐛 Dart错误: $error');
    print('堆栈跟踪: $stack');
    // 记录Dart错误到云端
    try {
      CloudLogService().logCrashException(error, stack);
    } catch (e) {
      print('记录Dart错误失败: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 初始化云日志服务
    final cloudLog = CloudLogService();
    await cloudLog.init();
    await cloudLog.logAppStarted();
    
    // 立即上传本地缓存的日志（可能包含崩溃时未能上传的日志）
    cloudLog.uploadLocalLogsNow();
    
    // 定期上传本地日志
    _scheduleLogUpload(cloudLog);
  }

  // 定期上传本地日志
  void _scheduleLogUpload(CloudLogService cloudLog) {
    // 每30秒尝试上传一次本地日志
    Timer.periodic(const Duration(seconds: 30), (Timer t) async {
      try {
        await cloudLog.uploadLocalLogs();
      } catch (e) {
        print('定期上传本地日志失败: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '约吗',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(), // 启动屏作为首页
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
