import 'dart:io';

void main() async {
  final rootDir = Directory('lib');
  final outputFile = File('PROJECT_TREE.md');
  final buffer = StringBuffer();

  buffer.writeln('# Project Structure & Classes');
  buffer.writeln('Generated: ${DateTime.now()}\n');

  if (!await rootDir.exists()) {
    print('lib directory not found');
    return;
  }

  await for (final entity in rootDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final relativePath = entity.path;
      final content = await entity.readAsString();
      
      final classMatches = RegExp(r'^(?:abstract\s+)?(class|enum|mixin|extension)\s+(\w+)', multiLine: true).allMatches(content);
      
      if (classMatches.isNotEmpty) {
        buffer.writeln('## $relativePath');
        for (final match in classMatches) {
          final type = match.group(1);
          final name = match.group(2);
          buffer.writeln('- [$type] $name');
        }
        buffer.writeln('');
      } else {
        // Uncomment to list files without classes too
        // buffer.writeln('## $relativePath'); 
        // buffer.writeln('(No classes defined)\n');
      }
    }
  }

  await outputFile.writeAsString(buffer.toString());
  print('Documentation generated at: ${outputFile.absolute.path}');
}
