import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Project Structure', () {
    test('Strict Export Policy: Only dart_acdc.dart is public in lib/', () {
      // Get the package root directory (assuming test is run from project root)
      // If run from test/ directory, adjust accordingly.
      // We'll search for 'lib' relative to the current working directory.
      final currentDir = Directory.current;
      final libDir = Directory(path.join(currentDir.path, 'lib'));

      if (!libDir.existsSync()) {
        // Fallback: try to find it relative to the test file if CWD is wrong
        // This is a heuristic; in standard 'dart test', CWD is project root.
        fail('Could not find lib/ directory at ${libDir.path}. '
            'Ensure you are running tests from the package root.');
      }

      final entities = libDir.listSync();

      // Define allowed entities in lib/ root
      final allowedFiles = ['dart_acdc.dart'];
      final allowedDirs = ['src'];

      final unexpectedEntities = <String>[];

      for (final entity in entities) {
        final name = path.basename(entity.path);

        // Ignore hidden files (like .DS_Store)
        if (name.startsWith('.')) continue;

        if (entity is File) {
          if (!allowedFiles.contains(name)) {
            unexpectedEntities.add('File: $name');
          }
        } else if (entity is Directory) {
          if (!allowedDirs.contains(name)) {
            unexpectedEntities.add('Directory: $name');
          }
        } else {
          // Links or other types
          unexpectedEntities.add('Unknown: $name');
        }
      }

      if (unexpectedEntities.isNotEmpty) {
        fail('Strict export policy violation! Found unexpected items in lib/:\n'
            '${unexpectedEntities.map((e) => ' - $e').join('\n')}\n\n'
            'The lib/ directory must ONLY contain:\n'
            ' - ${allowedFiles.join(', ')}\n'
            ' - ${allowedDirs.join(', ')}\n'
            'All other implementation code must be placed inside lib/src/.');
      }
    });
  });
}
