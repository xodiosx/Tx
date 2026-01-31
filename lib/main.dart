import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clipboard/clipboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:file_picker/file_picker.dart';
import 'backup_restore_dialog.dart';
import 'workflow.dart';
import 'spirited_mini_games.dart';
// App Colors
class AppColors {
  static const Color primaryDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF252525);
  static const Color primaryPurple = Color(0xFFBB86FC);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFF333333);
}

// Global variables and utilities
class G {
  static late String dataPath;
  static late String currentContainer;
  static late SharedPreferences prefs;
  static late BuildContext homePageStateContext;
  static ValueNotifier<int> pageIndex = ValueNotifier<int>(0);
  static ValueNotifier<bool> bootTextChange = ValueNotifier<bool>(false);
  static ValueNotifier<bool> terminalPageChange = ValueNotifier<bool>(false);
  static ValueNotifier<double> termFontScale = ValueNotifier<double>(1.0);
  static ValueNotifier<String> updateText = ValueNotifier<String>('');
  static Map<String, PtyWrapper> termPtys = {};
  static bool wasX11Enabled = false;
  static bool wasAvncEnabled = false;
  
  static final keyboard = KeyboardState();
}

class KeyboardState with ChangeNotifier {
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;
  
  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;
  
  set ctrl(bool value) {
    _ctrl = value;
    notifyListeners();
  }
  
  set alt(bool value) {
    _alt = value;
    notifyListeners();
  }
  
  set shift(bool value) {
    _shift = value;
    notifyListeners();
  }
}

class PtyWrapper {
  final Pty pty;
  final Terminal terminal;
  final TerminalController controller;
  
  PtyWrapper(this.pty, this.terminal, this.controller);
}

class Util {
  static const MethodChannel androidChannel = MethodChannel('xodos/xodos');
  
  static void termWrite(String text) {
    final ptyWrapper = G.termPtys[G.currentContainer];
    if (ptyWrapper != null) {
      ptyWrapper.pty.write(Utf8Encoder().convert('$text\n'));
    }
  }
  
  static dynamic getCurrentProp(String key) {
    // Implementation would read from shared preferences
    return null;
  }
  
  static Future<void> setCurrentProp(String key, dynamic value) async {
    // Implementation would write to shared preferences
  }
  
  static dynamic getGlobal(String key) {
    return G.prefs.get(key);
  }
  
  static String getl10nText(String text, BuildContext context) {
    return text; // Simplified for merge
  }
  
  static String? validateBetween(String? value, int min, int max, Function callback) {
    if (value == null || value.isEmpty) return 'Required';
    final intVal = int.tryParse(value);
    if (intVal == null) return 'Invalid number';
    if (intVal < min || intVal > max) return 'Must be between $min and $max';
    callback();
    return null;
  }
}

class D {
  static const ButtonStyle commandButtonStyle = ButtonStyle(
    padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
  );
  
  static const String boot = '''
LANG=zh_CN.UTF-8
cd ~
bash /extra/start-container
''';
  
  static const List<Map<String, String>> wineCommands = [];
  static const List<Map<String, String>> wineCommands4En = [];
  static const List<Map<String, dynamic>> commands = [];
  static const List<Map<String, dynamic>> commands4En = [];
  static const List<Map<String, String>> links = [];
  static const List<Map<String, dynamic>> termCommands = [];
}

class Workflow {
  static Future<void> workflow() async {
    // Implementation would initialize the workflow
  }
  
  static void launchX11() {}
  static void launchAvnc() {}
  static void launchBrowser() {}
}

