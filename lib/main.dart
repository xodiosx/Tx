// main.dart  --  This file is part of xodos.               
                                                                       
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_pty/flutter_pty.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clipboard/clipboard.dart';
import 'package:file_picker/file_picker.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'backup_restore_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:xodos/l10n/app_localizations.dart';

import 'package:xodos/workflow.dart';
// Add these imports
import 'package:path_provider/path_provider.dart';

import 'workflow.dart';
import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('pt'),
            Locale('ru'),
            Locale('fr'),
            Locale('ja'),
            Locale('hi'),
            Locale('ar'),
            Locale.fromSubtags(languageCode: 'zh'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
              // Customize the dark purple scheme
              primary: Colors.deepPurple[300],
              secondary: Colors.purple[300],
              background: Colors.black, // Black background
              surface: Colors.grey[900], // Dark grey surface
              onBackground: Colors.white,
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            // Additional dark theme customization
            scaffoldBackgroundColor: Colors.black,
            cardColor: Colors.grey[900],
            dialogBackgroundColor: Colors.grey[900],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.deepPurple[300],
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.grey[900],
              selectedItemColor: Colors.deepPurple[300],
              unselectedItemColor: Colors.grey[500],
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: Colors.deepPurple[300],
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: ThemeMode.dark, // Force dark theme
          home: const MyHomePage(title: "Xodos"),
        );
      },
    );
  }
}
// RTL Wrapper for language support
class RTLWrapper extends StatelessWidget {
  final Widget child;
  
  const RTLWrapper({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isRTL = _isRTL(locale);
    
    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    );
  }
  
  bool _isRTL(Locale locale) {
    return locale.languageCode == 'ar' || 
           locale.languageCode == 'he' || 
           locale.languageCode == 'fa' ||
           locale.languageCode == 'ur';
  }
}

//限制最大宽高比1:1
class AspectRatioMax1To1 extends StatelessWidget {
  final Widget child;
  //final double aspectRatio;

  const AspectRatioMax1To1({super.key, required this.child/*, required this.aspectRatio*/});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = MediaQuery.of(context).size;
        //double size = (s.width < s.height * aspectRatio) ? s.width : (s.height * aspectRatio);
        double size = s.width < s.height ? constraints.maxWidth : s.height;

