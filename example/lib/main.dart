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

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  void _initializeClient() {
    // 1. Create a Dio instance using Dart ACDC Builder
    // This automatically configures:
    // - Token management (if configured)
    // - Logging
    // - Error handling
    // - Timeouts
    final dio = AcdcClientBuilder()
        .withBaseUrl('https://jsonplaceholder.typicode.com')
        .withLogger((message, level, metadata) {
          debugPrint('[$level] $message ${metadata ?? ''}');
        })
        .withLogLevel(LogLevel.info)
        .build();

    // 2. Inject Dio into the generated OpenAPI client
    _client = Openapi(dio: dio);
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
      body: Center(
        child: Column(
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
            Expanded(
              child: ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${post.id}')),
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
    );
  }
}
