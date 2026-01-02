import 'package:test/test.dart';
import 'package:openapi/openapi.dart';


/// tests for DefaultApi
void main() {
  final instance = Openapi().getDefaultApi();

  group(DefaultApi, () {
    // Get a single post
    //
    //Future<Post> getPostById(int id) async
    test('test getPostById', () async {
      // TODO
    });

    // Get all posts
    //
    //Future<BuiltList<Post>> getPosts() async
    test('test getPosts', () async {
      // TODO
    });

  });
}