        return Center(
          child: SizedBox(
            width: size,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

// Logcat Manager for system logs
//already in workflow

// Backup/Restore Dialog
//already on workflow

// Wine Settings Dialog
class WineSettingsDialog extends StatefulWidget {
  const WineSettingsDialog({super.key});

  @override
  State<WineSettingsDialog> createState() => _WineSettingsDialogState();
}

class _WineSettingsDialogState extends State<WineSettingsDialog> {
  final TextEditingController _displayController = TextEditingController();
  final TextEditingController _winePrefixController = TextEditingController();
  final TextEditingController _wineArchController = TextEditingController();
  final TextEditingController _wineCommandController = TextEditingController();
  
  bool _wineRunning = false;
  bool _isLoading = true;
  bool _initialized = false;
  bool _winePrefixExists = false;
  bool _creatingWinePrefix = false;
  bool _startingWine = false;
  bool _startingExplorer = false;
  late String _dataPath;
  late String _home;
  Pty? _winePty;
  int _monitorLoopCount = 0;
  static const int _maxMonitorLoops = 10;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _winePty?.kill();
    _displayController.dispose();
    _winePrefixController.dispose();
    _wineArchController.dispose();
    _wineCommandController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    try {
      final context = G.homePageStateContext;
      _dataPath = G.dataPath;
      _home = '$_dataPath/home';
      
      _displayController.text = ':4';
      _winePrefixController.text = '$_home/.wine';
      _wineArchController.text = 'win64';
      _wineCommandController.text = 'xodxx';
      
      await _checkWinePrefixExists();
      await _checkWineProcess();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkWinePrefixExists() async {
    try {
      final winePrefix = _winePrefixController.text;
      final readyFile = File('$winePrefix/.ready');
      
      setState(() {
        _winePrefixExists = readyFile.existsSync();
      });
    } catch (_) {
      setState(() {
        _winePrefixExists = false;
      });
    }
  }
  
  Future<void> _createWinePrefix() async {
    _creatingWinePrefix = true;
    _monitorLoopCount = 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Creating Wine Prefix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Creating Wine prefix, please wait...'),
            const SizedBox(height: 8),
            Text(
              'This may take a few minutes...',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
    
    try {
      if (!_initialized) {
        await _initWinePty();
      }
      
      final createCommand = '''
# Create wine prefix
echo "Creating Wine prefix..."
export WINEPREFIX="${_winePrefixController.text}"
export WINEARCH="${_wineArchController.text}"

# Kill any existing wine processes
pkill -f "wine" 
pkill -f "winhandler.exe" 

xodxx

mkdir -p "${_winePrefixController.text}"
echo "Wine prefix created successfully!"
sleep 3
pkill -f "wine" 
pkill -f "winhandler.exe" 

echo "WinHandler started"
''';
      
      _winePty!.write(Utf8Encoder().convert(createCommand));
      await Future.delayed(const Duration(seconds: 60));
      
      bool winHandlerStarted = await _monitorForWinHandler();
      
      if (mounted) {
        Navigator.of(context).pop();
        
        if (winHandlerStarted) {
          setState(() {
            _winePrefixExists = true;
            _creatingWinePrefix = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wine prefix created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _creatingWinePrefix = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create Wine prefix'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _creatingWinePrefix = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating Wine prefix: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<bool> _monitorForWinHandler() async {
    for (_monitorLoopCount = 0; _monitorLoopCount < _maxMonitorLoops; _monitorLoopCount++) {
      await Future.delayed(const Duration(seconds: 20));
      
      try {
        final result = await Process.run(
          '/system/bin/sh',
          ['-c', 'pgrep -x "winhandler.exe" >/dev/null 2>&1 && echo "RUNNING"'],
          environment: _buildEnvironment(),
        );
        
        if (result.stdout.toString().contains('RUNNING')) {
          return true;
        }
      } catch (_) {}
      
      final readyFile = File('${_winePrefixController.text}/.ready');
      if (readyFile.existsSync()) {
        return true;
      }
    }
    
    return false;
  }
  
  Map<String, String> _buildEnvironment() {
    final env = <String, String>{};
    
    env['PATH'] = '$_dataPath/bin:$_dataPath/usr/bin';
    env['LD_LIBRARY_PATH'] = '$_dataPath/lib:$_dataPath/usr/lib';
    env['HOME'] = _home;
    env['DATA_DIR'] = _dataPath;
    env['PREFIX'] = '$_dataPath/usr';
    env['TMPDIR'] = '$_dataPath/usr/tmp';
    env['XDG_RUNTIME_DIR'] = '$_dataPath/usr/tmp/runtime';
    env['XDG_CACHE_HOME'] = '$_dataPath/usr/tmp/.cache';
    env['DISPLAY'] = _displayController.text;
    env['X11_UNIX_PATH'] = '$_dataPath/usr/tmp/.X11-unix';
    env['WINEPREFIX'] = _winePrefixController.text;
    env['WINEARCH'] = _wineArchController.text;
    env['WINE'] = '$_dataPath/usr/opt/wine/bin/wine';
    env['TERM'] = 'xterm-256color';
    env['LANG'] = 'en_US.UTF-8';
    env['SHELL'] = '$_dataPath/usr/bin/bash';
    env['BOX64_LOG'] = '0';
    env['DXVK_STATE_CACHE'] = '1';
    env['DXVK_LOG_PATH'] = '$_home/.cache';
    env['DXVK_STATE_CACHE_PATH'] = '$_home/.cache';
    env['ANDROID_ROOT'] = '/system';
    env['ANDROID_DATA'] = '/data';
    env['ANDROID_STORAGE'] = '/storage';
    env['EXTERNAL_STORAGE'] = '/sdcard';
    
    return env;
  }
  
  String _buildFullCommand() {
    final envVars = _buildEnvironment();
    final envString = envVars.entries.map((e) => 'export ${e.key}="${e.value}"').join('\n');
    
    return '''
$envString
[ -f $_dataPath/usr/opt/drv ] && . $_dataPath/usr/opt/drv
${_wineCommandController.text}
''';
  }
  
  Future<void> _initWinePty() async {
    if (_initialized && _winePty != null) {
      return;
    }
    
    final envVars = _buildEnvironment();
    
    _winePty = Pty.start(
      '$_dataPath/usr/bin/sh',
      workingDirectory: _home,
      environment: envVars,
    );
    
    final setupCommands = '''
cd $_dataPath
export PATH=\${PATH}:$_dataPath/usr/bin:$_dataPath/bin
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:$_dataPath/lib:$_dataPath/usr/lib
unset LD_LIBRARY_PATH

mkdir -p $_home
mkdir -p $_dataPath/usr/tmp
mkdir -p \${WINEPREFIX}

mkdir -p $_dataPath/usr/tmp/.X11-unix

[ -f $_dataPath/usr/opt/env ] && . $_dataPath/usr/opt/env
[ -f $_dataPath/usr/opt/drv ] && . $_dataPath/usr/opt/drv
[ -f $_dataPath/usr/opt/hud ] && . $_dataPath/usr/opt/hud
[ -f $_dataPath/usr/opt/dyna ] && . $_dataPath/usr/opt/dyna

echo "Wine environment initialized on ${_displayController.text}"
''';
    
    _winePty!.write(Utf8Encoder().convert(setupCommands));
    
    _winePty!.output.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
      print('Wine PTY: $data');
    });
    
    _initialized = true;
  }
  
  void _launchDesktopAfterWine() async {
    Navigator.of(context).pop(true);
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (G.wasX11Enabled) {
        Workflow.launchX11();
      } else if (G.wasAvncEnabled) {
        Workflow.launchAvnc();
      } else {
        Workflow.launchBrowser();
      }
    });
  }
  
  Future<void> _startTaskManager() async {
    await _checkWineProcess();
    Navigator.of(context).pop();

    if (_wineRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wine is already running'),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
    try {
      if (!_initialized) {
        await _initWinePty();
      }
      
      final taskMgrCommand = 'xod taskmgr\n';
      _winePty!.write(Utf8Encoder().convert(taskMgrCommand));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task Manager started'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start Task Manager: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _startWine() async {
    try {
      await _checkWineProcess();
      if (_wineRunning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wine is already running'),
            backgroundColor: Colors.blue,
          ),
        );
        
        _launchDesktopAfterWine();
        return;
      }
      
      await _checkWinePrefixExists();
      
      if (!_winePrefixExists) {
        bool createPrefix = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Wine Prefix Not Found'),
            content: const Text('Wine prefix does not exist. Create it now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ?? false;
        
        if (createPrefix) {
          await _createWinePrefix();
          if (!_winePrefixExists) {
            return;
          }
        } else {
          return;
        }
      }
      
      _startingWine = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Starting Wine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Launching Windows environment...'),
              const SizedBox(height: 8),
              Text(
                'Waiting for Wine to start...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
      
      if (!_initialized) {
        await _initWinePty();
      }
      
      final command = '''
pkill -f "wine" 2>/dev/null || true
pkill -f "winhandler.exe" 2>/dev/null || true
pkill -f ".exe" 2>/dev/null || true

echo "Starting: ${_wineCommandController.text}"
${_wineCommandController.text} 
''';
      
      _winePty!.write(Utf8Encoder().convert(command));
      
      _monitorLoopCount = 0;
      bool winHandlerStarted = await _monitorForWinHandler();
      
      if (mounted) {
        Navigator.of(context).pop();
        
        if (winHandlerStarted) {
          _startingWine = false;
          await _checkWineProcess();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wine started successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _launchDesktopAfterWine();
          
        } else {
          _startingWine = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start Wine (timeout)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _startingWine = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start Wine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error starting wine: $e');
    }
  }
  
  Future<void> _startExplorer() async {
    try {
      await _checkWineProcess();
      if (_wineRunning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wine is already running'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      await _checkWinePrefixExists();
      
      if (!_winePrefixExists) {
        bool createPrefix = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Wine Prefix Not Found'),
            content: const Text('Wine prefix does not exist. Create it now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ?? false;
        
        if (createPrefix) {
          await _createWinePrefix();
          if (!_winePrefixExists) {
            return;
          }
        } else {
          return;
        }
      }
      
      _startingExplorer = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Starting Explorer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Launching Windows Explorer...'),
              const SizedBox(height: 8),
              Text(
                'Waiting for Explorer to start...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      );
      
      if (!_initialized) {
        await _initWinePty();
      }
      
      final command = '''
echo "Starting: xod explorer"
xod $_dataPath/usr/opt/apps/wfm.exe
''';
      
      _winePty!.write(Utf8Encoder().convert(command));
      
      _monitorLoopCount = 0;
      bool winHandlerStarted = await _monitorForWinHandler();
      
      if (mounted) {
        Navigator.of(context).pop();
        
        if (winHandlerStarted) {
          _startingExplorer = false;
          await _checkWineProcess();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Explorer started successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _launchDesktopAfterWine();
        } else {
          _startingExplorer = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start Explorer (timeout)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _startingExplorer = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start Explorer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error starting explorer: $e');
    }
  }
  
  Future<void> _stopWine() async {
    try {
      bool confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop Wine?'),
          content: const Text('This will stop all Wine processes. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Stop'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) return;
      
      try {
        final result = await Process.run(
          '/system/bin/sh',
          ['-c', 'pkill -f "wine" && pkill -f "winhandler.exe" && pkill -f "*.exe"'],
          environment: _buildEnvironment(),
        );
      } catch (_) {}
      
      await Future.delayed(const Duration(seconds: 1));
      await _checkWineProcess();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wine stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {}
  }
  
  Future<void> _checkWineProcess() async {
    try {
      final result = await Process.run(
        '/system/bin/sh',
        ['-c', 'pgrep -x start.exe >/dev/null 2>&1 && echo RUNNING || echo STOPPED'],
        environment: _buildEnvironment(),
      );
      
      final isRunning = result.stdout.toString().trim() == 'RUNNING';
      
      if (mounted) {
        setState(() {
          _wineRunning = isRunning;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _wineRunning = false;
        });
      }
    }
  }
  
  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default?'),
        content: const Text('This will reset all settings to default values. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _displayController.text = ':4';
                _winePrefixController.text = '$_home/.wine';
                _wineArchController.text = 'win64';
                _wineCommandController.text = 'xodxx';
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _testWineConfig() async {
    try {
      if (!_initialized) {
        await _initWinePty();
      }
      
      final testPty = Pty.start(
        '$_dataPath/usr/bin/sh',
        workingDirectory: _home,
        environment: _buildEnvironment(),
      );
      
      String output = '';
      
      testPty.output.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
        output += data;
      });
      
      final cmd = '''
export PATH="$_dataPath/usr/bin:\$PATH"
export LD_LIBRARY_PATH="$_dataPath/usr/lib:\$LD_LIBRARY_PATH"
unset LD_LIBRARY_PATH
export WINEPREFIX="${_winePrefixController.text}"
export WINEARCH="${_wineArchController.text}"
echo "=== Wine Configuration Test ==="
echo "Wine Prefix: \$WINEPREFIX"
echo "Wine Arch: \$WINEARCH"
echo "Display: \$DISPLAY"
echo "\\n=== Checking Wine Prefix ==="
if [ -f "\$WINEPREFIX/.ready" ]; then
  echo "✓ Wine prefix exists and is ready"
else
  echo "✗ Wine prefix not found or not ready"
fi
echo "\\n=== Wine Version ==="
box64 "${_dataPath}/usr/opt/wine/bin/wine" --version 2>&1 || echo "Failed to get wine version"
cat "${_dataPath}/usr/opt/drv"
echo "\\n=== Test Complete ==="
''';
      
      testPty.write(Utf8Encoder().convert(cmd));
      
      await Future.delayed(const Duration(seconds: 3));
      testPty.kill();
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Wine Test Result'),
          content: SingleChildScrollView(
            child: Text(output.isEmpty ? 'No output' : output),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wine test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _editFullCommand() {
    final fullCommand = _buildFullCommand();
    final TextEditingController editController = TextEditingController(text: fullCommand);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit Launcher Command'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit the full launcher command below:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: The actual wine command is the last line',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(minHeight: 200),
                      child: TextFormField(
                        controller: editController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                          hintText: 'Enter full launcher command...',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tip: The command will be saved and used when starting Wine',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final editedCommand = editController.text;
                  final lines = editedCommand.split('\n');
                  String wineCommand = '';
                  
                  for (int i = lines.length - 1; i >= 0; i--) {
                    if (lines[i].trim().isNotEmpty) {
                      wineCommand = lines[i].trim();
                      break;
                    }
                  }
                  
                  _wineCommandController.text = wineCommand;
                  
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Launcher command updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Save Command'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showCommandPreview() {
    final fullCommand = _buildFullCommand();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Command Preview'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            fullCommand,
            style: const TextStyle(
              fontFamily: 'Monospace',
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullCommand));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Command copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        title: Text('Loading Wine Settings...'),
        content: Center(child: CircularProgressIndicator()),
      );
    }
    
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.wine_bar, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Wine Launcher'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: _winePrefixExists ? Colors.green[900] : Colors.orange[900],
                child: ListTile(
                  leading: Icon(
                    _winePrefixExists ? Icons.check_circle : Icons.warning,
                    color: _winePrefixExists ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Wine Prefix Status'),
                  subtitle: Text(_winePrefixExists ? 'Ready' : 'Not Created'),
                  trailing: !_winePrefixExists && !_creatingWinePrefix
                      ? IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: _createWinePrefix,
                          tooltip: 'Create Wine Prefix',
                        )
                      : _creatingWinePrefix
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                color: _wineRunning ? Colors.green[150] : Colors.red[150],
                child: ListTile(
                  leading: Icon(
                    _wineRunning ? Icons.check_circle : Icons.cancel,
                    color: _wineRunning ? Colors.green : Colors.red,
                  ),
                  title: const Text('Wine Status'),
                  subtitle: Text(_wineRunning ? 'Running' : 'Not Running'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _checkWineProcess,
                        tooltip: 'Refresh Status',
                      ),
                      if (_wineRunning)
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.red),
                          onPressed: _stopWine,
                          tooltip: 'Stop Wine',
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wine Configuration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _displayController,
                              decoration: const InputDecoration(
                                labelText: 'DISPLAY',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.display_settings),
                                hintText: ':4',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _wineArchController,
                              decoration: const InputDecoration(
                                labelText: 'Architecture',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.architecture),
                                hintText: 'win64',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _winePrefixController,
                        decoration: const InputDecoration(
                          labelText: 'Wine Prefix',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder),
                          hintText: '/data/data/com.xodos/files/home/.wine',
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _wineCommandController,
                        decoration: const InputDecoration(
                          labelText: 'Wine Command',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.terminal),
                          hintText: 'xod explorer.exe, xod notepad.exe, etc.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit Command'),
                              onPressed: _editFullCommand,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('Preview'),
                              onPressed: _showCommandPreview,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bug_report, size: 18),
                        label: const Text('Test Configuration'),
                        onPressed: _testWineConfig,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        icon: _startingWine
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: _startingWine
                            ? const Text('Starting Wine. Desktop..')
                            : const Text('Start Wine Desktop'),
                        onPressed: _startingWine ? null : _startWine,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      OutlinedButton.icon(
                        icon: const Icon(Icons.task, size: 20),
                        label: const Text('Start Explorer'),
                        onPressed: _startExplorer,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(
                            color: _wineRunning ? Colors.grey : Colors.purple,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      OutlinedButton.icon(
                        icon: const Icon(Icons.task, size: 20),
                        label: const Text('Task Manager'),
                        onPressed: _startTaskManager,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(
                            color: _wineRunning ? Colors.blue : Colors.grey,
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset'),
                              onPressed: _resetToDefault,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Card(
                color: Colors.blue[900],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wine Launcher Information',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• uses wine bionic arm64\n'
                        '• support for native vulkan wrapper/drivers \n'
                        '• support for gamepad using x11\n'
                        '• dri3 and touch controls only with x11 \n'
                        '• Uses X11 socket :4 for display\n'
                        '• More Settings can be adjusted on the Settings',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: const Text('wine'),
                            backgroundColor: Colors.deepPurple[700],
                          ),
                          Chip(
                            label: const Text('bionic'),
                            backgroundColor: Colors.green[700],
                          ),
                          Chip(
                            label: const Text('Box64'),
                            backgroundColor: Colors.purple[700],
                          ),
                          Chip(
                            label: const Text('windows'),
                            backgroundColor: Colors.orange[700],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Save & Close'),
        ),
      ],
    );
  }
}

// DXVK Dialog
class DxvkDialog extends StatefulWidget {
  @override
  _DxvkDialogState createState() => _DxvkDialogState();
}

class _DxvkDialogState extends State<DxvkDialog> {
  String? _selectedDxvk;
  List<String> _dxvkFiles = [];
  String? _dxvkDirectory;
  bool _isLoading = true;
  bool _currentMangohudEnabled = false;
  bool _currentDxvkHudEnabled = false;
  bool _savedMangohudEnabled = false;
  bool _savedDxvkHudEnabled = false;
  String? _savedSelectedDxvk;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
    _loadDxvkFiles();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      _savedMangohudEnabled = G.prefs.getBool('mangohud_enabled') ?? false;
      _savedDxvkHudEnabled = G.prefs.getBool('dxvkhud_enabled') ?? false;
      _savedSelectedDxvk = G.prefs.getString('selected_dxvk');
      
      setState(() {
        _currentMangohudEnabled = _savedMangohudEnabled;
        _currentDxvkHudEnabled = _savedDxvkHudEnabled;
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    await G.prefs.setBool('mangohud_enabled', _currentMangohudEnabled);
    await G.prefs.setBool('dxvkhud_enabled', _currentDxvkHudEnabled);
    if (_selectedDxvk != null) {
      await G.prefs.setString('selected_dxvk', _selectedDxvk!);
    }
  }

  bool get _hasHudChanged {
    return _currentMangohudEnabled != _savedMangohudEnabled ||
           _currentDxvkHudEnabled != _savedDxvkHudEnabled;
  }

  bool get _hasDxvkChanged {
    return _selectedDxvk != null && _selectedDxvk != _savedSelectedDxvk;
  }

  Future<void> _writeHudSettings() async {
    G.pageIndex.value = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/hud");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo '#================================'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (_currentMangohudEnabled) {
      Util.termWrite("echo 'export MANGOHUD=1' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo 'export MANGOHUD_DLSYM=1' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo '# MANGOHUD enabled' >> ${G.dataPath}/usr/opt/hud");
    } else {
      Util.termWrite("echo 'export MANGOHUD=0' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo 'export MANGOHUD_DLSYM=0' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo '# MANGOHUD disabled' >> ${G.dataPath}/usr/opt/hud");
    }
    
    if (_currentDxvkHudEnabled) {
      Util.termWrite("echo 'export DXVK_HUD=fps,version,devinfo' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo '# DXVK HUD enabled' >> ${G.dataPath}/usr/opt/hud");
    } else {
      Util.termWrite("echo 'export DXVK_HUD=0' >> ${G.dataPath}/usr/opt/hud");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo '# DXVK HUD disabled' >> ${G.dataPath}/usr/opt/hud");
    }
    
    Util.termWrite("echo 'HUD settings saved to ${G.dataPath}/usr/opt/hud'");
    await Future.delayed(const Duration(milliseconds: 50));
    Util.termWrite("echo '#================================'");
  }

  Future<void> _extractDxvk() async {
    try {
      if (_selectedDxvk == null || _dxvkDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a DXVK version'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      
      final dxvkPath = '$_dxvkDirectory/$_selectedDxvk';
      final file = File(dxvkPath);
      
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found: $dxvkPath'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      await _savePreferences();
      
      if (_hasHudChanged) {
        await _writeHudSettings();
      }
      
      Navigator.of(context).pop();
      
      G.pageIndex.value = 0;
      await Future.delayed(const Duration(milliseconds: 300));
      
      await _extractDxvkAndRelated();
      
    } catch (e) {
      print('Error in _extractDxvk: $e');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during extraction: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _extractDxvkAndRelated() async {
    if (_hasDxvkChanged && _selectedDxvk != null) {
      await _extractSingleFile(_selectedDxvk!, 'DXVK');
      
      bool isDxvkFile = _selectedDxvk!.toLowerCase().contains('dxvk');
      
      if (isDxvkFile) {
        final vkd3dFiles = await _findRelatedFiles('vkd3d');
        for (final vkd3dFile in vkd3dFiles) {
          await _extractSingleFile(vkd3dFile, 'VKD3D');
        }
        
        final d8vkFiles = await _findRelatedFiles('d8vk');
        for (final d8vkFile in d8vkFiles) {
          await _extractSingleFile(d8vkFile, 'D8VK');
        }
      }
    } else {
      Util.termWrite("echo 'DXVK already installed: $_selectedDxvk'");
      await Future.delayed(const Duration(milliseconds: 50));
      Util.termWrite("echo '#================================'");
    }
  }

  Future<void> _extractSingleFile(String fileName, String fileType) async {
    Util.termWrite("echo '#================================'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'Extracting $fileType: $fileName'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("mkdir -p ${G.dataPath}/home/.wine/drive_c/windows");
    await Future.delayed(const Duration(milliseconds: 50));
    
    String containerPath = "${G.dataPath}/usr/wincomponents/d3d/$fileName";
    
    if (fileName.endsWith('.zip')) {
      Util.termWrite("unzip -o '$containerPath' -d '${G.dataPath}/home/.wine/drive_c/windows'");
    } else if (fileName.endsWith('.7z')) {
      Util.termWrite("7z x '$containerPath' -o'${G.dataPath}/home/.wine/drive_c/windows' -y");
    } else {
      Util.termWrite("tar -xaf '$containerPath' -C '${G.dataPath}/home/.wine/drive_c/windows'");
    }
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo '$fileType extraction complete!'");
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<List<String>> _findRelatedFiles(String pattern) async {
    if (_dxvkDirectory == null) return [];
    
    try {
      final dir = Directory(_dxvkDirectory!);
      final files = await dir.list().toList();
      
      return files
          .where((file) => file is File)
          .map((file) => file.path.split('/').last)
          .where((fileName) => fileName.toLowerCase().contains(pattern.toLowerCase()))
          .where((fileName) => RegExp(r'\.(tzst|tar\.gz|tgz|tar\.xz|txz|tar|zip|7z)$').hasMatch(fileName))
          .toList();
    } catch (e) {
      print('Error finding related files: $e');
      return [];
    }
  }

  Future<void> _loadDxvkFiles() async {
    try {
      String hostDir = "${G.dataPath}/usr/wincomponents/d3d";
      
      final dir = Directory(hostDir);
      if (!await dir.exists()) {
        print('DXVK directory not found at: $hostDir');
        setState(() {
          _dxvkFiles = [];
          _isLoading = false;
        });
        return;
      }
      
      _dxvkDirectory = hostDir;
      
      final files = await dir.list().toList();
      
      final dxvkFiles = files
          .where((file) => file is File && 
              RegExp(r'\.(tzst|tar\.gz|tgz|tar\.xz|txz|tar|zip|7z)$').hasMatch(file.path))
          .map((file) => file.path.split('/').last)
          .toList();
      
      setState(() {
        _dxvkFiles = dxvkFiles;
        if (dxvkFiles.isNotEmpty) {
          _selectedDxvk = _savedSelectedDxvk ?? dxvkFiles.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading DXVK files: $e');
      setState(() {
        _dxvkFiles = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return AlertDialog(
      title: const Text('Install DXVK'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.8 : 0.6),
          minWidth: MediaQuery.of(context).size.width * (isLandscape ? 0.6 : 0.8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoading && _dxvkFiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No DXVK files found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please place DXVK files in:\n/wincomponents/d3d/',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_dxvkDirectory != null)
                        Text(
                          'Directory: $_dxvkDirectory',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
              if (!_isLoading && _dxvkFiles.isNotEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedDxvk,
                      decoration: const InputDecoration(
                        labelText: 'Select DXVK Version',
                        border: OutlineInputBorder(),
                      ),
                      items: _dxvkFiles.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDxvk = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HUD Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          
                          SwitchListTile(
                            dense: isLandscape,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              'MANGOHUD',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Overlay for monitoring FPS, CPU, GPU, etc.',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _currentMangohudEnabled,
                            onChanged: (value) {
                              setState(() {
                                _currentMangohudEnabled = value;
                              });
                            },
                          ),
                          
                          SwitchListTile(
                            dense: isLandscape,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              'DXVK HUD',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: const Text(
                              'DXVK overlay showing FPS, version, device info',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _currentDxvkHudEnabled,
                            onChanged: (value) {
                              setState(() {
                                _currentDxvkHudEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'installing: DXVK, VKD3D, and D8VK files will be Installed together',
                              style: TextStyle(
                                fontSize: isLandscape ? 12 : 14,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_hasHudChanged || _hasDxvkChanged)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasHudChanged && _hasDxvkChanged
                                    ? 'HUD settings and DXVK will be updated'
                                    : _hasHudChanged
                                        ? 'HUD settings will be saved to ${G.dataPath}/usr/opt/hud'
                                        : 'DXVK will be extracted',
                                style: TextStyle(
                                  fontSize: isLandscape ? 12 : 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_dxvkFiles.isNotEmpty && !_isLoading && _selectedDxvk != null)
          ElevatedButton(
            onPressed: _extractDxvk,
            child: const Text('Install'),
          ),
      ],
      scrollable: true,
    );
  }
}

// Environment Dialog
class EnvironmentDialog extends StatefulWidget {
  @override
  _EnvironmentDialogState createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<EnvironmentDialog> {
  final List<Map<String, dynamic>> _dynarecVariables = [
    {"name": "BOX64_DYNAREC_SAFEFLAGS", "values": ["0", "1", "2"], "defaultValue": "2"},
    {"name": "BOX64_DYNAREC_FASTNAN", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "1"},
    {"name": "BOX64_DYNAREC_FASTROUND", "values": ["0", "1", "2"], "defaultValue": "1"},
    {"name": "BOX64_DYNAREC_X87DOUBLE", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "0"},
    {"name": "BOX64_DYNAREC_BIGBLOCK", "values": ["0", "1", "2", "3"], "defaultValue": "1"},
    {"name": "BOX64_DYNAREC_STRONGMEM", "values": ["0", "1", "2", "3"], "defaultValue": "0"},
    {"name": "BOX64_DYNAREC_FORWARD", "values": ["0", "128", "256", "512", "1024"], "defaultValue": "128"},
    {"name": "BOX64_DYNAREC_CALLRET", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "1"},
    {"name": "BOX64_DYNAREC_WAIT", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "1"},
    {"name": "BOX64_DYNAREC_NATIVEFLAGS", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "0"},
    {"name": "BOX64_DYNAREC_WEAKBARRIER", "values": ["0", "1", "2"], "defaultValue": "0"},
    {"name": "BOX64_MMAP32", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "0"},
    {"name": "BOX64_AVX", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "0"},
    {"name": "BOX64_UNITYPLAYER", "values": ["0", "1"], "toggleSwitch": true, "defaultValue": "0"},
  ];

  final Map<String, Map<String, String>> _box64Presets = {
    'Stability': {
      'BOX64_DYNAREC_SAFEFLAGS': '2',
      'BOX64_DYNAREC_FASTNAN': '0',
      'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1',
      'BOX64_DYNAREC_BIGBLOCK': '0',
      'BOX64_DYNAREC_STRONGMEM': '2',
      'BOX64_DYNAREC_FORWARD': '128',
      'BOX64_DYNAREC_CALLRET': '0',
      'BOX64_DYNAREC_WAIT': '0',
      'BOX64_AVX': '0',
      'BOX64_UNITYPLAYER': '1',
      'BOX64_MMAP32': '0',
    },
    'Compatibility': {
      'BOX64_DYNAREC_SAFEFLAGS': '2',
      'BOX64_DYNAREC_FASTNAN': '0',
      'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1',
      'BOX64_DYNAREC_BIGBLOCK': '0',
      'BOX64_DYNAREC_STRONGMEM': '1',
      'BOX64_DYNAREC_FORWARD': '128',
      'BOX64_DYNAREC_CALLRET': '0',
      'BOX64_DYNAREC_WAIT': '1',
      'BOX64_AVX': '0',
      'BOX64_UNITYPLAYER': '1',
      'BOX64_MMAP32': '0',
    },
    'Intermediate': {
      'BOX64_DYNAREC_SAFEFLAGS': '2',
      'BOX64_DYNAREC_FASTNAN': '1',
      'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1',
      'BOX64_DYNAREC_BIGBLOCK': '1',
      'BOX64_DYNAREC_STRONGMEM': '0',
      'BOX64_DYNAREC_FORWARD': '128',
      'BOX64_DYNAREC_CALLRET': '1',
      'BOX64_DYNAREC_WAIT': '1',
      'BOX64_AVX': '0',
      'BOX64_UNITYPLAYER': '0',
      'BOX64_MMAP32': '1',
    },
  };

  List<bool> _coreSelections = [];
  int _availableCores = 8;
  bool _wineEsyncEnabled = false;
  List<Map<String, String>> _customVariables = [];
  String _selectedKnownVariable = '';
  final List<String> _knownWineVariables = [
    'WINEARCH',
    'DXVK_ASYNC',
    'adrenotool',
    'GALLIUM_DRIVER',
    'MESA_VK_WSI_PRESENT_MODE',
    'MESA_LOADER_DRIVER_OVERRIDE',
    'VK_LOADER_DEBUG',
    'LD_DEBUG',
    'ZINK_DEBUG',
    'WINEDEBUG',
    'MESA_VK_WSI_PRESENT_MODE',
    'WINEPREFIX',
    'WINEESYNC',
    'WINEFSYNC',
    'WINE_NOBLOB',
    'WINE_NO_CRASH_DIALOG',
    'WINEDLLOVERRIDES',
    'WINEDLLPATH',
    'WINE_MONO_CACHE_DIR',
    'WINE_GECKO_CACHE_DIR',
    'WINEDISABLE',
    'WINE_ENABLE'
  ];
  
  bool _debugEnabled = false;
  String _winedebugValue = '-all';
  final List<String> _winedebugOptions = [
    '-all', 'err', 'warn', 'fixme', 'all', 'trace', 'message', 'heap', 'fps', 'dx9', 'dx8'
  ];
  
  String _newVarName = '';
  String _newVarValue = '';

  @override
  void initState() {
    super.initState();
    _initializeCores();
    _loadSavedSettings();
  }

  Future<void> _initializeCores() async {
    try {
      _availableCores = Platform.numberOfProcessors;
      
      setState(() {
        _coreSelections = List.generate(_availableCores, (index) => true);
      });
    } catch (e) {
      print('Error getting CPU count: $e');
      _availableCores = 8;
      _coreSelections = List.generate(8, (index) => true);
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      final savedCores = G.prefs.getString('environment_cores');
      if (savedCores != null && savedCores.isNotEmpty) {
        _parseCoreSelections(savedCores);
      } else {
        setState(() {
          _coreSelections = List.generate(_availableCores, (index) => true);
        });
      }
      
      _wineEsyncEnabled = G.prefs.getBool('environment_wine_esync') ?? false;
      _debugEnabled = G.prefs.getBool('environment_debug') ?? false;
      _winedebugValue = G.prefs.getString('environment_winedebug') ?? '-all';
      
      final savedVars = G.prefs.getStringList('environment_custom_vars') ?? [];
      _customVariables = savedVars.map((varStr) {
        final parts = varStr.split('=');
        return {'name': parts[0], 'value': parts.length > 1 ? parts[1] : ''};
      }).toList();
      
      setState(() {});
    } catch (e) {
      print('Error loading environment settings: $e');
    }
  }

  void _parseCoreSelections(String coreString) {
    try {
      _coreSelections = List.generate(_availableCores, (index) => false);
      
      if (coreString.contains(',')) {
        final selectedIndices = coreString.split(',');
        for (final indexStr in selectedIndices) {
          final index = int.tryParse(indexStr);
          if (index != null && index < _availableCores) {
            _coreSelections[index] = true;
          }
        }
      } else if (coreString.contains('-')) {
        final parts = coreString.split('-');
        final start = int.tryParse(parts[0]) ?? 0;
        final end = int.tryParse(parts[1]) ?? (_availableCores - 1);
        
        for (int i = start; i <= end && i < _availableCores; i++) {
          _coreSelections[i] = true;
        }
      }
    } catch (e) {
      print('Error parsing core selections: $e');
    }
  }

  String _getCoreString() {
    final selectedIndices = <int>[];
    for (int i = 0; i < _availableCores; i++) {
      if (_coreSelections[i]) {
        selectedIndices.add(i);
      }
    }
    
    if (selectedIndices.isEmpty) {
      return "0";
    }
    
    return selectedIndices.join(',');
  }

  Future<void> _saveSettings() async {
    try {
      await G.prefs.setString('environment_cores', _getCoreString());
      await G.prefs.setBool('environment_wine_esync', _wineEsyncEnabled);
      await G.prefs.setBool('environment_debug', _debugEnabled);
      await G.prefs.setString('environment_winedebug', _winedebugValue);
      
      final varStrings = _customVariables.map((varMap) => '${varMap['name']}=${varMap['value']}').toList();
      await G.prefs.setStringList('environment_custom_vars', varStrings);
      
      for (final variable in _dynarecVariables) {
        final name = variable['name'] as String;
        final currentValue = variable['currentValue'] ?? variable['defaultValue'];
        await G.prefs.setString('dynarec_$name', currentValue);
      }
      
      await _applyEnvironmentSettings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Environment settings saved and applied!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
      
    } catch (e) {
      print('Error saving environment settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _applyEnvironmentSettings() async {
    G.pageIndex.value = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/dyna");
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/sync");
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/cores");
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/env");
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/dbg");
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/hud");
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    for (final variable in _dynarecVariables) {
      final name = variable['name'] as String;
      final defaultValue = variable['defaultValue'] as String;
      final savedValue = G.prefs.getString('dynarec_$name') ?? defaultValue;
      
      Util.termWrite("echo 'export $name=$savedValue' >> ${G.dataPath}/usr/opt/dyna");
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    if (_wineEsyncEnabled) {
      Util.termWrite("echo 'export WINEFSYNC=1' >> ${G.dataPath}/usr/opt/sync");
      Util.termWrite("echo 'export WINEESYNC_TERMUX=1' >> ${G.dataPath}/usr/opt/sync");
    } else {
      Util.termWrite("echo 'export WINEFSYNC=0' >> ${G.dataPath}/usr/opt/sync");
      Util.termWrite("echo 'export WINEESYNC_TERMUX=0' >> ${G.dataPath}/usr/opt/sync");
    }
    
    Util.termWrite("echo 'export PRIMARY_CORES=${_getCoreString()}' >> ${G.dataPath}/usr/opt/cores");
    
    for (final variable in _customVariables) {
      Util.termWrite("echo 'export ${variable['name']}=${variable['value']}' >> ${G.dataPath}/usr/opt/env");
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    if (_debugEnabled) {
      Util.termWrite("echo 'export MESA_NO_ERROR=0' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export WINEDEBUG=$_winedebugValue' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_LOG=1' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_NOBANNER=0' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_SHOWSEGV=1' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_DLSYM_ERROR=1' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_DYNAREC_MISSING=1' >> ${G.dataPath}/usr/opt/dbg");
    } else {
      Util.termWrite("echo 'export MESA_NO_ERROR=1' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export WINEDEBUG=$_winedebugValue' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_LOG=0' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_NOBANNER=1' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_SHOWSEGV=0' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_DLSYM_ERROR=0' >> ${G.dataPath}/usr/opt/dbg");
      Util.termWrite("echo 'export BOX64_DYNAREC_MISSING=0' >> ${G.dataPath}/usr/opt/dbg");
    }
    
    Util.termWrite("echo '#================================'");
    Util.termWrite("echo 'Environment settings applied!'");
    Util.termWrite("echo '#================================'");
  }

  void _showDynarecDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final localVariables = _dynarecVariables.map((variable) {
          final name = variable['name'] as String;
          final defaultValue = variable['defaultValue'] as String;
          final savedValue = G.prefs.getString('dynarec_$name') ?? defaultValue;
          return {
            'name': name,
            'values': variable['values'],
            'defaultValue': defaultValue,
            'toggleSwitch': variable['toggleSwitch'] ?? false,
            'currentValue': savedValue,
          };
        }).toList();

        String selectedPreset = 'Custom';

        return StatefulBuilder(
          builder: (context, setState) {
            void _updatePresetSelection() {
              for (final presetName in _box64Presets.keys) {
                final preset = _box64Presets[presetName]!;
                bool matches = true;
                
                for (final variable in localVariables) {
                  final name = variable['name'] as String;
                  final currentValue = variable['currentValue'] as String;
                  
                  if (preset.containsKey(name) && preset[name] != currentValue) {
                    matches = false;
                    break;
                  }
                }
                
                if (matches) {
                  selectedPreset = presetName;
                  return;
                }
              }
              selectedPreset = 'Custom';
            }

            _updatePresetSelection();

            return AlertDialog(
              title: const Text('Box64 Dynarec Settings'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preset',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: selectedPreset,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: 'Custom',
                                    child: Text('Custom'),
                                  ),
                                  ..._box64Presets.keys.map((presetName) {
                                    return DropdownMenuItem<String>(
                                      value: presetName,
                                      child: Text(presetName),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      selectedPreset = newValue;
                                      
                                      if (newValue != 'Custom') {
                                        final preset = _box64Presets[newValue]!;
                                        
                                        for (final variable in localVariables) {
                                          final name = variable['name'] as String;
                                          if (preset.containsKey(name)) {
                                            variable['currentValue'] = preset[name]!;
                                          }
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      ...localVariables.map((variable) {
                        return _buildDynarecVariableWidget(
                          variable, 
                          setState,
                          localVariables,
                          onVariableChanged: () {
                            setState(() {
                              selectedPreset = 'Custom';
                            });
                          }
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    for (final variable in localVariables) {
                      final name = variable['name'] as String;
                      final currentValue = variable['currentValue'] as String;
                      await G.prefs.setString('dynarec_$name', currentValue);
                    }
                    
                    for (final localVar in localVariables) {
                      final index = _dynarecVariables.indexWhere((v) => v['name'] == localVar['name']);
                      if (index != -1) {
                        _dynarecVariables[index]['currentValue'] = localVar['currentValue'];
                      }
                    }
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDynarecVariableWidget(
    Map<String, dynamic> variable, 
    StateSetter setState,
    List<Map<String, dynamic>> localVariables, {
    VoidCallback? onVariableChanged,
  }) {
    final name = variable['name'] as String;
    final values = variable['values'] as List<String>;
    final isToggle = variable['toggleSwitch'] == true;
    final currentValue = variable['currentValue'] as String;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isToggle)
              SwitchListTile(
                title: Text('Enabled (${currentValue == "1" ? "ON" : "OFF"})'),
                value: currentValue == "1",
                onChanged: (value) {
                  setState(() {
                    variable['currentValue'] = value ? "1" : "0";
                    onVariableChanged?.call();
                  });
                },
              )
            else
              DropdownButton<String>(
                value: currentValue,
                isExpanded: true,
                items: values.map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      variable['currentValue'] = newValue;
                      onVariableChanged?.call();
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addCustomVariable() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Environment Variable'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _knownWineVariables.where(
                    (variable) => variable.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                  );
                },
                fieldViewBuilder: (
                  context,
                  textEditingController,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Variable Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _newVarName = value;
                    },
                  );
                },
                onSelected: (String selection) {
                  _newVarName = selection;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _newVarValue = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_newVarName.isNotEmpty && _newVarValue.isNotEmpty) {
                setState(() {
                  _customVariables.add({
                    'name': _newVarName,
                    'value': _newVarValue,
                  });
                  _newVarName = '';
                  _newVarValue = '';
                });
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both variable name and value'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeCustomVariable(int index) {
    setState(() {
      _customVariables.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Environment Settings'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  title: const Text('Box64 Dynarec'),
                  subtitle: const Text('Advanced emulation settings'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: _showDynarecDialog,
                ),
              ),
              const SizedBox(height: 8),
              
              Card(
                child: SwitchListTile(
                  title: const Text('Wine Fsync'),
                  subtitle: const Text('Enable Wine Fsync for better performance'),
                  value: _wineEsyncEnabled,
                  onChanged: (value) {
                    setState(() {
                      _wineEsyncEnabled = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CPU Cores',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Available CPUs: $_availableCores'),
                      Text('Selected: ${_getCoreString()}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_availableCores, (index) {
                          return FilterChip(
                            label: Text('CPU$index'),
                            selected: _coreSelections[index],
                            onSelected: (selected) {
                              setState(() {
                                _coreSelections[index] = selected;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _coreSelections = List.generate(_availableCores, (index) => true);
                              });
                            },
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _coreSelections = List.generate(_availableCores, (index) => false);
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Variables',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._customVariables.asMap().entries.map((entry) {
                        final index = entry.key;
                        final variable = entry.value;
                        return ListTile(
                          title: Text(variable['name'] ?? ''),
                          subtitle: Text(variable['value'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeCustomVariable(index),
                          ),
                          dense: true,
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _addCustomVariable,
                        child: const Text('Add Variable'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Debug Mode'),
                        subtitle: _debugEnabled
                            ? const Text('Verbose logging enabled')
                            : const Text('Quiet mode - minimal logging'),
                        value: _debugEnabled,
                        onChanged: (value) {
                          setState(() {
                            _debugEnabled = value;
                          });
                        },
                      ),
                      if (_debugEnabled) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'WINEDEBUG Level',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _winedebugValue,
                          decoration: const InputDecoration(
                            labelText: 'WINEDEBUG',
                            border: OutlineInputBorder(),
                          ),
                          items: _winedebugOptions.map((option) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _winedebugValue = value ?? '-all';
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}

// GPU Drivers Dialog
class GpuDriversDialog extends StatefulWidget {
  @override
  _GpuDriversDialogState createState() => _GpuDriversDialogState();
}

class _GpuDriversDialogState extends State<GpuDriversDialog> {
  String _selectedDriverType = 'wrapper';
  String? _selectedDriverFile;
  List<String> _driverFiles = [];
  String? _driversDirectory;
  bool _isLoading = true;
  
  // DRI3 switches
  bool _turnipDri3Enabled = false;
  bool _wrapperDri3Enabled = false;
  bool _venusDri3Enabled = false;
  bool _virglEnabled = false;
  
  // Venus settings
  bool _androidVenusEnabled = true;
  String _defaultTurnipOpt = 'MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform';
  String _defaultVenusCommand = '--no-virgl --venus --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
  String _defaultVenusOpt = '';
  String _defaultVirglCommand = '--use-egl-surfaceless --use-gles --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
  String _defaultVirglOpt = 'GALLIUM_DRIVER=virpipe';
  bool _isX11Enabled = false;
  
  // Server status
  bool _virglServerRunning = false;
  bool _venusServerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _loadDriverFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServerStatus();
    });
  }

  Future<void> _checkServerStatus() async {
    await _updateVirglServerStatus();
    await _updateVenusServerStatus();
  }

  Future<void> _updateVirglServerStatus() async {
    try {
      final result = await Process.run(
        '${G.dataPath}/usr/bin/sh',
        [
          '-c',
          '${G.dataPath}/usr/bin/pgrep -a virgl_ |'
          ' grep use-'
        ],
      );

      final output = result.stdout.toString().trim();
      
      setState(() {
        _virglServerRunning = output.isNotEmpty;
      });
    } catch (e) {
      print('Error checking VirGL server status: $e');
      setState(() {
        _virglServerRunning = false;
      });
    }
  }

  Future<void> _updateVenusServerStatus() async {
    try {
      final result = await Process.run(
        '${G.dataPath}/usr/bin/sh',
        [
          '-c',
          '${G.dataPath}/usr/bin/pgrep -a virgl_ |'
          ' grep venus'
        ],
      );

      final output = result.stdout.toString().trim();
      
      setState(() {
        _venusServerRunning = output.isNotEmpty;
      });
    } catch (e) {
      print('Error checking Venus server status: $e');
      setState(() {
        _venusServerRunning = false;
      });
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      _turnipDri3Enabled = G.prefs.getBool('turnip_dri3') ?? false;
      _wrapperDri3Enabled = G.prefs.getBool('wrapper_dri3') ?? false;
      _venusDri3Enabled = G.prefs.getBool('venus_dri3') ?? false;
      _virglEnabled = G.prefs.getBool('virgl') ?? false;
      _isX11Enabled = G.prefs.getBool('useX11') ?? false;
      _androidVenusEnabled = G.prefs.getBool('androidVenus') ?? true;
      
      String savedTurnipOpt = G.prefs.getString('defaultTurnipOpt') ?? 'MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform';
      _defaultTurnipOpt = _removeVkIcdFromEnvString(savedTurnipOpt);
      
      if (_defaultTurnipOpt.isEmpty) {
        _defaultTurnipOpt = 'MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform';
      }
      
      _defaultVenusCommand = G.prefs.getString('defaultVenusCommand') ?? '--no-virgl --venus --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
      _defaultVenusOpt = G.prefs.getString('defaultVenusOpt') ?? ' ANDROID_VENUS=1';
      _defaultVirglCommand = G.prefs.getString('defaultVirglCommand') ?? '--use-egl-surfaceless --use-gles --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
      _defaultVirglOpt = G.prefs.getString('defaultVirglOpt') ?? 'GALLIUM_DRIVER=virpipe';
      
      _selectedDriverType = G.prefs.getString('gpu_driver_type') ?? 'wrapper';
      _selectedDriverFile = G.prefs.getString('selected_gpu_driver');
      
      setState(() {});
    } catch (e) {
      print('Error loading GPU settings: $e');
    }
  }

  String _removeVkIcdFromEnvString(String envString) {
    List<String> envVars = envString.split(' ');
    envVars.removeWhere((varStr) => varStr.trim().startsWith('VK_ICD_FILENAMES='));
    return envVars.join(' ').trim();
  }

  Future<void> _saveAndExtract() async {
    try {
      await G.prefs.setString('gpu_driver_type', _selectedDriverType);
      if (_selectedDriverFile != null) {
        await G.prefs.setString('selected_gpu_driver', _selectedDriverFile!);
      }
      
      await G.prefs.setBool('turnip_dri3', _turnipDri3Enabled);
      await G.prefs.setBool('wrapper_dri3', _wrapperDri3Enabled);
      await G.prefs.setBool('venus_dri3', _venusDri3Enabled);
      await G.prefs.setBool('virgl', _virglEnabled);
      await G.prefs.setBool('androidVenus', _androidVenusEnabled);
      
      String cleanTurnipOpt = _removeVkIcdFromEnvString(_defaultTurnipOpt);
      if (cleanTurnipOpt.isEmpty) {
        cleanTurnipOpt = 'MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform';
      }
      await G.prefs.setString('defaultTurnipOpt', cleanTurnipOpt);
      
      await G.prefs.setString('defaultVenusCommand', _defaultVenusCommand);
      await G.prefs.setString('defaultVenusOpt', _defaultVenusOpt);
      await G.prefs.setString('defaultVirglCommand', _defaultVirglCommand);
      await G.prefs.setString('defaultVirglOpt', _defaultVirglOpt);
      
      G.pageIndex.value = 0;
      await Future.delayed(const Duration(milliseconds: 300));
      
      if ((_selectedDriverType == 'turnip' || _selectedDriverType == 'wrapper') && 
          _selectedDriverFile != null) {
        await _extractDriver();
      } else {
        await _applyGpuSettings();
      }
      
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPU driver settings saved and applied!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving GPU settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _applyGpuSettings() async {
    G.pageIndex.value = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    
    Util.termWrite("echo '' >${G.dataPath}/usr/opt/drv");
    
    if (_selectedDriverType == 'turnip') {
      await _applyTurnipSettings();
    } else if (_selectedDriverType == 'venus') {
      await _applyVenusSettings();
    } else if (_selectedDriverType == 'virgl') {
      await _applyVirglSettings();
    } else if (_selectedDriverType == 'wrapper') {
      await _applyWrapperSettings();
    }
    
    Util.termWrite("echo '#================================'");
    Util.termWrite("echo 'GPU driver settings applied!'");
    Util.termWrite("echo '#================================'");
  }

  Future<void> _applyTurnipSettings() async {
    Util.termWrite("echo 'export VK_ICD_FILENAMES=${G.dataPath}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' >> ${G.dataPath}/usr/opt/drv");
    
    String cleanTurnipOpt = _removeVkIcdFromEnvString(_defaultTurnipOpt);
    if (cleanTurnipOpt.isNotEmpty) {
      Util.termWrite("echo 'export $cleanTurnipOpt' >> ${G.dataPath}/usr/opt/drv");
    }
    
    if (!_turnipDri3Enabled) {
      Util.termWrite("echo 'export MESA_VK_WSI_DEBUG=sw' >> ${G.dataPath}/usr/opt/drv");
    }
  }

  Future<void> _applyVenusSettings() async {
    String venusEnv = _defaultVenusOpt;
    
    if (_androidVenusEnabled) {
      venusEnv = venusEnv.replaceAll('ANDROID_VENUS=0', 'ANDROID_VENUS=1');
      if (!venusEnv.contains('ANDROID_VENUS=1')) {
        venusEnv = '$venusEnv ANDROID_VENUS=1';
      }
    } else {
      venusEnv = venusEnv.replaceAll('ANDROID_VENUS=1', 'ANDROID_VENUS=0');
    }
    
    Util.termWrite("echo 'export $venusEnv' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!_venusDri3Enabled) {
      Util.termWrite("echo 'export MESA_VK_WSI_DEBUG=sw' >> ${G.dataPath}/usr/opt/drv");
    }
  }

  Future<void> _applyVirglSettings() async {
    Util.termWrite("echo 'export $_defaultVirglOpt' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _applyWrapperSettings() async {
    Util.termWrite("echo '' > ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo '#================================' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo '# Wrapper driver configuration' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'export VK_ICD_FILENAMES=${G.dataPath}/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'export TU_DEBUG=noconform' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!_wrapperDri3Enabled) {
      Util.termWrite("echo 'export MESA_VK_WSI_DEBUG=sw' >> ${G.dataPath}/usr/opt/drv");
    }
    
    Util.termWrite("echo '#================================' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'Wrapper driver configuration complete'");
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _startVirglServer() async {
    G.pageIndex.value = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    
    Util.termWrite("pkill -f virgl_test_server");
    await Future.delayed(const Duration(milliseconds: 100));
    
    Util.termWrite("echo '#================================'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'Starting VirGL server...'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("mkdir -p ${G.dataPath}/usr/tmp/.virgl_test");
    await Future.delayed(const Duration(milliseconds: 50));
    
    String containerDir = "${G.dataPath}/containers/${G.currentContainer}";
    
    String processedCommand = _defaultVirglCommand.replaceAll('\$CONTAINER_DIR', containerDir);
    
    Util.termWrite("echo 'Container directory: $containerDir'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("${G.dataPath}/usr/bin/virgl_test_server $processedCommand &");    
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("export GALLIUM_DRIVER=virpipe ");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("sleep 1 && if pgrep -f virgl_test_server > /dev/null; then echo 'VirGL server started successfully'; else echo 'Failed to start VirGL server'; fi");
    
    await Future.delayed(const Duration(milliseconds: 50));
    Util.termWrite("echo '#================================'");
    
    await Future.delayed(const Duration(seconds: 1));
    await _updateVirglServerStatus();
  }

  Future<void> _startVenusServer() async {
    G.pageIndex.value = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    
    Util.termWrite("pkill -f virgl_test_server");
    await Future.delayed(const Duration(milliseconds: 100));
    
    Util.termWrite("echo '#================================'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'Starting Venus server...'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("mkdir -p ${G.dataPath}/usr/tmp/");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("rm -rf ${G.dataPath}/usr/tmp/.virgl_test");
    await Future.delayed(const Duration(milliseconds: 50));
    
    String containerDir = "${G.dataPath}/containers/${G.currentContainer}";
    
    String processedCommand = _defaultVenusCommand.replaceAll('\$CONTAINER_DIR', containerDir);
    
    Util.termWrite("echo 'Container directory: $containerDir'");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'export VK_ICD_FILENAMES=${G.dataPath}/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));

    String androidVenusEnv = _androidVenusEnabled ? "ANDROID_VENUS=1 " : "";
 
    Util.termWrite(". /data/data/com.xodos/files/usr/opt/drv");    
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("$androidVenusEnv ${G.dataPath}/usr/bin/virgl_test_server $processedCommand &");    
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("echo 'VK_ICD_FILENAMES=${G.dataPath}/usr/share/vulkan/icd.d/virtio_icd.aarch64.json' >> ${G.dataPath}/usr/opt/drv");
    await Future.delayed(const Duration(milliseconds: 50));
    
    Util.termWrite("export VN_DEBUG=vtest");  
    await Future.delayed(const Duration(milliseconds: 50));
  
    Util.termWrite("echo '#================================'");
          
    await Future.delayed(const Duration(seconds: 1));
    await _updateVenusServerStatus();
  }

  Future<void> _extractDriver() async {
    try {
      if (_selectedDriverFile == null || _driversDirectory == null) {
        throw Exception('Please select a driver file');
      }
      
      final driverPath = '$_driversDirectory/$_selectedDriverFile';
      final file = File(driverPath);
      
      if (!await file.exists()) {
        throw Exception('File not found: $driverPath');
      }
      
      G.pageIndex.value = 0;
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      Util.termWrite("echo '#================================'");
      await Future.delayed(const Duration(milliseconds: 50));
      
      Util.termWrite("echo 'Extracting GPU driver: $_selectedDriverFile'");
      await Future.delayed(const Duration(milliseconds: 50));
      
      Util.termWrite("echo '#================================'");
      await Future.delayed(const Duration(milliseconds: 50));
      
      Util.termWrite("mkdir -p ${G.dataPath}/usr/share/vulkan/icd.d");
      await Future.delayed(const Duration(milliseconds: 50));
      
      String containerPath = "${G.dataPath}/usr/drivers/files/$_selectedDriverFile";
      
      if (_selectedDriverFile!.endsWith('.zip')) {
        Util.termWrite("unzip -o '$containerPath' -d '${G.dataPath}/usr'");
      } else if (_selectedDriverFile!.endsWith('.7z')) {
        Util.termWrite("7z x '$containerPath' -o'${G.dataPath}/usr' -y");
      } else if (_selectedDriverFile!.endsWith('.tar.gz') || _selectedDriverFile!.endsWith('.tgz')) {
        Util.termWrite("tar -xzf '$containerPath' -C '${G.dataPath}/usr'");
      } else if (_selectedDriverFile!.endsWith('.tar.xz') || _selectedDriverFile!.endsWith('.txz')) {
        Util.termWrite("tar -xJf '$containerPath' -C '${G.dataPath}/usr'");
      } else if (_selectedDriverFile!.endsWith('.json')) {
        Util.termWrite("cp '$containerPath' '${G.dataPath}/usr/share/vulkan/icd.d/'");
      } else {
        Util.termWrite("tar -xf '$containerPath' -C '${G.dataPath}/usr'");
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      if (_selectedDriverType == 'turnip' && _selectedDriverFile!.endsWith('.json')) {
        Util.termWrite("mv '${G.dataPath}/usr/share/vulkan/icd.d/$_selectedDriverFile' "
                      "'${G.dataPath}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json'");
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await _applyGpuSettings();
      
    } catch (e) {
      print('Error in _extractDriver: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extracting driver: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadDriverFiles() async {
    try {
      String hostDir = "${G.dataPath}/usr/drivers/files";
      
      final dir = Directory(hostDir);
      if (!await dir.exists()) {
        print('Drivers directory not found at: $hostDir');
        setState(() {
          _driverFiles = [];
          _driversDirectory = hostDir;
          _isLoading = false;
        });
        return;
      }
      
      _driversDirectory = hostDir;
      
      final files = await dir.list().toList();
      
      final allDriverFiles = files
          .where((file) => file is File && 
              RegExp(r'\.(tzst|tar\.gz|tgz|tar\.xz|txz|tar|zip|7z|json|so|ko)$').hasMatch(file.path))
          .map((file) => file.path.split('/').last)
          .toList();
      
      setState(() {
        _driverFiles = allDriverFiles;
        if (allDriverFiles.isNotEmpty) {
          _selectedDriverFile = G.prefs.getString('selected_gpu_driver');
          
          if (_selectedDriverFile == null) {
            _filterDriverFiles();
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading driver files: $e');
      setState(() {
        _driverFiles = [];
        _isLoading = false;
      });
    }
  }

  void _filterDriverFiles() {
    List<String> filteredFiles = [];
    
    if (_selectedDriverType == 'turnip') {
      filteredFiles = _driverFiles.where((file) => 
          file.toLowerCase().contains('turnip') ||
          file.toLowerCase().contains('freedreno') ||
          file.endsWith('.json')).toList();
    } else if (_selectedDriverType == 'wrapper') {
      filteredFiles = _driverFiles.where((file) => 
          file.toLowerCase().contains('wrapper')).toList();
    }
    
    if (filteredFiles.isNotEmpty) {
      setState(() {
        _selectedDriverFile = filteredFiles.first;
      });
    }
  }

  void _onDriverTypeChanged(String? newType) {
    if (newType != null) {
      setState(() {
        _selectedDriverType = newType;
        _selectedDriverFile = null;
        _filterDriverFiles();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GPU Drivers'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Driver Type',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDriverType,
                        decoration: const InputDecoration(
                          labelText: 'Select Driver Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'virgl',
                            child: Row(
                              children: [
                                Icon(Icons.hardware, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('VirGL (Virtual GL)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'turnip',
                            child: Row(
                              children: [
                                Icon(Icons.grain, color: Colors.purple),
                                SizedBox(width: 8),
                                Text('Turnip (Vulkan)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'venus',
                            child: Row(
                              children: [
                                Icon(Icons.hardware, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Venus (Vulkan)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'wrapper',
                            child: Row(
                              children: [
                                Icon(Icons.wrap_text, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Wrapper'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: _onDriverTypeChanged,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              if (_selectedDriverType == 'venus')
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Experimental Feature Under Development',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Venus driver is currently in development. Features may be unstable or incomplete.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              if (_selectedDriverType == 'virgl')
                Card(
                  color: _virglServerRunning ? Colors.green[50] : Colors.red[50],
                  child: ListTile(
                    leading: Icon(
                      _virglServerRunning ? Icons.check_circle : Icons.error,
                      color: _virglServerRunning ? Colors.green : Colors.red,
                    ),
                    title: const Text('VirGL Server'),
                    subtitle: Text(
                      _virglServerRunning ? 'Running' : 'Not running',
                      style: TextStyle(
                        color: _virglServerRunning ? Colors.green : Colors.red,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            _startVirglServer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Restarting VirGL server...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: _virglServerRunning ? () async {
                            Util.termWrite("pkill -f virgl_test_server");
                            await Future.delayed(const Duration(seconds: 1));
                            await _updateVirglServerStatus();
                          } : null,
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (_selectedDriverType == 'venus')
                Card(
                  color: _venusServerRunning ? Colors.green[50] : Colors.red[50],
                  child: ListTile(
                    leading: Icon(
                      _venusServerRunning ? Icons.check_circle : Icons.error,
                      color: _venusServerRunning ? Colors.green : Colors.red,
                    ),
                    title: const Text('Venus Server'),
                    subtitle: Text(
                      _venusServerRunning ? 'Running' : 'Not running',
                      style: TextStyle(
                        color: _venusServerRunning ? Colors.green : Colors.red,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            _startVenusServer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Restarting Venus server...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: _venusServerRunning ? () async {
                            Util.termWrite("pkill -f virgl_test_server");
                            await Future.delayed(const Duration(seconds: 1));
                            await _updateVenusServerStatus();
                          } : null,
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              if (_selectedDriverType == 'wrapper' || _selectedDriverType == 'turnip')
                _buildDriverFileSelection(),
              
              if (_selectedDriverType == 'turnip') _buildTurnipSettings(),
              if (_selectedDriverType == 'virgl') _buildVirglSettings(),
              if (_selectedDriverType == 'venus') _buildVenusSettings(),
              if (_selectedDriverType == 'wrapper') _buildWrapperSettings(),
              
              if (_selectedDriverType == 'turnip')
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable DRI3 for Turnip'),
                    subtitle: const Text('Direct Rendering Infrastructure v3'),
                    value: _turnipDri3Enabled,
                    onChanged: _isX11Enabled 
                        ? (value) {
                            setState(() {
                              _turnipDri3Enabled = value;
                            });
                          }
                        : null,
                  ),
                ),
              
              if (_selectedDriverType == 'wrapper')
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable DRI3 for Wrapper'),
                    subtitle: const Text('Direct Rendering Infrastructure v3'),
                    value: _wrapperDri3Enabled,
                    onChanged: _isX11Enabled 
                        ? (value) {
                            setState(() {
                              _wrapperDri3Enabled = value;
                            });
                          }
                        : null,
                  ),
                ),
              
              if (_selectedDriverType == 'venus')
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable DRI3 for Venus'),
                    subtitle: const Text('Direct Rendering Infrastructure v3'),
                    value: _venusDri3Enabled,
                    onChanged: _isX11Enabled 
                        ? (value) {
                            setState(() {
                              _venusDri3Enabled = value;
                            });
                          }
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAndExtract,
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }

  Widget _buildTurnipSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Turnip Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_selectedDriverFile == null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using built-in Turnip from: ${G.dataPath}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedDriverFile != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using custom Turnip driver: $_selectedDriverFile',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultTurnipOpt,
              decoration: const InputDecoration(
                labelText: 'Turnip Environment Variables (without VK_ICD_FILENAMES)',
                hintText: 'Example: MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _defaultTurnipOpt = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirglSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VirGL Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVirglCommand,
              decoration: const InputDecoration(
                labelText: 'VirGL Server Parameters',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                setState(() {
                  _defaultVirglCommand = value;
                });
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVirglOpt,
              decoration: const InputDecoration(
                labelText: 'VirGL Environment Variables',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                setState(() {
                  _defaultVirglOpt = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenusSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Venus Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVenusCommand,
              decoration: const InputDecoration(
                labelText: 'Venus Server Parameters',
                hintText: 'Example: --no-virgl --venus --socket-path=\$CONTAINER_DIR/tmp/.virgl_test',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _defaultVenusCommand = value;
                });
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVenusOpt,
              decoration: const InputDecoration(
                labelText: 'Venus Environment Variables',
                hintText: 'Example: ANDROID_VENUS=1',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _defaultVenusOpt = value;
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Enable Android Venus'),
              subtitle: const Text('Use Android\'s Vulkan driver (requires Android 10+)'),
              value: _androidVenusEnabled,
              onChanged: (value) {
                setState(() {
                  _androidVenusEnabled = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrapperSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wrapper Driver Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wrapper driver provides compatibility layer for specific GPU architectures.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverFileSelection() {
    List<String> filteredFiles = _driverFiles.where((file) {
      if (_selectedDriverType == 'turnip') {
        return file.toLowerCase().contains('turnip') ||
               file.toLowerCase().contains('freedreno') ||
               file.endsWith('.json');
      } else if (_selectedDriverType == 'wrapper') {
        return file.toLowerCase().contains('wrapper');
      }
      return false;
    }).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedDriverType == 'turnip' 
                ? 'Select Turnip Driver File'
                : 'Select Wrapper Driver File',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            
            if (!_isLoading && filteredFiles.isEmpty)
              Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    _selectedDriverType == 'turnip'
                      ? 'No turnip driver files found'
                      : 'No wrapper driver files found',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDriverType == 'turnip'
                      ? 'Please place turnip driver files in the drivers folder'
                      : 'Please place wrapper driver files in the drivers folder',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _loadDriverFiles,
                  ),
                ],
              ),
            
            if (!_isLoading && filteredFiles.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedDriverFile,
                decoration: InputDecoration(
                  labelText: _selectedDriverType == 'turnip'
                    ? 'Turnip Driver File'
                    : 'Wrapper Driver File',
                  border: const OutlineInputBorder(),
                ),
                items: filteredFiles.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDriverFile = newValue;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class FakeLoadingStatus extends StatefulWidget {
  const FakeLoadingStatus({super.key});

  @override
  State<FakeLoadingStatus> createState() => _FakeLoadingStatusState();
}

class _FakeLoadingStatusState extends State<FakeLoadingStatus> {

  double _progressT = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progressT += 0.1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: 1 - pow(10, _progressT / -300).toDouble());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}



class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {

  final List<bool> _expandState = [false, false, false, false, false, false];
  double _avncScaleFactor = Util.getGlobal("avncScaleFactor") as double;

  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => const BackupRestoreDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
        setState(() {
          _expandState[panelIndex] = isExpanded;
        });
      },
      children: [
        // Panel 0: Advanced Settings
        ExpansionPanel(
          isExpanded: _expandState[0],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.advancedSettings),
              subtitle: Text(AppLocalizations.of(context)!.restartAfterChange),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.resetStartupCommand),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text(AppLocalizations.of(context)!.attention),
                            content: Text(AppLocalizations.of(context)!.confirmResetCommand),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(AppLocalizations.of(context)!.cancel),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await Util.setCurrentProp(
                                    "boot",
                                    Localizations.localeOf(context).languageCode == 'zh'
                                        ? D.boot
                                        : D.boot.replaceFirst('LANG=zh_CN.UTF-8', 'LANG=en_US.UTF-8')
                                            .replaceFirst('公共', 'Public')
                                            .replaceFirst('图片', 'Pictures')
                                            .replaceFirst('音乐', 'Music')
                                            .replaceFirst('视频', 'Videos')
                                            .replaceFirst('下载', 'Downloads')
                                            .replaceFirst('文档', 'Documents')
                                            .replaceFirst('照片', 'Photos'),
                                  );
                                  G.bootTextChange.value = !G.bootTextChange.value;
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                },
                                child: Text(AppLocalizations.of(context)!.yes),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.signal9ErrorPage),
                    onPressed: () async {
                      await D.androidChannel.invokeMethod("launchSignal9Page", {});
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("name"),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.containerName,
                ),
                onChanged: (value) async {
                  await Util.setCurrentProp("name", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              ValueListenableBuilder(
                valueListenable: G.bootTextChange,
                builder: (context, v, child) {
                  return TextFormField(
                    maxLines: null,
                    initialValue: Util.getCurrentProp("boot"),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.startupCommand,
                    ),
                    onChanged: (value) async {
                      await Util.setCurrentProp("boot", value);
                    },
                  );
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vnc"),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.vncStartupCommand,
                ),
                onChanged: (value) async {
                  await Util.setCurrentProp("vnc", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.shareUsageHint),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.copyShareLink),
                    onPressed: () async {
                      final String? ip = await NetworkInfo().getWifiIP();
                      if (!context.mounted) return;
                      if (G.wasX11Enabled) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.x11InvalidHint)),
                        );
                        return;
                      }
                      if (ip == null) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.cannotGetIpAddress)),
                        );
                        return;
                      }
                      await FlutterClipboard.copy((Util.getCurrentProp("vncUrl") as String)
                          .replaceAll(RegExp.escape("localhost"), ip)).then((value) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.shareLinkCopied)),
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 16),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vncUrl"),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.webRedirectUrl,
                ),
                onChanged: (value) async {
                  await Util.setCurrentProp("vncUrl", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vncUri"),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.vncLink,
                ),
                onChanged: (value) async {
                  await Util.setCurrentProp("vncUri", value);
                },
              ),
              const SizedBox.square(dimension: 8),
            ]),
          ),
        ),

        // Panel 1: Global Settings
        ExpansionPanel(
          isExpanded: _expandState[1],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.globalSettings),
              subtitle: Text(AppLocalizations.of(context)!.enableTerminalEditing),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                initialValue: (Util.getGlobal("termMaxLines") as int).toString(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.terminalMaxLines,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  return Util.validateBetween(value, 1024, 2147483647, () async {
                    await G.prefs.setInt("termMaxLines", int.parse(value!));
                  });
                },
              ),
              const SizedBox.square(dimension: 16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                initialValue: (Util.getGlobal("defaultAudioPort") as int).toString(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.pulseaudioPort,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  return Util.validateBetween(value, 0, 65535, () async {
                    await G.prefs.setInt("defaultAudioPort", int.parse(value!));
                  });
                },
              ),
              const SizedBox.square(dimension: 16),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableTerminal),
                value: Util.getGlobal("isTerminalWriteEnabled") as bool,
                onChanged: (value) {
                  G.prefs.setBool("isTerminalWriteEnabled", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableTerminalKeypad),
                value: Util.getGlobal("isTerminalCommandsEnabled") as bool,
                onChanged: (value) {
                  G.prefs.setBool("isTerminalCommandsEnabled", value);
                  setState(() {
                    G.terminalPageChange.value = !G.terminalPageChange.value;
                  });
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.terminalStickyKeys),
                value: Util.getGlobal("isStickyKey") as bool,
                onChanged: (value) {
                  G.prefs.setBool("isStickyKey", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.keepScreenOn),
                value: Util.getGlobal("wakelock") as bool,
                onChanged: (value) {
                  G.prefs.setBool("wakelock", value);
                  WakelockPlus.toggle(enable: value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.restartRequiredHint),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.startWithGUI),
                value: Util.getGlobal("autoLaunchVnc") as bool,
                onChanged: (value) {
                  G.prefs.setBool("autoLaunchVnc", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.reinstallBootPackage),
                value: Util.getGlobal("reinstallBootstrap") as bool,
                onChanged: (value) {
                  G.prefs.setBool("reinstallBootstrap", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.getifaddrsBridge),
                subtitle: Text(AppLocalizations.of(context)!.fixGetifaddrsPermission),
                value: Util.getGlobal("getifaddrsBridge") as bool,
                onChanged: (value) {
                  G.prefs.setBool("getifaddrsBridge", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Logcat Capture'),
                subtitle: const Text('Save system logs to app storage'),
                value: Util.getGlobal("logcatEnabled") as bool,
                onChanged: (value) async {
                  await G.prefs.setBool("logcatEnabled", value);
                  if (value) {
                    LogcatManager().startCapture();
                  } else {
                    LogcatManager().stopCapture();
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder, size: 16),
                      label: const Text('View Logs'),
                      onPressed: () async {
                        final files = await LogcatManager().getLogFiles();
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Log Files (${files.length})'),
                            content: Container(
                              width: double.maxFinite,
                              height: 300,
                              child: ListView.builder(
                                itemCount: files.length,
                                itemBuilder: (context, index) => ListTile(
                                  title: Text(files[index]),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, size: 16),
                                    onPressed: () async {
                                      final logDir = await LogcatManager().getLogDirectory();
                                      final file = File('${logDir.path}/${files[index]}');
                                      await file.delete();
                                      Navigator.pop(context);
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Deleted ${files[index]}')),
                                      );
                                    },
                                  ),
                                  onTap: () async {
                                    final content = await LogcatManager().readLogFile(files[index]);
                                    if (content != null) {
                                      Navigator.pop(context);
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(files[index]),
                                          content: Container(
                                            width: double.maxFinite,
                                            height: 400,
                                            child: SingleChildScrollView(
                                              child: SelectableText(content),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear All Logs?'),
                            content: const Text('This will delete all log files. This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final success = await LogcatManager().clearLogs();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success 
                                        ? 'All logs cleared successfully'
                                        : 'Failed to clear logs'),
                                    ),
                                  );
                                },
                                child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.fakeUOSSystem),
                value: Util.getGlobal("uos") as bool,
                onChanged: (value) {
                  G.prefs.setBool("uos", value);
                  setState(() {});
                },
              ),
            ]),
          ),
        ),

        // Panel 2: Display Settings
        ExpansionPanel(
          isExpanded: _expandState[2],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.displaySettings),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.hidpiAdvantages),
              const SizedBox.square(dimension: 16),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultHidpiOpt") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.hidpiEnvVar,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultHidpiOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.hidpiSupport),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("isHidpiEnabled") as bool,
                onChanged: (value) {
                  G.prefs.setBool("isHidpiEnabled", value);
                  _avncScaleFactor += value ? 0.5 : -0.5;
                  _avncScaleFactor = _avncScaleFactor.clamp(-1, 1);
                  G.prefs.setDouble("avncScaleFactor", _avncScaleFactor);
                  X11Flutter.setX11ScaleFactor(value ? 0.5 : 2.0);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.avncAdvantages),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.avncSettings),
                    onPressed: () async {
                      await AvncFlutter.launchPrefsPage();
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.aboutAVNC),
                    onPressed: () async {
                      await AvncFlutter.launchAboutPage();
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    onPressed: Util.getGlobal("avncResizeDesktop") as bool
                        ? null
                        : () async {
                            final s = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
                            final w0 = max(s.width, s.height);
                            final h0 = min(s.width, s.height);
                            String w = (w0 * 0.75).round().toString();
                            String h = (h0 * 0.75).round().toString();
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(AppLocalizations.of(context)!.resolutionSettings),
                                  content: SingleChildScrollView(
                                    child: Column(children: [
                                      Text("${AppLocalizations.of(context)!.deviceScreenResolution} ${w0.round()}x${h0.round()}"),
                                      const SizedBox.square(dimension: 8),
                                      TextFormField(
                                        autovalidateMode: AutovalidateMode.onUserInteraction,
                                        initialValue: w,
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: AppLocalizations.of(context)!.width,
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          return Util.validateBetween(value, 200, 7680, () {
                                            w = value!;
                                          });
                                        },
                                      ),
                                      const SizedBox.square(dimension: 8),
                                      TextFormField(
                                        autovalidateMode: AutovalidateMode.onUserInteraction,
                                        initialValue: h,
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: AppLocalizations.of(context)!.height,
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          return Util.validateBetween(value, 200, 7680, () {
                                            h = value!;
                                          });
                                        },
                                      ),
                                    ]),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(AppLocalizations.of(context)!.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Util.termWrite("""sed -i -E "s@(geometry)=.*@\\1=${w}x${h}@" /etc/tigervnc/vncserver-config-tmoe
sed -i -E "s@^(VNC_RESOLUTION)=.*@\\1=${w}x${h}@" \$(command -v startvnc)""");
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text("${w}x${h}. ${AppLocalizations.of(context)!.applyOnNextLaunch}")),
                                        );
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(AppLocalizations.of(context)!.save),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                    child: Text(AppLocalizations.of(context)!.avncResolution),
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.useAVNCByDefault),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("useAvnc") as bool,
                onChanged: (value) {
                  G.prefs.setBool("useAvnc", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.avncScreenResize),
                value: Util.getGlobal("avncResizeDesktop") as bool,
                onChanged: (value) {
                  G.prefs.setBool("avncResizeDesktop", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              ListTile(
                title: Text(AppLocalizations.of(context)!.avncResizeFactor),
                onTap: () {},
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('${AppLocalizations.of(context)!.avncResizeFactorValue} ${pow(4, _avncScaleFactor).toStringAsFixed(2)}x'),
                    const SizedBox(height: 12),
                    Slider(
                      value: _avncScaleFactor,
                      min: -1,
                      max: 1,
                      divisions: 96,
                      onChangeEnd: (double value) {
                        G.prefs.setDouble("avncScaleFactor", value);
                      },
                      onChanged: Util.getGlobal("avncResizeDesktop") as bool
                          ? (double value) {
                              _avncScaleFactor = value;
                              setState(() {});
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.termuxX11Advantages),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(AppLocalizations.of(context)!.termuxX11Preferences),
                    onPressed: () async {
                      await X11Flutter.launchX11PrefsPage();
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.useTermuxX11ByDefault),
                subtitle: Text(AppLocalizations.of(context)!.disableVNC),
                value: Util.getGlobal("useX11") as bool,
                onChanged: (value) {
                  G.prefs.setBool("useX11", value);
                  if (!value && Util.getGlobal("dri3")) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 16),
            ]),
          ),
        ),

        // Panel 3: Graphics Acceleration
        ExpansionPanel(
          isExpanded: _expandState[3],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.graphicsAcceleration),
              subtitle: Text(AppLocalizations.of(context)!.experimentalFeature),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(AppLocalizations.of(context)!.graphicsAccelerationHint),
              const SizedBox.square(dimension: 16),
              
              // Virgl section
              Text(AppLocalizations.of(context)!.virglServerParams,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVirglCommand") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.virglServerParams,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVirglCommand", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVirglOpt") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.virglEnvVar,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVirglOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableVirgl),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("virgl") as bool,
                onChanged: (value) {
                  if (value) {
                    G.prefs.setBool("venus", false);
                    G.prefs.setBool("turnip", false);
                    if (Util.getGlobal("dri3")) {
                      G.prefs.setBool("dri3", false);
                    }
                  }
                  G.prefs.setBool("virgl", value);
                  setState(() {});
                },
              ),
              
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              
              // Venus section
              Text(AppLocalizations.of(context)!.venusAdvantages,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              Text(AppLocalizations.of(context)!.venusAdvantages),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVenusCommand") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.venusServerParams,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVenusCommand", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVenusOpt") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.venusEnvVar,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVenusOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableVenus),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("venus") as bool,
                onChanged: (value) {
                  if (value) {
                    G.prefs.setBool("virgl", false);
                    G.prefs.setBool("turnip", false);
                  }
                  G.prefs.setBool("venus", value);
                  
                  if (!value && Util.getGlobal("dri3")) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableAndroidVenus),
                subtitle: Text(AppLocalizations.of(context)!.venusAdvantages),
                value: Util.getGlobal("androidVenus") as bool,
                onChanged: (value) async {
                  await G.prefs.setBool("androidVenus", value);
                  setState(() {});
                },
              ),
              
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              
              // Turnip section
              Text(AppLocalizations.of(context)!.turnipAdvantages,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultTurnipOpt") as String,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.turnipEnvVar,
                ),
                onChanged: (value) async {
                  await G.prefs.setString("defaultTurnipOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableTurnipZink),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("turnip") as bool,
                onChanged: (value) async {
                  if (value) {
                    G.prefs.setBool("virgl", false);
                    G.prefs.setBool("venus", false);
                  }
                  G.prefs.setBool("turnip", value);
                  if (!value && Util.getGlobal("dri3")) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.enableDRI3),
                subtitle: Text(AppLocalizations.of(context)!.applyOnNextLaunch),
                value: Util.getGlobal("dri3") as bool,
                onChanged: (value) async {
                  final bool useX11 = Util.getGlobal("useX11") == true;
                  final bool turnip = Util.getGlobal("turnip") == true;
                  final bool venus  = Util.getGlobal("venus") == true;
                  if (value && !(useX11 && (turnip || venus))) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.dri3Requirement)),
                    );
                    return;
                  }
                  G.prefs.setBool("dri3", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 16),
            ]),
          ),
        ),

        // Panel 4: Windows App Support
        ExpansionPanel(
          isExpanded: _expandState[4],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.windowsAppSupport),
              subtitle: Text(AppLocalizations.of(context)!.experimentalFeature),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(AppLocalizations.of(context)!.hangoverDescription),
              const SizedBox.square(dimension: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Environment Settings'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => EnvironmentDialog(),
                      );
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('GPU Drivers'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => GpuDriversDialog(),
                      );
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Install DXVK'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => DxvkDialog(),
                      );
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Wine bionic Settings🍷'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => WineSettingsDialog(),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.wineCommandsHint),
              const SizedBox.square(dimension: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: (Localizations.localeOf(context).languageCode == 'zh' ? D.wineCommands : D.wineCommands4En)
                    .asMap()
                    .entries
                    .map<Widget>((e) {
                  return OutlinedButton(
                    style: D.commandButtonStyle,
                    child: Text(e.value["name"]!),
                    onPressed: () {
                      Util.termWrite("${e.value["command"]!} &");
                      G.pageIndex.value = 0;
                    },
                  );
                }).toList(),
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: Text("${AppLocalizations.of(context)!.installHangoverStable}（10.14）"),
                onPressed: () async {
                  Util.termWrite("bash /home/tiny/.local/share/tiny/extra/install-hangover-stable");
                  G.pageIndex.value = 0;
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: Text(AppLocalizations.of(context)!.installHangoverLatest),
                onPressed: () async {
                  Util.termWrite("bash //extra/install-hangover");
                  G.pageIndex.value = 0;
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: Text(AppLocalizations.of(context)!.uninstallHangover),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                      title: const Text('Delete Wine hangover?'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('This will delete:'),
                          SizedBox(height: 8),
                          Text('•❌Full Wine🍷 ', style: TextStyle(color: Colors.red)),
                          Text('•with Windows support', style: TextStyle(color: Colors.red)),
                          Text('• for wine hangover!', style: TextStyle(color: Colors.red)),
                          SizedBox(height: 12),
                          Text('This action cannot be undone!'),
                        ],
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("sudo apt autoremove --purge -y hangover*");
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wine hangover deleted'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          child: const Text('Delete Now'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: const Text('Delete Wine x86_64🍷'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                      title: const Text('Delete Wine x86_64?'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('This will delete:'),
                          SizedBox(height: 8),
                          Text('•❌Full Wine🍷 ', style: TextStyle(color: Colors.red)),
                          Text('•with Windows support', style: TextStyle(color: Colors.red)),
                          Text('• for wine x86_64!', style: TextStyle(color: Colors.red)),
                          SizedBox(height: 12),
                          Text('This action cannot be undone!'),
                        ],
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf /opt/wine");
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wine deleted'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          child: const Text('Delete Now'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: const Text('Delete Wine Bionic🍷'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                      title: const Text('Delete Wine bionic?'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('This will delete:'),
                          SizedBox(height: 8),
                          Text('•❌Full Wine🍷 ', style: TextStyle(color: Colors.red)),
                          Text('•with Windows support', style: TextStyle(color: Colors.red)),
                          Text('• for wine bionic!', style: TextStyle(color: Colors.red)),
                          SizedBox(height: 12),
                          Text('This action cannot be undone!'),
                        ],
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf ${G.dataPath}/usr/opt/wine");
                            Util.termWrite("rm -rf ${G.dataPath}/home/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wine deleted'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          child: const Text('Delete Now'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: Text(AppLocalizations.of(context)!.clearWineData),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                      title: const Text('Delete Wine Prefix?'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('This will delete:'),
                          SizedBox(height: 8),
                          Text('• All Wine configuration', style: TextStyle(color: Colors.red)),
                          Text('• Installed Windows apps', style: TextStyle(color: Colors.red)),
                          Text('• Registry and save games with settings', style: TextStyle(color: Colors.red)),
                          SizedBox(height: 12),
                          Text('This action cannot be undone!'),
                        ],
                      ),
                      actions: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wine prefix deleted'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          child: const Text('Delete Now'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.restartRequiredHint),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.switchToJapanese),
                subtitle: const Text("システムを日本語に切り替える"),
                value: Util.getGlobal("isJpEnabled") as bool,
                onChanged: (value) async {
                  if (value) {
                    Util.termWrite("sudo localedef -c -i ja_JP -f UTF-8 ja_JP.UTF-8");
                    G.pageIndex.value = 0;
                  }
                  G.prefs.setBool("isJpEnabled", value);
                  setState(() {});
                },
              ),
            ]),
          ),
        ),

        // Panel 5: System Backup & Restore
        ExpansionPanel(
          isExpanded: _expandState[5],
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.systemBackupRestore),
              subtitle: Text(AppLocalizations.of(context)!.backupRestoreDescriptionShort),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(AppLocalizations.of(context)!.backupRestoreWarning),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.backup),
                      label: Text(AppLocalizations.of(context)!.backupSystem),
                      onPressed: _showBackupRestoreDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: Text(AppLocalizations.of(context)!.restoreSystem),
                      onPressed: _showBackupRestoreDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.backupNote,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class InfoPage extends StatefulWidget {
  final bool openFirstInfo;

  const InfoPage({super.key, this.openFirstInfo=false});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<bool> _expandState = [false, false, false, false, false];
 // late AudioPlayer _gamesMusicPlayer;
// bool _isGamesMusicPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _expandState[0] = widget.openFirstInfo;
 //   _gamesMusicPlayer = AudioPlayer();
  //  _setupMusicPlayer();
  }
  
/*  void _setupMusicPlayer() async {
    try {
      await _gamesMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _gamesMusicPlayer.setVolume(0.6);
    } catch (_) {
      // ignore audio errors
    }
  }

  void _startGamesMusic() async {
    if (_isGamesMusicPlaying) return;
    
    try {
      await _gamesMusicPlayer.play(AssetSource('music.mp3'));
      setState(() {
        _isGamesMusicPlaying = true;
      });
    } catch (_) {
      setState(() {
        _isGamesMusicPlaying = true;
      });
    }
  }

  void _stopGamesMusic() async {
    if (!_isGamesMusicPlaying) return;
    
    try {
      await _gamesMusicPlayer.stop();
      setState(() {
        _isGamesMusicPlaying = false;
      });
    } catch (_) {
      setState(() {
        _isGamesMusicPlaying = false;
      });
    }
  } */

  @override
  void dispose() {
    //_stopGamesMusic();
  //  _gamesMusicPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
       
        
        setState(() {
          _expandState[panelIndex] = isExpanded;
        });
      },
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(title: Text(AppLocalizations.of(context)!.userManual));
          },
          body: Padding(padding: const EdgeInsets.all(8), child: Column(
            children: [
              Text(AppLocalizations.of(context)!.firstLoadInstructions),
              const SizedBox.square(dimension: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
                OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.requestStoragePermission), onPressed: () {
                  Permission.storage.request();
                }),
                OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.requestAllFilesAccess), onPressed: () {
                  Permission.manageExternalStorage.request();
                }),
                OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.ignoreBatteryOptimization), onPressed: () {
                  Permission.ignoreBatteryOptimizations.request();
                }),
              ]),
              const SizedBox.square(dimension: 16),
              Text(AppLocalizations.of(context)!.updateRequest),
              const SizedBox.square(dimension: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: D.links
              .asMap().entries.map<Widget>((e) {
                return OutlinedButton(style: D.commandButtonStyle, child: Text(Util.getl10nText(e.value["name"]!, context)), onPressed: () {
                  launchUrl(Uri.parse(e.value["value"]!), mode: LaunchMode.externalApplication);
                });
              }).toList()),
            ],
          )),
          isExpanded: _expandState[0],
        ),
        ExpansionPanel(
          isExpanded: _expandState[1],
          headerBuilder: ((context, isExpanded) {
            return ListTile(
              title: Text(AppLocalizations.of(context)!.mindTwisterGames),
              subtitle: Text( 
                AppLocalizations.of(context)!.extractionInProgress 
                : AppLocalizations.of(context)!.playWhileWaiting),
            );
          }), 
          body: _buildGamesSection(),
        ),
        ExpansionPanel(
        isExpanded: _expandState[2],
        headerBuilder: ((context, isExpanded) {
          return ListTile(title: Text(AppLocalizations.of(context)!.fileAccess));
        }), body: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Text(AppLocalizations.of(context)!.fileAccessHint),
          const SizedBox.square(dimension: 16),
          Wrap(alignment: WrapAlignment.center, spacing: 4.0, runSpacing: 4.0, children: [
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.requestStoragePermission), onPressed: () {
              Permission.storage.request();
            }),
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.requestAllFilesAccess), onPressed: () {
              Permission.manageExternalStorage.request();
            }),
            OutlinedButton(style: D.commandButtonStyle, child: Text(AppLocalizations.of(context)!.fileAccessGuide), onPressed: () {
              launchUrl(Uri.parse("https://github.com/xodiosx/XoDos2/blob/main/fileaccess.md"), mode: LaunchMode.externalApplication);
            }),
          ]),
          const SizedBox.square(dimension: 16),
        ],))),
        ExpansionPanel(
          isExpanded: _expandState[3],
          headerBuilder: ((context, isExpanded) {
            return ListTile(title: Text(AppLocalizations.of(context)!.permissionUsage));
          }), body: Padding(padding: const EdgeInsets.all(8), child: Text(AppLocalizations.of(context)!.privacyStatement))),
        ExpansionPanel(
          isExpanded: _expandState[4],
          headerBuilder: ((context, isExpanded) {
            return ListTile(title: Text(AppLocalizations.of(context)!.supportAuthor));
          }), body: Column(
          children: [
            Padding(padding: const EdgeInsets.all(8), child: Text(AppLocalizations.of(context)!.recommendApp)),
            ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/xodiosx/XoDos2"), mode: LaunchMode.externalApplication);
              },
              child: Text(AppLocalizations.of(context)!.projectUrl),
            ),
          ]
        )),
      ],
    );
  }

  Widget _buildGamesSection() {
    return Container(
      height: 600,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Text(
                  '🎮 ${AppLocalizations.of(context)!.gameModeActive}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),

                
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Note: SpiritedMiniGamesView would need to be imported from the xodos code
          // For now, we'll show a placeholder
          Expanded(
            child: Center(
              child: Text(
                'Mini Games Section\n(SpiritedMiniGamesView would go here)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AspectRatioMax1To1(child:
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: FractionallySizedBox(
                widthFactor: 0.4,
                child: Image(
                  image: AssetImage("images/icon.png")
                )
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: ValueListenableBuilder(valueListenable: G.updateText, builder:(context, value, child) {
                return Text(value, textScaler: const TextScaler.linear(2));
              }),
            ),
            const FakeLoadingStatus(),
            const Expanded(child: Padding(padding: EdgeInsets.all(8), child: Card(child: Padding(padding: EdgeInsets.all(8), child: 
              Scrollbar(child:
                SingleChildScrollView(
                  child: InfoPage(openFirstInfo: true)
                )
              )
            ))
            ,))
          ]
        )
      )
    );
  }
}

class ForceScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    super.acceptGesture(pointer);
  }
}

RawGestureDetector forceScaleGestureDetector({
  GestureScaleUpdateCallback? onScaleUpdate,
  GestureScaleEndCallback? onScaleEnd,
  Widget? child,
}) {
  return RawGestureDetector(
    gestures: {
      ForceScaleGestureRecognizer:GestureRecognizerFactoryWithHandlers<ForceScaleGestureRecognizer>(() {
        return ForceScaleGestureRecognizer();
      }, (detector) {
        detector.onUpdate = onScaleUpdate;
        detector.onEnd = onScaleEnd;
      })
    },
    child: child,
  );
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopActionButtons(),
        Expanded(
          child: forceScaleGestureDetector(
            onScaleUpdate: (details) {
              G.termFontScale.value = (details.scale * (Util.getGlobal("termFontScale") as double)).clamp(0.2, 5);
            }, 
            onScaleEnd: (details) async {
              await G.prefs.setDouble("termFontScale", G.termFontScale.value);
            }, 
            child: ValueListenableBuilder(
              valueListenable: G.termFontScale, 
              builder: (context, value, child) {
                return TerminalView(
                  G.termPtys[G.currentContainer]!.terminal, 
                  textScaler: TextScaler.linear(G.termFontScale.value), 
                  keyboardType: TextInputType.multiline,
                );
              },
            ),
          ),
        ), 
        ValueListenableBuilder(
          valueListenable: G.terminalPageChange, 
          builder: (context, value, child) {
            return (Util.getGlobal("isTerminalCommandsEnabled") as bool) 
              ? _buildTermuxStyleControlBar()
              : const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildTopActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopActionButton(
            Icons.play_arrow,
            'Start Desktop,',
            _startGUI,
          ),
          
          _buildTopActionButton(
            Icons.stop,
            'Exit Desktop',
            _exitContainer,
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).primaryColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startGUI() {
    if (G.wasX11Enabled) {
      Workflow.launchX11();
    } else if (G.wasAvncEnabled) {
      Workflow.launchAvnc();
    } else {
      Workflow.launchBrowser();
    }
  }

  void _exitContainer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit 🛑'),
        content: const Text('This will stop the current container and exit. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel❌'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _forceExitContainer();
            },
            child: const Text('Exit✅'),
          ),
        ],
      ),
    );
  }

  void _forceExitContainer() {
    Util.termWrite('stopvnc');
    Util.termWrite('pkill -f dbus');
    Util.termWrite('pkill -f wine');
    Util.termWrite('pkill -f virgl*');
    Util.termWrite('pkill -f lxqt');
    Util.termWrite('exit');
    Util.termWrite('exit');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(' session stopped. closing app...'),
        duration: Duration(seconds: 3),
      ),
    );
    SystemNavigator.pop();
  }

  Future<void> _copyTerminalText() async {
    try {
      final termPty = G.termPtys[G.currentContainer]!;
      final terminal = termPty.terminal;
      // Note: This is a simplified version. You may need to implement proper text selection
      final text = terminal.buffer.getText();
      
      if (text.isNotEmpty) {
        await FlutterClipboard.copy(text);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terminal text copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text to copy'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Copy error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to copy text'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pasteToTerminal() async {
    try {
      final clipboardText = await FlutterClipboard.copy("") // This is incorrect, need proper implementation
          .then((_) => ""); // Placeholder
      
      // In reality, you'd need to get clipboard text properly
      // For now, we'll show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste functionality requires proper implementation'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to paste from clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTermuxStyleControlBar() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildModifierKeys(),
              ),
              const SizedBox(width: 8),
              _buildCopyPasteButtons(),
            ],
          ),
          const SizedBox(height: 8),
          _buildFunctionKeys(),
        ],
      ),
    );
  }

  Widget _buildCopyPasteButtons() {
    return Row(
      children: [
        _buildTermuxKey(
          'COPY',
          onTap: _copyTerminalText,
        ),
        const SizedBox(width: 4),
        _buildTermuxKey(
          'PASTE', 
          onTap: _pasteToTerminal,
        ),
      ],
    );
  }

  Widget _buildModifierKeys() {
    return AnimatedBuilder(
      animation: G.keyboard,
      builder: (context, child) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTermuxKey(
            'CTRL',
            isActive: G.keyboard.ctrl,
            onTap: () => G.keyboard.ctrl = !G.keyboard.ctrl,
          ),
          _buildTermuxKey(
            'ALT', 
            isActive: G.keyboard.alt,
            onTap: () => G.keyboard.alt = !G.keyboard.alt,
          ),
          _buildTermuxKey(
            'SHIFT',
            isActive: G.keyboard.shift, 
            onTap: () => G.keyboard.shift = !G.keyboard.shift,
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionKeys() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: D.termCommands.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          return _buildTermuxKey(
            D.termCommands[index]["name"]! as String,
            onTap: () {
              G.termPtys[G.currentContainer]!.terminal.keyInput(
                D.termCommands[index]["key"]! as TerminalKey
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTermuxKey(String label, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 40,
          maxWidth: 80,
          minHeight: 32,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Theme.of(context).textTheme.bodyLarge!.color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class FastCommands extends StatefulWidget {
  const FastCommands({super.key});

  @override
  State<FastCommands> createState() => _FastCommandsState();
}

class _FastCommandsState extends State<FastCommands> {
  final List<bool> _sectionExpanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final commands = Util.getCurrentProp("commands") as List<dynamic>;
    
    final installCommands = _getInstallCommands(commands);
    final otherCommands = _getOtherCommands(commands);
    final systemCommands = _getSystemCommands(commands);
    
    return Column(
      children: [
        if (installCommands.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: Text(
                'Installation Commands',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              initiallyExpanded: _sectionExpanded[0],
              onExpansionChanged: (expanded) {
                setState(() {
                  _sectionExpanded[0] = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: _buildCommandButtons(installCommands),
                  ),
                ),
              ],
            ),
          ),
        
        if (otherCommands.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: Text(
                'Other Commands',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              initiallyExpanded: _sectionExpanded[1],
              onExpansionChanged: (expanded) {
                setState(() {
                  _sectionExpanded[1] = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: _buildCommandButtons(otherCommands),
                  ),
                ),
              ],
            ),
          ),
        
        if (systemCommands.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: Text(
                'effects',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              initiallyExpanded: _sectionExpanded[2],
              onExpansionChanged: (expanded) {
                setState(() {
                  _sectionExpanded[2] = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: _buildCommandButtons(systemCommands),
                  ),
                ),
              ],
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).textTheme.bodyLarge!.color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[700]!),
            ),
            onPressed: _addCommand,
            onLongPress: _resetCommands,
            child: Text(AppLocalizations.of(context)!.addShortcutCommand),
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _getInstallCommands(List<dynamic> commands) {
    return commands.where((cmd) {
      final name = cmd["name"]?.toString().toLowerCase() ?? "";
      final command = cmd["command"]?.toString().toLowerCase() ?? "";
      return name.contains("install") || 
             command.contains("install") || 
             name.contains("enable");
    }).map((cmd) => Map<String, String>.from(cmd)).toList();
  }

  List<Map<String, String>> _getOtherCommands(List<dynamic> commands) {
    return commands.where((cmd) {
      final name = cmd["name"]?.toString().toLowerCase() ?? "";
      final command = cmd["command"]?.toString().toLowerCase() ?? "";
      return !name.contains("install") && 
             !command.contains("install") && 
             !name.contains("enable") &&
             name != "???" &&
             !name.contains("shutdown");
    }).map((cmd) => Map<String, String>.from(cmd)).toList();
  }

  List<Map<String, String>> _getSystemCommands(List<dynamic> commands) {
    return commands.where((cmd) {
      final name = cmd["name"]?.toString().toLowerCase() ?? "";
      return name.contains("shutdown") || name == "???";
    }).map((cmd) => Map<String, String>.from(cmd)).toList();
  }

  List<Widget> _buildCommandButtons(List<Map<String, String>> commands) {
    return commands.asMap().entries.map<Widget>((e) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).textTheme.bodyLarge!.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey[700]!),
        ),
        child: Text(e.value["name"]!),
        onPressed: () {
          Util.termWrite(e.value["command"]!);
          G.pageIndex.value = 0;
        },
        onLongPress: () {
          _editCommand(e.key, e.value);
        },
      );
    }).toList();
  }

  void _editCommand(int index, Map<String, String> cmd) {
    String name = cmd["name"]!;
    String command = cmd["command"]!;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.commandEdit),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.commandName,
                  ),
                  onChanged: (value) {
                    name = value;
                  },
                ),
                const SizedBox.square(dimension: 8),
                TextFormField(
                  maxLines: null,
                  initialValue: command,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.commandContent,
                  ),
                  onChanged: (value) {
                    command = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  List<dynamic> currentCommands = Util.getCurrentProp("commands");
                  
                  int commandIndex = currentCommands.indexWhere((c) => 
                    c["name"] == cmd["name"] && c["command"] == cmd["command"]);
                  
                  if (commandIndex != -1) {
                    currentCommands.removeAt(commandIndex);
                    
                    await Util.setCurrentProp("commands", currentCommands);
                    
                    setState(() {});
                    
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Command "${cmd["name"]}" deleted!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error deleting command: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting command: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.deleteItem),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                try {
                  List<dynamic> currentCommands = Util.getCurrentProp("commands");
                  
                  int commandIndex = currentCommands.indexWhere((c) => 
                    c["name"] == cmd["name"] && c["command"] == cmd["command"]);
                  
                  if (commandIndex != -1) {
                    currentCommands[commandIndex] = {"name": name, "command": command};
                    
                    await Util.setCurrentProp("commands", currentCommands);
                    
                    setState(() {});
                    
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Command "$name" updated!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error updating command: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating command: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  void _addCommand() {
    String name = "";
    String command = "";
    final BuildContext dialogContext = context;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.commandEdit),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.commandName,
                  ),
                  onChanged: (value) {
                    name = value;
                  },
                ),
                const SizedBox.square(dimension: 8),
                TextFormField(
                  maxLines: null,
                  initialValue: command,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.commandContent,
                  ),
                  onChanged: (value) {
                    command = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/xodiosx/XoDos2/blob/main/extracommand.md"),
                    mode: LaunchMode.externalApplication);
              },
              child: Text(AppLocalizations.of(context)!.more),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                try {
                  List<dynamic> currentCommands = Util.getCurrentProp("commands");
                  
                  final newCommand = {"name": name, "command": command};
                  
                  List<dynamic> newCommands = [...currentCommands, newCommand];
                  
                  await Util.setCurrentProp("commands", newCommands);
                  
                  Navigator.of(context).pop();
                  
                  setState(() {});
                  
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Command "$name" added successfully!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  print('Error adding command: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding command: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        );
      },
    );
  }

  void _resetCommands() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.resetCommand),
          content: Text(AppLocalizations.of(context)!.confirmResetAllCommands),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                final commands = Localizations.localeOf(context).languageCode == 'zh' 
                    ? D.commands 
                    : D.commands4En;
                await Util.setCurrentProp("commands", commands);
                setState(() {});
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.yes),
            ),
          ],
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool bannerAdsFailedToLoad = false;
  bool isLoadingComplete = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero,() {
      _initializeWorkflow();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
  }

  Future<void> _initializeWorkflow() async {
    await Workflow.workflow();
    if (mounted) {
      setState(() {
        isLoadingComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    G.homePageStateContext = context;

    return RTLWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(isLoadingComplete ? Util.getCurrentProp("name") : widget.title),
        ),
        body: isLoadingComplete
            ? ValueListenableBuilder(
                valueListenable: G.pageIndex,
                builder: (context, value, child) {
                  return IndexedStack(
                    index: G.pageIndex.value,
                    children: const [
                      TerminalPage(),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: AspectRatioMax1To1(
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              restorationId: "control-scroll",
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.4,
                                      child: Image(image: AssetImage("images/icon.png")),
                                    ),
                                  ),
                                  FastCommands(),
                                  Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          children: [
                                            SettingPage(),
                                            SizedBox.square(dimension: 8),
                                            InfoPage(openFirstInfo: false),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : const LoadingPage(),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: G.pageIndex,
          builder: (context, value, child) {
            return Visibility(
              visible: isLoadingComplete,
              child: NavigationBar(
                selectedIndex: G.pageIndex.value,
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.monitor), label: AppLocalizations.of(context)!.terminal),
                  NavigationDestination(icon: const Icon(Icons.video_settings), label: AppLocalizations.of(context)!.control),
                ],
                onDestinationSelected: (index) {
                  G.pageIndex.value = index;
                },
              ),
            );
          },
        ),
        //
        
      ),
    );
  }
}