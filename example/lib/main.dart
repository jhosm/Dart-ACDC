import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:talker_flutter/talker_flutter.dart' as talker_pkg;
// ignore: avoid_web_libraries_in_flutter
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'google_tasks_auth_helper.dart';
import 'logging/talker_log_delegate.dart';

const String kRedirectUrl = 'dartacdc://callback';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart ACDC Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Google Tasks API Demo'),
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
  // Dependencies
  final SecureTokenProvider _tokenProvider = const SecureTokenProvider();
  final TextEditingController _clientIdController = TextEditingController();
  final talker_pkg.Talker _talker = talker_pkg.TalkerFlutter.init();

  late Dio _dio;

  // State
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  // Data State
  List<Map<String, dynamic>> _taskLists = [];

  // Settings
  final LogLevel _logLevel = LogLevel.info;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _initializeClient();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await _tokenProvider.getAccessToken();
    if (mounted) {
      setState(() {
        _isLoggedIn = token != null;
      });
    }
  }

  Future<void> _initializeClient() async {
    _dio = await AcdcClientBuilder()
        .withBaseUrl('https://tasks.googleapis.com/tasks/v1')
        .withLogDelegate(TalkerLogDelegate(_talker))
        .withLogLevel(_logLevel)
        .withTokenProvider(_tokenProvider)
        .withCache(
          CacheConfig(
            ttl: const Duration(minutes: 5),
            userIdProvider: (token) async => 'google_user',
          ),
        )
        .build();

    _talker.info('ACDC Client re-initialized', {
      'cache': true,
      'auth': _isLoggedIn ? 'LoggedIn' : 'LoggedOut',
    });
  }

  Future<void> _login() async {
    final clientId = _clientIdController.text.trim();

    if (clientId.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Client ID Required'),
          content: const Text(
            'Please enter your Google Client ID to proceed.\n\n'
            'Ensure you have configured "Authorized JavaScript origins" in Google Cloud Console if running on Web.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authHelper = GoogleTasksAuthHelper(
        clientId: clientId,
        redirectUrl: kRedirectUrl,
      );

      final accessToken = await authHelper.authenticate();
      await _tokenProvider.setTokens(accessToken: accessToken);

      setState(() {
        _isLoggedIn = true;
      });

      _talker.info('User logged in & tokens stored securely');
      await _initializeClient();
      await _fetchData(forceRefresh: false);
    } catch (e, st) {
      setState(() {
        _error = 'Login Failed: $e';
      });
      _talker.handle(e, st, 'Login failed');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_dio.auth.isConfigured) {
      await _dio.auth.logout();
      _talker.info('User logged out via dio.auth.logout()');
    } else {
      await _tokenProvider.clearTokens();
      _talker.info('User logged out (manual clear)');
    }

    setState(() {
      _isLoggedIn = false;
      _taskLists = [];
    });
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!_isLoggedIn) {
      setState(() {
        _error = 'Please login first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (forceRefresh) {
        _dio.options.extra.addAll({
          'force_refresh': true,
          'dio_cache_force_refresh': true,
        });
        await _dio.cache.clearCache();
        _talker.info('Cache cleared before fetch');
      } else {
        _dio.options.extra.remove('force_refresh');
        _dio.options.extra.remove('dio_cache_force_refresh');
      }

      // Fetch Task Lists
      // https://tasks.googleapis.com/tasks/v1/users/@me/lists
      final response = await _dio.get('/users/@me/lists');

      final items =
          (response.data['items'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      setState(() {
        _taskLists = items;
      });

      _talker.info('Task Lists fetched successfully', {
        'count': _taskLists.length,
        'cached': response.extra['from_cache'] ?? false,
      });
    } on AcdcException catch (e) {
      setState(() {
        _error = 'ACDC Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPublicData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch data from public API with max-age=10
      // We pass an empty Authorization header to skip the AuthInterceptor's
      // automatic token injection.
      final response = await _dio.get(
        'https://httpbin.org/cache/10',
        options: Options(headers: {'Authorization': ''}),
      );

      final dataStr = response.data.toString();
      final preview = dataStr.length > 50
          ? '${dataStr.substring(0, 50)}...'
          : dataStr;

      _talker.info('Public Data fetched (max-age: 10s)', {
        'status': response.statusCode,
        'cached': response.extra['from_cache'] ?? false,
        'data': preview,
      });
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) {
        _talker.handle(e, st, 'Public API not found (404)');
      } else {
        _talker.handle(e, st, 'Public API Error');
      }
      setState(() {
        _error = 'Public Call Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEtagData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch data from public API with ETag
      // httpbin.org/etag/{etag} returns the provided etag in header.
      // Subsequent calls with If-None-Match should return 304.
      final response = await _dio.get(
        'https://httpbin.org/etag/test-etag-123',
        options: Options(headers: {'Authorization': ''}),
      );

      final dataStr = response.data.toString();
      final preview = dataStr.length > 50
          ? '${dataStr.substring(0, 50)}...'
          : dataStr;

      _talker.info('Public ETag Data fetched', {
        'status': response.statusCode,
        'cached': response.extra['from_cache'] ?? false,
        'data': preview,
      });
    } on DioException catch (e, st) {
      _talker.handle(e, st, 'Public ETag API Error');
      setState(() {
        _error = 'Public Call Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Open Talker Logs',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => talker_pkg.TalkerScreen(talker: _talker),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-initialize Client',
            onPressed: _initializeClient,
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel: Controls & Logs
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Auth Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentication',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          if (!_isLoggedIn)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: TextField(
                                controller: _clientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Google Client ID',
                                  hintText: 'Enter your Client ID',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          if (!_isLoggedIn)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Setup Required:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '1. Add Client ID above.\n'
                                      '2. Add ${kIsWeb ? web.window.location.origin : "App Origin"} to "Authorized JavaScript origins" in Google Console.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Icon(
                                _isLoggedIn ? Icons.check_circle : Icons.cancel,
                                color: _isLoggedIn ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(_isLoggedIn ? 'Logged In' : 'Logged Out'),
                              const Spacer(),
                              if (!_isLoggedIn)
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _login,
                                  icon: const Icon(Icons.login),
                                  label: const Text('Login with Google'),
                                )
                              else
                                OutlinedButton(
                                  onPressed: _isLoading ? null : _logout,
                                  child: const Text('Logout'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading || !_isLoggedIn
                                  ? null
                                  : () => _fetchData(forceRefresh: false),
                              icon: const Icon(Icons.download),
                              label: const Text('Fetch Data (Cache Preferred)'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading || !_isLoggedIn
                                  ? null
                                  : () => _fetchData(forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Force Network Fetch'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Public API Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Public API Test',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Calls httpbin.org',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _fetchPublicData,
                                icon: const Icon(Icons.public),
                                label: const Text('Fetch (Max-Age: 10s)'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _fetchEtagData,
                                icon: const Icon(Icons.cached),
                                label: const Text('Fetch (ETag)'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Right Panel: Content
          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                if (_error != null)
                  Container(
                    color: Colors.red.shade50,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: !_isLoggedIn
                      ? const Center(
                          child: Text('Please log in with Google to view data'),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              'My Task Lists',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            if (_taskLists.isEmpty && !_isLoading)
                              const Center(child: Text('No Task Lists found.')),
                            ..._taskLists.map((list) {
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.list_alt),
                                  title: Text(list['title'] ?? 'Untitled List'),
                                  subtitle: Text('ID: ${list['id']}'),
                                  trailing: Text(
                                    'Updated: ${list['updated']?.substring(0, 10) ?? 'N/A'}',
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
