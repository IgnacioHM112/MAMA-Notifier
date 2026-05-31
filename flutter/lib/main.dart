import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';
import 'wifi_monitor.dart';
import 'foreground_service.dart';
import 'event_model.dart'; // Importante: Asegurar que este import esté presente

const String wifiTaskName = 'wifiMonitorTask';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[Workmanager] Ejecutando tarea de fondo: $task');
    final apiService = ApiService();
    final safeSsid = inputData?['safeSsid'] as String?;
    final userId = inputData?['userId'] as String?;
    final deviceId = inputData?['deviceId'] as String?;
    final zoneName = inputData?['zoneName'] as String? ?? 'Casa';

    if (safeSsid == null || userId == null || deviceId == null) {
      print('[Workmanager] Datos insuficientes para el monitoreo.');
      return Future.value(true);
    }

    final monitor = WifiMonitor(
      apiService: apiService,
      safeSsid: safeSsid,
      userId: userId,
      deviceId: deviceId,
      zoneName: zoneName,
    );

    await monitor.checkAndSendEvent(background: true);
    return Future.value(true);
  });
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MamaNotifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token = await _apiService.getStoredToken();
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_token == null) return const LoginPage();
    return const MainContainer();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    dynamic result;
    if (_isLogin) {
      result = await _apiService.login(email, password);
    } else {
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa tu nombre.')));
        setState(() => _isLoading = false);
        return;
      }
      result = await _apiService.register(name, email, password);
    }

    if (result != null) {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainContainer()));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error. Verifica tus datos.')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active, size: 80, color: Colors.indigo),
              const SizedBox(height: 16),
              Text(
                _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (!_isLogin)
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              if (!_isLogin) const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                    ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const MonitorTab(),
    const ContactsTab(),
    const HistoryTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Monitor'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contactos'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// --- TAB: MONITOR ---
class MonitorTab extends StatefulWidget {
  const MonitorTab({super.key});

  @override
  State<MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends State<MonitorTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  bool _monitoringEnabled = false;
  String _statusMessage = 'Configura tu red Wi-Fi segura para empezar.';
  String? _userId;
  String? _deviceId;
  WifiMonitor? _liveMonitor;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _loadData();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mama_notifier_channel',
        channelName: 'Mama-Notifier Guardián',
        channelDescription: 'Mantiene el monitoreo de Wi-Fi activo.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void dispose() {
    _liveMonitor?.stopForegroundMonitoring();
    super.dispose();
  }

  Future<void> _loadData() async {
    final ssid = await _apiService.getSafeSsid();
    final zone = await _apiService.getZoneName();
    final userId = await _apiService.getUserId();
    final deviceId = await _apiService.getDeviceId() ?? const Uuid().v4();
    if (await _apiService.getDeviceId() == null) await _apiService.saveDeviceId(deviceId);

    final bool isRunning = await FlutterForegroundTask.isRunningService;

    setState(() {
      _ssidController.text = ssid ?? '';
      _zoneController.text = zone ?? 'Casa';
      _userId = userId;
      _deviceId = deviceId;
      _monitoringEnabled = isRunning;
    });
  }

  Future<void> _toggleMonitoring(bool start) async {
    final ssid = _ssidController.text.trim();
    final zone = _zoneController.text.trim().isEmpty ? 'Casa' : _zoneController.text.trim();

    if (start) {
      if (ssid.isEmpty) {
        _updateStatus('⚠️ Por favor, ingresa el nombre de tu Wi-Fi.');
        return;
      }
      await _apiService.saveSafeSsid(ssid);
      await _apiService.saveZoneName(zone);

      // 1. Iniciar Servicio Guardián (Foreground)
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Modo Guardián Activo',
          notificationText: 'Monitoreando red Wi-Fi: $ssid',
          callback: startCallback,
        );
      }

      // 2. Monitoreo en Vivo (UI)
      _liveMonitor = WifiMonitor(
        apiService: _apiService,
        safeSsid: ssid,
        userId: _userId!,
        deviceId: _deviceId!,
        zoneName: zone,
      );
      await _liveMonitor?.startForegroundMonitoring();
      
      _updateStatus('🚀 Guardián activado. Puedes cerrar la app.');
    } else {
      await FlutterForegroundTask.stopService();
      await _liveMonitor?.stopForegroundMonitoring();
      _liveMonitor = null;
      _updateStatus('🛑 Monitoreo desactivado.');
    }
    setState(() => _monitoringEnabled = start);
  }

  Future<void> _checkNow() async {
    if (_userId == null || _deviceId == null) return;
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty) return;
    _updateStatus('🔍 Verificando red...');
    
    final payload = EventPayload(
      userId: _userId!,
      deviceId: _deviceId!,
      eventType: 'manual_check', 
      zoneName: _zoneController.text.trim().isEmpty ? 'Casa' : _zoneController.text.trim(),
      timestamp: DateTime.now(),
    );
    
    final success = await _apiService.sendLocationEvent(payload);
    final isSafe = await WifiMonitor(
      apiService: _apiService,
      safeSsid: ssid,
      userId: _userId!,
      deviceId: _deviceId!,
    ).isConnectedToSafeWifi();

    _updateStatus('✅ Prueba enviada (success=$success). Estado Wi-Fi: ${isSafe ? "CONECTADO" : "FUERA DE RANGO"}');
  }

  void _updateStatus(String msg) => setState(() => _statusMessage = msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoreo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              color: Colors.indigo[600],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.white, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El "Modo Guardián" permite que la app te proteja aunque la cierres del todo.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                labelText: 'Nombre de Wi-Fi Seguro (SSID)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _zoneController,
              decoration: InputDecoration(
                labelText: 'Nombre de este lugar (ej: Casa, Oficina)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleMonitoring(!_monitoringEnabled),
                    icon: Icon(_monitoringEnabled ? Icons.shield : Icons.shield_outlined),
                    label: Text(_monitoringEnabled ? 'Detener Guardián' : 'Activar Modo Guardián'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _monitoringEnabled ? Colors.red[50] : Colors.green[50],
                      foregroundColor: _monitoringEnabled ? Colors.red : Colors.green,
                      minimumSize: const Size(0, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkNow,
              icon: const Icon(Icons.sync),
              label: const Text('Verificar ahora (Manual)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  const Text('ESTADO ACTUAL', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '⚠️ Importante: Para que el Guardián sea efectivo, desactiva el "Ahorro de batería" para esta App en los ajustes de tu teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB: CONTACTOS ---
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final ApiService _apiService = ApiService();
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await _apiService.getContacts();
    setState(() {
      _contacts = data;
      _isLoading = false;
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final arrivalCtrl = TextEditingController(text: '¡Hola! {user} llegó a su destino. ✅');
    final departureCtrl = TextEditingController(text: '¡Hola! {user} está volviendo. 🏠');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nuevo Contacto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'WhatsApp (ej: +549...)')),
                const SizedBox(height: 16),
                const Text('Mensajes Personalizados:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: arrivalCtrl, decoration: const InputDecoration(labelText: 'Al llegar')),
                TextField(controller: departureCtrl, decoration: const InputDecoration(labelText: 'Al salir')),
                if (isSaving) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isSaving 
                ? null 
                : () async {
                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nombre y Teléfono son obligatorios'))
                      );
                      return;
                    }
                    
                    setStateDialog(() => isSaving = true);
                    final success = await _apiService.addContact(
                      nameCtrl.text, 
                      phoneCtrl.text, 
                      arrivalCtrl.text, 
                      departureCtrl.text
                    );
                    
                    if (success) {
                      if (mounted) Navigator.pop(ctx);
                      _fetch();
                    } else {
                      setStateDialog(() => isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error al guardar contacto'))
                        );
                      }
                    }
                  },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Contactos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(child: Text('Aún no tienes contactos.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  itemBuilder: (ctx, i) {
                    final c = _contacts[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(c['contact_name']),
                        subtitle: Text(c['phone_number']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _apiService.deleteContact(c['id']);
                            _fetch();
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }
}

// --- TAB: HISTORIAL ---
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await _apiService.getLogs();
    setState(() {
      _logs = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No hay actividad reciente.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final l = _logs[i];
                    final isArrival = l['event_type'] == 'llegada';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isArrival ? Icons.login : Icons.logout,
                          color: isArrival ? Colors.green : Colors.orange,
                        ),
                        title: Text('Aviso a ${l['recipient']}'),
                        subtitle: Text(l['timestamp'].toString().substring(0, 16)),
                        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ),
                    );
                  },
                ),
    );
  }
}

// --- TAB: PERFIL ---
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _apiService = ApiService();
  String _userName = 'Cargando...';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _apiService.getUserName();
    final id = await _apiService.getUserId();
    setState(() {
      _userName = name ?? 'Usuario';
      _userId = id ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 16),
            Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('ID: $_userId', style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            const Text(
              'Mama-Notifier v3.5.0\nDiseñado para tu seguridad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await _apiService.logout();
                if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthWrapper()), (r) => false);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