class ExtractionManager {
  static Future<double> getExtractionProgressT() async => 0.0;
  static Future<bool> isExtractionComplete() async => false;
  static Future<void> setExtractionProgressT(double progress) async {}
  static Future<void> setExtractionComplete() async {}
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
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
      theme: _buildDarkTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.dark,
      home: MyHomePage(title: "XoDos"),
    );
  }

  ThemeData _buildDarkTheme() {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: Colors.blue,
        secondary: Colors.green,
        surface: AppColors.surfaceDark,
        background: AppColors.primaryDark,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.primaryDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: baseTheme.cardTheme.copyWith(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}

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

class AspectRatioMax1To1 extends StatelessWidget {
  final Widget child;

  const AspectRatioMax1To1({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = MediaQuery.of(context).size;
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

class FakeLoadingStatus extends StatefulWidget {
  const FakeLoadingStatus({super.key});

  @override
  State<FakeLoadingStatus> createState() => _FakeLoadingStatusState();
}

class _FakeLoadingStatusState extends State<FakeLoadingStatus> {
  double _progressT = 0;
  Timer? _timer;
  bool _extractionComplete = false;

  @override
  void initState() {
    super.initState();
    _loadInitialProgress();
  }

  void _loadInitialProgress() async {
    final savedProgressT = await ExtractionManager.getExtractionProgressT();
    final savedComplete = await ExtractionManager.isExtractionComplete();
    
    if (mounted) {
      setState(() {
        _progressT = savedProgressT;
        _extractionComplete = savedComplete;
      });
    }

    if (!_extractionComplete) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_extractionComplete) {
          timer.cancel();
          return;
        }

        setState(() {
          _progressT += 0.1;
        });
        
        await ExtractionManager.setExtractionProgressT(_progressT);
        
        final progress = 1 - pow(10, _progressT / -300).toDouble();
        if (progress >= 0.999 && !_extractionComplete) {
          _extractionComplete = true;
          await ExtractionManager.setExtractionComplete();
          timer.cancel();
        }
      });
    }
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

class ExtractionProgressState {
  static double _progressT = 0.0;
  static bool _extractionComplete = false;
  static final List<VoidCallback> _listeners = [];

  static double get progressT => _progressT;
  static bool get extractionComplete => _extractionComplete;

  static void updateProgress(double progressT, bool complete) {
    _progressT = progressT;
    _extractionComplete = complete;
    _notifyListeners();
  }

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
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
      ForceScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ForceScaleGestureRecognizer>(
        () => ForceScaleGestureRecognizer(),
        (detector) {
          detector.onUpdate = onScaleUpdate;
          detector.onEnd = onScaleEnd;
        }
      )
    },
    child: child,
  );
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

  bool get _hasHudChanged => _currentMangohudEnabled != _savedMangohudEnabled ||
                             _currentDxvkHudEnabled != _savedDxvkHudEnabled;

  bool get _hasDxvkChanged => _selectedDxvk != null && _selectedDxvk != _savedSelectedDxvk;

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
          SnackBar(content: Text('Please select a DXVK version')),
        );
        return;
      }
      
      final dxvkPath = '$_dxvkDirectory/$_selectedDxvk';
      final file = File(dxvkPath);
      
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found: $dxvkPath')),
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
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during extraction: $e')),
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

  Future<void> _cancelDialog() async {
    await _savePreferences();
    
    if (_hasHudChanged) {
      await _writeHudSettings();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HUD settings saved to ${G.dataPath}/usr/opt/hud')),
        );
      });
    }
    
    Navigator.of(context).pop();
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
      print('Found DXVK directory at: $hostDir');
      
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
                const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator())),
              if (!_isLoading && _dxvkFiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      const Text('No DXVK files found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Please place DXVK files in:\n/wincomponents/d3d/', textAlign: TextAlign.center),
                      if (_dxvkDirectory != null)
                        Text('Directory: $_dxvkDirectory', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      decoration: const InputDecoration(labelText: 'Select DXVK Version', border: OutlineInputBorder()),
                      items: _dxvkFiles.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
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
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HUD Settings (Saved to Prefix/usr/opt/hud)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            dense: isLandscape,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('MANGOHUD', style: TextStyle(fontSize: 14)),
                            subtitle: const Text('Overlay for monitoring FPS, CPU, GPU, etc.', style: TextStyle(fontSize: 12)),
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
                            title: const Text('DXVK HUD', style: TextStyle(fontSize: 14)),
                            subtitle: const Text('DXVK overlay showing FPS, version, device info', style: TextStyle(fontSize: 12)),
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
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'installing: DXVK, VKD3D, and D8VK files will be Installed together',
                              style: TextStyle(fontSize: isLandscape ? 12 : 14, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasHudChanged && _hasDxvkChanged
                                    ? 'HUD settings and DXVK will be updated'
                                    : _hasHudChanged
                                        ? 'HUD settings will be saved to ${G.dataPath}/usr/opt/hud'
                                        : 'DXVK will be extracted',
                                style: TextStyle(fontSize: isLandscape ? 12 : 14, color: Colors.blue),
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
        TextButton(onPressed: _cancelDialog, child: const Text('Cancel')),
        if (_dxvkFiles.isNotEmpty && !_isLoading && _selectedDxvk != null)
          ElevatedButton(onPressed: _extractDxvk, child: const Text('Install')),
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
      'BOX64_DYNAREC_SAFEFLAGS': '2', 'BOX64_DYNAREC_FASTNAN': '0', 'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1', 'BOX64_DYNAREC_BIGBLOCK': '0', 'BOX64_DYNAREC_STRONGMEM': '2',
      'BOX64_DYNAREC_FORWARD': '128', 'BOX64_DYNAREC_CALLRET': '0', 'BOX64_DYNAREC_WAIT': '0',
      'BOX64_AVX': '0', 'BOX64_UNITYPLAYER': '1', 'BOX64_MMAP32': '0',
    },
    'Compatibility': {
      'BOX64_DYNAREC_SAFEFLAGS': '2', 'BOX64_DYNAREC_FASTNAN': '0', 'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1', 'BOX64_DYNAREC_BIGBLOCK': '0', 'BOX64_DYNAREC_STRONGMEM': '1',
      'BOX64_DYNAREC_FORWARD': '128', 'BOX64_DYNAREC_CALLRET': '0', 'BOX64_DYNAREC_WAIT': '1',
      'BOX64_AVX': '0', 'BOX64_UNITYPLAYER': '1', 'BOX64_MMAP32': '0',
    },
    'Intermediate': {
      'BOX64_DYNAREC_SAFEFLAGS': '2', 'BOX64_DYNAREC_FASTNAN': '1', 'BOX64_DYNAREC_FASTROUND': '0',
      'BOX64_DYNAREC_X87DOUBLE': '1', 'BOX64_DYNAREC_BIGBLOCK': '1', 'BOX64_DYNAREC_STRONGMEM': '0',
      'BOX64_DYNAREC_FORWARD': '128', 'BOX64_DYNAREC_CALLRET': '1', 'BOX64_DYNAREC_WAIT': '1',
      'BOX64_AVX': '0', 'BOX64_UNITYPLAYER': '0', 'BOX64_MMAP32': '1',
    },
  };

  List<bool> _coreSelections = [];
  int _availableCores = 8;
  bool _wineEsyncEnabled = false;
  List<Map<String, String>> _customVariables = [];
  String _selectedKnownVariable = '';
  final List<String> _knownWineVariables = [
    'WINEARCH', 'DXVK_ASYNC', 'adrenotool', 'GALLIUM_DRIVER', 'MESA_LOADER_DRIVER_OVERRIDE',
    'VK_LOADER_DEBUG', 'LD_DEBUG', 'ZINK_DEBUG', 'WINEDEBUG', 'MESA_VK_WSI_PRESENT_MODE',
    'WINEPREFIX', 'WINEESYNC', 'WINEFSYNC', 'WINE_NOBLOB', 'WINE_NO_CRASH_DIALOG',
    'WINEDLLOVERRIDES', 'WINEDLLPATH', 'WINE_MONO_CACHE_DIR', 'WINE_GECKO_CACHE_DIR',
    'WINEDISABLE', 'WINE_ENABLE'
  ];
  bool _debugEnabled = false;
  String _winedebugValue = '-all';
  final List<String> _winedebugOptions = ['-all', 'err', 'warn', 'fixme', 'all', 'trace', 'message', 'heap', 'fps', 'dx9', 'dx8'];
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
    return selectedIndices.isEmpty ? "0" : selectedIndices.join(',');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Environment settings saved and applied!')));
      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving environment settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
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
      Util.termWrite("echo 'export WINEESYNC=1' >> ${G.dataPath}/usr/opt/sync");
      Util.termWrite("echo 'export WINEESYNC_TERMUX=1' >> ${G.dataPath}/usr/opt/sync");
    } else {
      Util.termWrite("echo 'export WINEESYNC=0' >> ${G.dataPath}/usr/opt/sync");
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
                              const Text('Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: selectedPreset,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String>(value: 'Custom', child: Text('Custom')),
                                  ..._box64Presets.keys.map((presetName) {
                                    return DropdownMenuItem<String>(value: presetName, child: Text(presetName));
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
                        return _buildDynarecVariableWidget(variable, setState, localVariables, onVariableChanged: () {
                          setState(() {
                            selectedPreset = 'Custom';
                          });
                        });
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dynarec settings saved')));
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

  Widget _buildDynarecVariableWidget(Map<String, dynamic> variable, StateSetter setState, List<Map<String, dynamic>> localVariables, {VoidCallback? onVariableChanged}) {
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
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  return DropdownMenuItem<String>(value: value, child: Text(value));
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
                  if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                  return _knownWineVariables.where((variable) => variable.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Variable Name', border: OutlineInputBorder()),
                    onChanged: (value) => _newVarName = value,
                  );
                },
                onSelected: (String selection) => _newVarName = selection,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
                onChanged: (value) => _newVarValue = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (_newVarName.isNotEmpty && _newVarValue.isNotEmpty) {
                setState(() {
                  _customVariables.add({'name': _newVarName, 'value': _newVarValue});
                  _newVarName = '';
                  _newVarValue = '';
                });
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both variable name and value')));
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
                  title: const Text('Wine Esync'),
                  subtitle: const Text('Enable Wine Esync for better performance'),
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
                      const Text('CPU Cores', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          TextButton(onPressed: () {
                            setState(() {
                              _coreSelections = List.generate(_availableCores, (index) => true);
                            });
                          }, child: const Text('Select All')),
                          TextButton(onPressed: () {
                            setState(() {
                              _coreSelections = List.generate(_availableCores, (index) => false);
                            });
                          }, child: const Text('Clear All')),
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
                      const Text('Custom Variables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      OutlinedButton(onPressed: _addCustomVariable, child: const Text('Add Variable')),
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
                        subtitle: _debugEnabled ? const Text('Verbose logging enabled') : const Text('Quiet mode - minimal logging'),
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
                        const Text('WINEDEBUG Level', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _winedebugValue,
                          decoration: const InputDecoration(labelText: 'WINEDEBUG', border: OutlineInputBorder()),
                          items: _winedebugOptions.map((option) {
                            return DropdownMenuItem<String>(value: option, child: Text(option));
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save & Apply')),
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
  bool _turnipDri3Enabled = false;
  bool _wrapperDri3Enabled = false;
  bool _venusDri3Enabled = false;
  bool _virglEnabled = false;
  bool _androidVenusEnabled = true;
  String _defaultTurnipOpt = 'MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform';
  String _defaultVenusCommand = '--no-virgl --venus --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
  String _defaultVenusOpt = '';
  String _defaultVirglCommand = '--use-egl-surfaceless --use-gles --socket-path=\$CONTAINER_DIR/tmp/.virgl_test';
  String _defaultVirglOpt = 'GALLIUM_DRIVER=virpipe';
  bool _isX11Enabled = false;
  bool _virglServerRunning = false;
  bool _venusServerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _loadDriverFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkServerStatus());
  }

  Future<void> _checkServerStatus() async {
    await _updateVirglServerStatus();
    await _updateVenusServerStatus();
  }

  Future<void> _updateVirglServerStatus() async {
    try {
      final result = await Process.run(
        '${G.dataPath}/usr/bin/sh',
        ['-c', '${G.dataPath}/usr/bin/pgrep -a virgl_ | grep use-'],
      );
      setState(() {
        _virglServerRunning = result.stdout.toString().trim().isNotEmpty;
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
        ['-c', '${G.dataPath}/usr/bin/pgrep -a virgl_ | grep venus'],
      );
      setState(() {
        _venusServerRunning = result.stdout.toString().trim().isNotEmpty;
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
      
      if ((_selectedDriverType == 'turnip' || _selectedDriverType == 'wrapper') && _selectedDriverFile != null) {
        await _extractDriver();
      } else {
        await _applyGpuSettings();
      }
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPU driver settings saved and applied!')));
    } catch (e) {
      print('Error saving GPU settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
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
    Util.termWrite("echo 'export VK_ICD_FILENAMES=${G.dataPath}/usr/share/vulkan/icd.d/virtio_icd.aarch64.json' >> ${G.dataPath}/usr/opt/drv");
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
        Util.termWrite("mv '${G.dataPath}/usr/share/vulkan/icd.d/$_selectedDriverFile' '${G.dataPath}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json'");
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await _applyGpuSettings();
    } catch (e) {
      print('Error in _extractDriver: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error extracting driver: $e')));
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
      print('Found drivers directory at: $hostDir');
      final files = await dir.list().toList();
      final allDriverFiles = files
          .where((file) => file is File && RegExp(r'\.(tzst|tar\.gz|tgz|tar\.xz|txz|tar|zip|7z|json|so|ko)$').hasMatch(file.path))
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
      filteredFiles = _driverFiles.where((file) => file.toLowerCase().contains('turnip') || file.toLowerCase().contains('freedreno') || file.endsWith('.json')).toList();
    } else if (_selectedDriverType == 'wrapper') {
      filteredFiles = _driverFiles.where((file) => file.toLowerCase().contains('wrapper')).toList();
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
                      const Text('Driver Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDriverType,
                        decoration: const InputDecoration(labelText: 'Select Driver Type', border: OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'virgl', child: Row(children: [Icon(Icons.hardware, color: Colors.blue), SizedBox(width: 8), Text('VirGL (Virtual GL)')])),
                          DropdownMenuItem(value: 'turnip', child: Row(children: [Icon(Icons.grain, color: Colors.purple), SizedBox(width: 8), Text('Turnip (Vulkan)')])),
                          DropdownMenuItem(value: 'venus', child: Row(children: [Icon(Icons.hardware, color: Colors.orange), SizedBox(width: 8), Text('Venus (Vulkan)')])),
                          DropdownMenuItem(value: 'wrapper', child: Row(children: [Icon(Icons.wrap_text, color: Colors.green), SizedBox(width: 8), Text('Wrapper')])),
                        ],
                        onChanged: _onDriverTypeChanged,
                      ),
                    ],
                  ),
                ),
              ),
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
                              Text('Experimental Feature Under Development', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900])),
                              const SizedBox(height: 4),
                              Text('Venus driver is currently in development. Features may be unstable or incomplete.', style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_selectedDriverType == 'virgl')
                Card(
                  color: _virglServerRunning ? Colors.green[50] : Colors.red[50],
                  child: ListTile(
                    leading: Icon(_virglServerRunning ? Icons.check_circle : Icons.error, color: _virglServerRunning ? Colors.green : Colors.red),
                    title: const Text('VirGL Server'),
                    subtitle: Text(_virglServerRunning ? 'Running' : 'Not running', style: TextStyle(color: _virglServerRunning ? Colors.green : Colors.red)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.refresh), onPressed: () {
                          _startVirglServer();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restarting VirGL server...')));
                        }),
                        IconButton(icon: const Icon(Icons.stop), onPressed: _virglServerRunning ? () async {
                          Util.termWrite("pkill -f virgl_test_server");
                          await Future.delayed(const Duration(seconds: 1));
                          await _updateVirglServerStatus();
                        } : null),
                      ],
                    ),
                  ),
                ),
              if (_selectedDriverType == 'venus')
                Card(
                  color: _venusServerRunning ? Colors.green[50] : Colors.red[50],
                  child: ListTile(
                    leading: Icon(_venusServerRunning ? Icons.check_circle : Icons.error, color: _venusServerRunning ? Colors.green : Colors.red),
                    title: const Text('Venus Server'),
                    subtitle: Text(_venusServerRunning ? 'Running' : 'Not running', style: TextStyle(color: _venusServerRunning ? Colors.green : Colors.red)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.refresh), onPressed: () {
                          _startVenusServer();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restarting Venus server...')));
                        }),
                        IconButton(icon: const Icon(Icons.stop), onPressed: _venusServerRunning ? () async {
                          Util.termWrite("pkill -f virgl_test_server");
                          await Future.delayed(const Duration(seconds: 1));
                          await _updateVenusServerStatus();
                        } : null),
                      ],
                    ),
                  ),
                ),
              if (_selectedDriverType == 'wrapper' || _selectedDriverType == 'turnip') _buildDriverFileSelection(),
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
                    onChanged: _isX11Enabled ? (value) {
                      setState(() {
                        _turnipDri3Enabled = value;
                      });
                    } : null,
                  ),
                ),
              if (_selectedDriverType == 'wrapper')
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable DRI3 for Wrapper'),
                    subtitle: const Text('Direct Rendering Infrastructure v3'),
                    value: _wrapperDri3Enabled,
                    onChanged: _isX11Enabled ? (value) {
                      setState(() {
                        _wrapperDri3Enabled = value;
                      });
                    } : null,
                  ),
                ),
              if (_selectedDriverType == 'venus')
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable DRI3 for Venus'),
                    subtitle: const Text('Direct Rendering Infrastructure v3'),
                    value: _venusDri3Enabled,
                    onChanged: _isX11Enabled ? (value) {
                      setState(() {
                        _venusDri3Enabled = value;
                      });
                    } : null,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveAndExtract, child: const Text('Save & Apply')),
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
            const Text('Turnip Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_selectedDriverFile == null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Using built-in Turnip from: ${G.dataPath}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                  ],
                ),
              ),
            if (_selectedDriverFile != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Using custom Turnip driver: $_selectedDriverFile', style: const TextStyle(fontSize: 12, color: Colors.green))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultTurnipOpt,
              decoration: const InputDecoration(labelText: 'Turnip Environment Variables (without VK_ICD_FILENAMES)', hintText: 'Example: MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform', border: OutlineInputBorder()),
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
            const Text('VirGL Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVirglCommand,
              decoration: const InputDecoration(labelText: 'VirGL Server Parameters', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'VirGL Environment Variables', border: OutlineInputBorder()),
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
            const Text('Venus Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              initialValue: _defaultVenusCommand,
              decoration: const InputDecoration(labelText: 'Venus Server Parameters', hintText: 'Example: --no-virgl --venus --socket-path=\$CONTAINER_DIR/tmp/.virgl_test', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'Venus Environment Variables', hintText: 'Example: ANDROID_VENUS=1', border: OutlineInputBorder()),
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
            const Text('Wrapper Driver Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Wrapper driver provides compatibility layer for specific GPU architectures.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverFileSelection() {
    List<String> filteredFiles = _driverFiles.where((file) {
      if (_selectedDriverType == 'turnip') {
        return file.toLowerCase().contains('turnip') || file.toLowerCase().contains('freedreno') || file.endsWith('.json');
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
            Text(_selectedDriverType == 'turnip' ? 'Select Turnip Driver File' : 'Select Wrapper Driver File', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (!_isLoading && filteredFiles.isEmpty)
              Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                  const SizedBox(height: 8),
                  Text(_selectedDriverType == 'turnip' ? 'No turnip driver files found' : 'No wrapper driver files found', textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(_selectedDriverType == 'turnip' ? 'Please place turnip driver files in the drivers folder' : 'Please place wrapper driver files in the drivers folder', style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Refresh'), onPressed: _loadDriverFiles),
                ],
              ),
            if (!_isLoading && filteredFiles.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedDriverFile,
                decoration: InputDecoration(labelText: _selectedDriverType == 'turnip' ? 'Turnip Driver File' : 'Wrapper Driver File', border: const OutlineInputBorder()),
                items: filteredFiles.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
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

// Main Home Page
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
          title: Text(isLoadingComplete ? Util.getCurrentProp("name") as String? ?? widget.title : widget.title),
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
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.monitor), label: 'Terminal'),
                  NavigationDestination(icon: Icon(Icons.video_settings), label: 'Control'),
                ],
                onDestinationSelected: (index) {
                  G.pageIndex.value = index;
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// Setting Page
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final List<bool> _expandState = [false, false, false, false, false, false];
  double _avncScaleFactor = Util.getGlobal("avncScaleFactor") as double? ?? 0.0;

  void _showBackupRestoreDialog() {
    // Implementation would show backup/restore dialog
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
          isExpanded: _expandState[0],
          headerBuilder: (context, isExpanded) => ListTile(
            title: const Text('Advanced Settings'),
            subtitle: const Text('Restart after change'),
          ),
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
                    child: const Text('Reset Startup Command'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Attention'),
                          content: const Text('Confirm reset command?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () async {
                                await Util.setCurrentProp("boot", D.boot);
                                G.bootTextChange.value = !G.bootTextChange.value;
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Signal9 Error Page'),
                    onPressed: () async {
                      await Util.androidChannel.invokeMethod("launchSignal9Page", {});
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("name") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Container Name'),
                onChanged: (value) async {
                  await Util.setCurrentProp("name", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              ValueListenableBuilder(
                valueListenable: G.bootTextChange,
                builder: (context, v, child) => TextFormField(
                  maxLines: null,
                  initialValue: Util.getCurrentProp("boot") as String? ?? '',
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Startup Command'),
                  onChanged: (value) async {
                    await Util.setCurrentProp("boot", value);
                  },
                ),
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vnc") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'VNC Startup Command'),
                onChanged: (value) async {
                  await Util.setCurrentProp("vnc", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              const Text('Share usage hint'),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Copy Share Link'),
                    onPressed: () async {
                      final String? ip = await NetworkInfo().getWifiIP();
                      if (!context.mounted) return;
                      if (G.wasX11Enabled) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('X11 invalid hint')));
                        return;
                      }
                      if (ip == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot get IP address')));
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: (Util.getCurrentProp("vncUrl") as String? ?? '').replaceAll("localhost", ip))).then((value) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied')));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 16),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vncUrl") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Web Redirect URL'),
                onChanged: (value) async {
                  await Util.setCurrentProp("vncUrl", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getCurrentProp("vncUri") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'VNC Link'),
                onChanged: (value) async {
                  await Util.setCurrentProp("vncUri", value);
                },
              ),
              const SizedBox.square(dimension: 8),
            ]),
          ),
        ),
        ExpansionPanel(
          isExpanded: _expandState[1],
          headerBuilder: (context, isExpanded) => ListTile(
            title: const Text('Global Settings'),
            subtitle: const Text('Enable terminal editing'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                initialValue: (Util.getGlobal("termMaxLines") as int? ?? 1024).toString(),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Terminal Max Lines'),
                keyboardType: TextInputType.number,
                validator: (value) => Util.validateBetween(value, 1024, 2147483647, () async {
                  await G.prefs.setInt("termMaxLines", int.parse(value!));
                }),
              ),
              const SizedBox.square(dimension: 16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                initialValue: (Util.getGlobal("defaultAudioPort") as int? ?? 0).toString(),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'PulseAudio Port'),
                keyboardType: TextInputType.number,
                validator: (value) => Util.validateBetween(value, 0, 65535, () async {
                  await G.prefs.setInt("defaultAudioPort", int.parse(value!));
                }),
              ),
              const SizedBox.square(dimension: 16),
              SwitchListTile(
                title: const Text('Enable Terminal'),
                value: Util.getGlobal("isTerminalWriteEnabled") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("isTerminalWriteEnabled", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable Terminal Keypad'),
                value: Util.getGlobal("isTerminalCommandsEnabled") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("isTerminalCommandsEnabled", value);
                  setState(() {
                    G.terminalPageChange.value = !G.terminalPageChange.value;
                  });
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Terminal Sticky Keys'),
                value: Util.getGlobal("isStickyKey") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("isStickyKey", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Keep Screen On'),
                value: Util.getGlobal("wakelock") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("wakelock", value);
                  WakelockPlus.toggle(enable: value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              const Text('Restart required hint'),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Start with GUI'),
                value: Util.getGlobal("autoLaunchVnc") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("autoLaunchVnc", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Reinstall Boot Package'),
                value: Util.getGlobal("reinstallBootstrap") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("reinstallBootstrap", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Getifaddrs Bridge'),
                subtitle: const Text('Fix getifaddrs permission'),
                value: Util.getGlobal("getifaddrsBridge") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("getifaddrsBridge", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Fake UOS System'),
                value: Util.getGlobal("uos") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("uos", value);
                  setState(() {});
                },
              ),
            ]),
          ),
        ),
        ExpansionPanel(
          isExpanded: _expandState[2],
          headerBuilder: (context, isExpanded) => ListTile(title: const Text('Display Settings')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const SizedBox.square(dimension: 16),
              const Text('HiDPI advantages'),
              const SizedBox.square(dimension: 16),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultHidpiOpt") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'HiDPI Environment Variables'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultHidpiOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('HiDPI Support'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("isHidpiEnabled") as bool? ?? false,
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
              const Text('AVNC advantages'),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('AVNC Settings'),
                    onPressed: () async {
                      await AvncFlutter.launchPrefsPage();
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('About AVNC'),
                    onPressed: () async {
                      await AvncFlutter.launchAboutPage();
                    },
                  ),
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    onPressed: Util.getGlobal("avncResizeDesktop") as bool? ?? false ? null : () async {
                      final s = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
                      final w0 = max(s.width, s.height);
                      final h0 = min(s.width, s.height);
                      String w = (w0 * 0.75).round().toString();
                      String h = (h0 * 0.75).round().toString();
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Resolution Settings'),
                            content: SingleChildScrollView(
                              child: Column(children: [
                                Text("Device screen resolution ${w0.round()}x${h0.round()}"),
                                const SizedBox.square(dimension: 8),
                                TextFormField(
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  initialValue: w,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Width'),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => Util.validateBetween(value, 200, 7680, () {
                                    w = value!;
                                  }),
                                ),
                                const SizedBox.square(dimension: 8),
                                TextFormField(
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  initialValue: h,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Height'),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => Util.validateBetween(value, 200, 7680, () {
                                    h = value!;
                                  }),
                                ),
                              ]),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () async {
                                  Util.termWrite("""sed -i -E "s@(geometry)=.*@\\1=${w}x${h}@" /etc/tigervnc/vncserver-config-tmoe
sed -i -E "s@^(VNC_RESOLUTION)=.*@\\1=${w}x${h}@" \$(command -v startvnc)""");
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${w}x${h}. Apply on next launch")));
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('AVNC Resolution'),
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Use AVNC by Default'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("useAvnc") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("useAvnc", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('AVNC Screen Resize'),
                value: Util.getGlobal("avncResizeDesktop") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("avncResizeDesktop", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              ListTile(
                title: const Text('AVNC Resize Factor'),
                onTap: () {},
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('AVNC resize factor value ${pow(4, _avncScaleFactor).toStringAsFixed(2)}x'),
                    const SizedBox(height: 12),
                    Slider(
                      value: _avncScaleFactor,
                      min: -1,
                      max: 1,
                      divisions: 96,
                      onChangeEnd: (double value) {
                        G.prefs.setDouble("avncScaleFactor", value);
                      },
                      onChanged: Util.getGlobal("avncResizeDesktop") as bool? ?? false ? (double value) {
                        _avncScaleFactor = value;
                        setState(() {});
                      } : null,
                    ),
                  ],
                ),
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              const Text('Termux X11 advantages'),
              const SizedBox.square(dimension: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(
                    style: D.commandButtonStyle,
                    child: const Text('Termux X11 Preferences'),
                    onPressed: () async {
                      await X11Flutter.launchX11PrefsPage();
                    },
                  ),
                ],
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Use Termux X11 by Default'),
                subtitle: const Text('Disable VNC'),
                value: Util.getGlobal("useX11") as bool? ?? false,
                onChanged: (value) {
                  G.prefs.setBool("useX11", value);
                  if (!value && Util.getGlobal("dri3") as bool? ?? false) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 16),
            ]),
          ),
        ),
        ExpansionPanel(
          isExpanded: _expandState[3],
          headerBuilder: (context, isExpanded) => ListTile(
            title: const Text('Graphics Acceleration'),
            subtitle: const Text('Experimental feature'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const Text('Graphics acceleration hint'),
              const SizedBox.square(dimension: 16),
              const Text('VirGL server parameters', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVirglCommand") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'VirGL Server Parameters'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVirglCommand", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVirglOpt") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'VirGL Environment Variables'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVirglOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable VirGL'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("virgl") as bool? ?? false,
                onChanged: (value) {
                  if (value) {
                    G.prefs.setBool("venus", false);
                    G.prefs.setBool("turnip", false);
                    if (Util.getGlobal("dri3") as bool? ?? false) {
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
              const Text('Venus advantages', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              const Text('Venus advantages'),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVenusCommand") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Venus Server Parameters'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVenusCommand", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultVenusOpt") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Venus Environment Variables'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultVenusOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable Venus'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("venus") as bool? ?? false,
                onChanged: (value) {
                  if (value) {
                    G.prefs.setBool("virgl", false);
                    G.prefs.setBool("turnip", false);
                  }
                  G.prefs.setBool("venus", value);
                  if (!value && Util.getGlobal("dri3") as bool? ?? false) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable Android Venus'),
                subtitle: const Text('Venus advantages'),
                value: Util.getGlobal("androidVenus") as bool? ?? false,
                onChanged: (value) async {
                  await G.prefs.setBool("androidVenus", value);
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              const Text('Turnip advantages', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox.square(dimension: 8),
              TextFormField(
                maxLines: null,
                initialValue: Util.getGlobal("defaultTurnipOpt") as String? ?? '',
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Turnip Environment Variables'),
                onChanged: (value) async {
                  await G.prefs.setString("defaultTurnipOpt", value);
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable Turnip Zink'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("turnip") as bool? ?? false,
                onChanged: (value) async {
                  if (value) {
                    G.prefs.setBool("virgl", false);
                    G.prefs.setBool("venus", false);
                  }
                  G.prefs.setBool("turnip", value);
                  if (!value && Util.getGlobal("dri3") as bool? ?? false) {
                    G.prefs.setBool("dri3", false);
                  }
                  setState(() {});
                },
              ),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Enable DRI3'),
                subtitle: const Text('Apply on next launch'),
                value: Util.getGlobal("dri3") as bool? ?? false,
                onChanged: (value) async {
                  final bool useX11 = Util.getGlobal("useX11") as bool? ?? false;
                  final bool turnip = Util.getGlobal("turnip") as bool? ?? false;
                  final bool venus = Util.getGlobal("venus") as bool? ?? false;
                  if (value && !(useX11 && (turnip || venus))) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DRI3 requirement')));
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
        ExpansionPanel(
          isExpanded: _expandState[4],
          headerBuilder: (context, isExpanded) => ListTile(
            title: const Text('Windows App Support'),
            subtitle: const Text('Experimental feature'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const Text('Hangover description'),
              const SizedBox.square(dimension: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton(style: D.commandButtonStyle, child: const Text('Environment Settings'), onPressed: () => showDialog(context: context, builder: (context) => EnvironmentDialog())),
                  OutlinedButton(style: D.commandButtonStyle, child: const Text('GPU Drivers'), onPressed: () => showDialog(context: context, builder: (context) => GpuDriversDialog())),
                  OutlinedButton(style: D.commandButtonStyle, child: const Text('Install DXVK'), onPressed: () => showDialog(context: context, builder: (context) => DxvkDialog())),
                  OutlinedButton(style: D.commandButtonStyle, child: const Text('Wine bionic Settings🍷'), onPressed: () => showDialog(context: context, builder: (context) => WineSettingsDialog())),
                ],
              ),
              const SizedBox.square(dimension: 16),
              const Divider(height: 2, indent: 8, endIndent: 8),
              const SizedBox.square(dimension: 16),
              const Text('Wine commands hint'),
              const SizedBox.square(dimension: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: D.wineCommands.asMap().entries.map<Widget>((e) {
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
                child: const Text('Install Hangover Stable (10.14)'),
                onPressed: () async {
                  Util.termWrite("bash /extra/install-hangover-stable");
                  G.pageIndex.value = 0;
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: const Text('Install Hangover Latest'),
                onPressed: () async {
                  Util.termWrite("bash /extra/install-hangover");
                  G.pageIndex.value = 0;
                },
              ),
              OutlinedButton(
                style: D.commandButtonStyle,
                child: const Text('Uninstall Hangover'),
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
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("sudo apt autoremove --purge -y hangover*");
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wine hangover deleted'), backgroundColor: Colors.red));
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
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf /opt/wine");
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wine deleted'), backgroundColor: Colors.red));
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
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf ${G.dataPath}/usr/opt/wine");
                            Util.termWrite("rm -rf ${G.dataPath}/home/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wine deleted'), backgroundColor: Colors.red));
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
                child: const Text('Clear Wine Data'),
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
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            G.pageIndex.value = 0;
                            Util.termWrite("rm -rf ~/.wine");
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wine prefix deleted'), backgroundColor: Colors.red));
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
              const Text('Restart required hint'),
              const SizedBox.square(dimension: 8),
              SwitchListTile(
                title: const Text('Switch to Japanese'),
                subtitle: const Text('システムを日本語に切り替える'),
                value: Util.getGlobal("isJpEnabled") as bool? ?? false,
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
        ExpansionPanel(
          isExpanded: _expandState[5],
          headerBuilder: (context, isExpanded) => ListTile(
            title: const Text('System Backup & Restore'),
            subtitle: const Text('Backup and restore description'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('Backup restore warning'),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.backup),
                      label: const Text('Backup System'),
                      onPressed: _showBackupRestoreDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore System'),
                      onPressed: _showBackupRestoreDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Backup note', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Info Page
class InfoPage extends StatefulWidget {
  final bool openFirstInfo;
  const InfoPage({super.key, this.openFirstInfo = false});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<bool> _expandState = [false, false, false, false, false];
  late AudioPlayer _gamesMusicPlayer;
  bool _isGamesMusicPlaying = false;
  bool _gamesLoaded = false;
  bool _isLoadingGames = false;
  
  @override
  void initState() {
    super.initState();
    _expandState[0] = widget.openFirstInfo;
    _gamesMusicPlayer = AudioPlayer();
    _setupMusicPlayer();
  }

  Future<void> _setupMusicPlayer() async {
    try {
      await _gamesMusicPlayer.setReleaseMode(ReleaseMode.loop);
      await _gamesMusicPlayer.setVolume(0.6);
    } catch (_) {}
  }

  Future<void> _startGamesMusic() async {
    if (_isGamesMusicPlaying) return;
    try {
      await _gamesMusicPlayer.play(AssetSource('music.mp3'));
      setState(() => _isGamesMusicPlaying = true);
    } catch (_) {
      setState(() => _isGamesMusicPlaying = true);
    }
  }

  Future<void> _stopGamesMusic() async {
    if (!_isGamesMusicPlaying) return;
    try {
      await _gamesMusicPlayer.stop();
      setState(() => _isGamesMusicPlaying = false);
    } catch (_) {
      setState(() => _isGamesMusicPlaying = false);
    }
  }

  Future<void> _loadGames() async {
    if (_isLoadingGames || _gamesLoaded) return;
    setState(() => _isLoadingGames = true);
    await Future.delayed(const Duration(milliseconds: 50));
    await _startGamesMusic();
    setState(() {
      _gamesLoaded = true;
      _isLoadingGames = false;
    });
  }

  void _unloadGames() {
    setState(() {
      _gamesLoaded = false;
      _isLoadingGames = false;
    });
    _stopGamesMusic();
  }

  @override
  void dispose() {
    _stopGamesMusic();
    _gamesMusicPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (panelIndex, isExpanded) {
        if (panelIndex == 1) {
          if (isExpanded) {
            // Do not load games automatically
          } else {
            _unloadGames();
          }
        }
        setState(() => _expandState[panelIndex] = isExpanded);
      },
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) => ListTile(title: const Text('User Manual')),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const Text('First load instructions'),
                const SizedBox.square(dimension: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: [
                    OutlinedButton(style: D.commandButtonStyle, child: const Text('Request Storage Permission'), onPressed: () => Permission.storage.request()),
                    OutlinedButton(style: D.commandButtonStyle, child: const Text('Request All Files Access'), onPressed: () => Permission.manageExternalStorage.request()),
                    OutlinedButton(style: D.commandButtonStyle, child: const Text('Ignore Battery Optimization'), onPressed: () => Permission.ignoreBatteryOptimizations.request()),
                  ],
                ),
                const SizedBox.square(dimension: 16),
                const Text('Update request'),
                const SizedBox.square(dimension: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: D.links.asMap().entries.map<Widget>