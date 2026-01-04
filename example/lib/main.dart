import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:openapi/openapi.dart';
import 'token_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart ACDC Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Dart ACDC Example'),
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
  final MockTokenProvider _tokenProvider = MockTokenProvider();
  late Openapi _client;
  late Dio _dio;

  // State
  bool _isLoading = false;
  String? _error;
  List<Post> _posts = [];
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  // Settings
  bool _isCacheEnabled = true;
  final LogLevel _logLevel = LogLevel.info;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String message, LogLevel level, Map<String, dynamic>? metadata) {
    if (!mounted) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final metaStr = metadata != null ? ' ${_formatMetadata(metadata)}' : '';

    setState(() {
      // Color code logs based on level or content
      _logs.add('[$timestamp] [$level] $message$metaStr');

      // Auto-scroll to bottom
      if (_logScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Also print to console for debugging
    debugPrint('[$level] $message $metaStr');
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    final type = metadata['type'];
    switch (type) {
      case 'request':
        return '{${metadata['method']} ${metadata['url']}}';
      case 'response':
        final cache = metadata['from_cache'] == true ? ' [CACHE]' : '';
        return '{${metadata['statusCode']} in ${metadata['duration_ms']}ms$cache}';
      case 'error':
        return '{${metadata['error_type']}: ${metadata['statusCode'] ?? 'N/A'}}';
      default:
        return metadata.toString();
    }
  }

  Future<void> _initializeClient() async {
    _dio = await AcdcClientBuilder()
        .withBaseUrl('https://jsonplaceholder.typicode.com')
        .withLogger(_addLog)
        .withLogLevel(_logLevel)
        // Authentication Configuration
        .withTokenProvider(_tokenProvider)
        // Since JSONPlaceholder doesn't support actual OAuth, we simulate a refresh
        // loop that just returns new mock tokens.
        .withCustomTokenRefresh((refreshToken) async {
          _addLog('Executing custom token refresh...', LogLevel.info, null);
          await Future.delayed(const Duration(milliseconds: 500));
          return TokenRefreshResult(
            accessToken:
                'refreshed_access_${DateTime.now().millisecondsSinceEpoch}',
            refreshToken:
                'refreshed_refresh_${DateTime.now().millisecondsSinceEpoch}',
          );
        })
        // Caching Configuration
        .withCache(
          CacheConfig(
            // Enable/disable based on UI toggle
            ttl: _isCacheEnabled ? const Duration(minutes: 5) : Duration.zero,
            // Since we use mock tokens that aren't real JWTs, we must provide
            // a way to identify the user for cache isolation.
            userIdProvider: (token) async => 'mock_user_123',
          ),
        )
        .build();

    if (!mounted) return;

    setState(() {
      _client = Openapi(dio: _dio);
    });

    _addLog('ACDC Client re-initialized', LogLevel.info, {
      'cache': _isCacheEnabled,
      'auth': _tokenProvider.isLoggedIn ? 'LoggedIn' : 'LoggedOut',
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _login() async {
    await _tokenProvider.login();
    _addLog('User logged in locally', LogLevel.info, null);
    // Re-initialize to ensure auth interceptor picks up new state or token provider is ready
    await _initializeClient();
    // In ACDC, the AuthInterceptor checks TokenProvider on every request,
    // so we don't strictly *need* to rebuild the client, but for this demo
    // we want to log the state change clearly.
    setState(() {});
  }

  Future<void> _logout() async {
    // Use the auth manager to logout
    if (_dio.auth.isConfigured) {
      await _dio.auth.logout();
      _addLog('User logged out via dio.auth.logout()', LogLevel.info, null);
    } else {
      await _tokenProvider.clearTokens();
      _addLog('User logged out (manual clear)', LogLevel.info, null);
    }
    setState(() {});
  }

  Future<void> _fetchPosts({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (forceRefresh) {
        // Add cache control header to force network request
        _dio.options.extra.addAll({
          'force_refresh': true,
          'dio_cache_force_refresh': true,
        });

        // Note: The generated client might not expose Options easily for every method.
        // If we can't pass options, we can rely on standard cache behavior or
        // clear the cache manually:
        await _dio.cache.clearCache();
        _addLog('Cache cleared before fetch', LogLevel.info, null);
      } else {
        // Reset force refresh flags
        _dio.options.extra.remove('force_refresh');
        _dio.options.extra.remove('dio_cache_force_refresh');
      }

      // 3. Use the generated API
      final response = await _client.getDefaultApi().getPosts();

      setState(() {
        _posts = response.data?.toList() ?? [];
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

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _tokenProvider.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
                          Row(
                            children: [
                              Icon(
                                isLoggedIn ? Icons.check_circle : Icons.cancel,
                                color: isLoggedIn ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(isLoggedIn ? 'Logged In' : 'Logged Out'),
                              const Spacer(),
                              if (!isLoggedIn)
                                ElevatedButton(
                                  onPressed: _login,
                                  child: const Text('Login'),
                                )
                              else
                                OutlinedButton(
                                  onPressed: _logout,
                                  child: const Text('Logout'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cache Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Caching',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SwitchListTile(
                            title: const Text('Enable Cache'),
                            subtitle: const Text('TTL: 5 mins'),
                            value: _isCacheEnabled,
                            onChanged: (val) {
                              setState(() => _isCacheEnabled = val);
                              _initializeClient();
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _fetchPosts(forceRefresh: false),
                    icon: const Icon(Icons.download),
                    label: const Text('Fetch Posts (Cache Preferred)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _fetchPosts(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Force Network Fetch'),
                  ),

                  const Divider(height: 32),

                  // Logs Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Logs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: _clearLogs,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),

                  // Logs List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: _logScrollController,
                              padding: const EdgeInsets.all(8),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    _logs[index],
                                    style: const TextStyle(
                                      color: Colors.lightGreenAccent,
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
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
                  child: _posts.isEmpty
                      ? const Center(child: Text('Fetch posts to view data'))
                      : ListView.builder(
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text('\${post.id}')),
                              title: Text(post.title ?? ''),
                              subtitle: Text(
                                post.body ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
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
