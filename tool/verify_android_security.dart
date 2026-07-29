import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (!arguments.contains('--merged-manifest-stdin')) {
    stderr.writeln('Pipe the effective manifest with --merged-manifest-stdin.');
    exitCode = 64;
    return;
  }

  final mergedManifest = await stdin.transform(systemEncoding.decoder).join();
  _require(
    mergedManifest.contains('package="tr.indirimgo.app"'),
    'The effective package must be tr.indirimgo.app.',
  );
  _require(
    mergedManifest.contains('android.permission.INTERNET'),
    'The effective manifest must include Internet permission.',
  );
  _require(
    mergedManifest.contains('android:allowBackup="false"'),
    'Application backup must be disabled.',
  );
  _require(
    mergedManifest.contains('android:usesCleartextTraffic="false"'),
    'Global cleartext traffic must remain disabled.',
  );
  _require(
    mergedManifest.contains('android:networkSecurityConfig='),
    'The effective manifest must reference a network security policy.',
  );

  final permissions = RegExp(
    r'<uses-permission[^>]*android:name="([^"]+)"',
  ).allMatches(mergedManifest).map((match) => match.group(1)!).toSet();
  // AndroidX/AGP injects this app-scoped signature permission for
  // non-exported dynamic receivers; it is not a dangerous capability grant.
  final unexpected = permissions.difference(const {
    'android.permission.INTERNET',
    'tr.indirimgo.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
  });
  _require(
    unexpected.isEmpty,
    'The effective manifest includes unnecessary permission(s): '
    '${(unexpected.toList()..sort()).join(', ')}.',
  );

  final debugPolicy = File(
    'android/app/src/debug/res/xml/network_security_config.xml',
  ).readAsStringSync();
  _require(
    debugPolicy.contains('<base-config cleartextTrafficPermitted="false" />'),
    'Debug cleartext must be denied by default.',
  );
  final cleartextDomains = RegExp(
    r'<domain includeSubdomains="false">([^<]+)</domain>',
  ).allMatches(debugPolicy).map((match) => match.group(1)).toSet();
  _require(
    cleartextDomains.length == 3 &&
        cleartextDomains.containsAll(const {
          '10.0.2.2',
          '127.0.0.1',
          'localhost',
        }),
    'Debug cleartext exceptions must contain only approved local hosts.',
  );
  _require(
    RegExp('cleartextTrafficPermitted="true"').allMatches(debugPolicy).length ==
        1,
    'Debug must contain exactly one explicit cleartext allow rule.',
  );

  stdout.writeln('Android security policy verified.');
}

void _require(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
