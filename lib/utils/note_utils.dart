import 'package:intl/intl.dart';

final RegExp urlRegex = RegExp(
  r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
  caseSensitive: false,
);

String? extractFirstUrl(String text) {
  final match = urlRegex.firstMatch(text);
  if (match == null) {
    return null;
  }
  final raw = match.group(0);
  if (raw == null) {
    return null;
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  return 'https://$raw';
}

List<String> extractUrls(String text) {
  final matches = urlRegex.allMatches(text);
  if (matches.isEmpty) {
    return [];
  }
  final urls = <String>[];
  for (final match in matches) {
    final raw = match.group(0);
    if (raw == null) {
      continue;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      urls.add(raw);
    } else {
      urls.add('https://$raw');
    }
  }
  return urls;
}

String formatNoteDate(DateTime dateTime) {
  return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
}
