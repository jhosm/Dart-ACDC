import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:openapi/openapi.dart';

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
  late final Openapi _client;
  bool _isLoading = false;
  String? _error;
  List<Post> _posts = [];
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

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
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final metaStr = metadata != null ? ' ${_formatMetadata(metadata)}' : '';

    setState(() {
      _logs.add('[$timestamp] [$level] $message$metaStr');

      // Auto-scroll to bottom
      if (_logScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    });

    // Also print to console for debugging
    debugPrint('[$level] $message $metaStr');
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    // Format specific metadata types for better readability
    final type = metadata['type'];
    switch (type) {
      case 'request':
        return '{${metadata['method']} ${metadata['url']}}';
      case 'response':
        return '{${metadata['statusCode']} in ${metadata['duration_ms']}ms}';
      case 'error':
        return '{${metadata['error_type']}: ${metadata['statusCode'] ?? 'N/A'}}';
      case 'slow_request':
        return '{${metadata['duration_ms']}ms > ${metadata['threshold_ms']}ms}';
      case 'large_payload':
        return '{${metadata['payload_type']}: ${metadata['size_mb']}MB}';
      default:
        return metadata.toString();
    }
  }

  Future<void> _initializeClient() async {
    // 1. Create a Dio instance using Dart ACDC Builder
    // This automatically configures:
    // - Token management (if configured)
    // - Logging with custom logger
    // - Error handling
    // - Timeouts
    final dio = await AcdcClientBuilder()
        .withBaseUrl('https://jsonplaceholder.typicode.com')
        .withLogger(_addLog)
        .withLogLevel(LogLevel.info)
        .build();

    if (!mounted) return;

    // 2. Inject Dio into the generated OpenAPI client
    setState(() {
      _client = Openapi(dio: dio);
    });

    _addLog('ACDC Client initialized', LogLevel.info, {
      'base_url': 'https://jsonplaceholder.typicode.com',
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 3. Use the generated API
      final response = await _client.getDefaultApi().getPosts();
      setState(() {
        _posts = response.data?.toList() ?? [];
      });
    } on AcdcException catch (e) {
      // Dart ACDC wraps errors in AcdcException
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

  Future<void> _triggerError() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try to fetch a non-existent post to trigger 404
      await _client.getDefaultApi().getPostById(id: 999999);
    } catch (e) {
      // The error interceptor in AcdcClient should catch this and we can see it in logs.
      // The exception bubbling up depends on how the generated client handles DioExceptions.
      // Usually it rethrows.
      setState(() {
        if (e is DioException) {
          _error = 'DioError: ${e.message} (Status: ${e.response?.statusCode})';
        } else {
          _error = 'Error: $e';
        }
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchPosts,
                  child: const Text('Fetch Posts'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _triggerError,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                  ),
                  child: const Text('Trigger Error'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _clearLogs,
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ),
          if (_isLoading) const CircularProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          // Log Viewer Section
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Logs (${_logs.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text('No logs yet. Try fetching posts!'),
                          )
                        : ListView.builder(
                            controller: _logScrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  log,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Posts Section
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Posts (${_posts.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _posts.isEmpty
                        ? const Center(child: Text('No posts loaded'))
                        : ListView.builder(
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              final post = _posts[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text('${post.id}'),
                                ),
                                title: Text(post.title ?? ''),
                                subtitle: Text(
                                  post.body ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
