import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/sheet_tab.dart';
import '../models/track.dart';

class TrackerParser {
  TrackerParser(this.sourceUrl);
  final String sourceUrl;

  String get _baseUrl {
    var url = sourceUrl;
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<List<SheetTab>> fetchTabs() async {
    final response = await http
        .get(Uri.parse(_baseUrl), headers: Track.imageHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load source: ${response.statusCode}');
    }

    final tabList = <SheetTab>[];
    final tabReg = RegExp(r'name: "(.*?)",.*?gid: "(\d+)"');
    final matches = tabReg.allMatches(response.body);

    for (final m in matches) {
      final name = m.group(1)!;
      final gid = m.group(2)!;
      if (!const [
        'Key',
        'Template',
        'Fakes',
        'Stats',
        'Updates',
        'Links',
      ].contains(name)) {
        if (!tabList.any((t) => t.gid == gid)) {
          tabList.add(SheetTab(name: name, gid: gid));
        }
      }
    }
    if (tabList.isEmpty) {
      throw Exception('No tabs found. Check URL.');
    }
    return tabList;
  }

  Future<List<Track>> fetchTracksForTab(String gid) async {
    final url = '$_baseUrl/htmlview/sheet?headers=true&gid=$gid';
    debugPrint('Fetching: $url');

    final response = await http
        .get(Uri.parse(url), headers: Track.imageHeaders)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) throw Exception('Failed to load Tab HTML');

    return Isolate.run(() => _parseHtml(response.body));
  }
}

List<Track> _parseHtml(String htmlBody) {
  final document = html_parser.parse(htmlBody);
  final table = document.querySelector('table.waffle');
  if (table == null) return [];

  final rows = table.querySelectorAll('tbody tr');
  if (rows.isEmpty) return [];

  // --- 1. Header Detection ---
  final colMap = <String, int>{};
  var startRowIndex = 0;

  for (var i = 0; i < rows.length && i < 20; i++) {
    final cells = rows[i].children;
    if (cells.isEmpty) continue;

    final texts = cells.map((e) => e.text.trim().toLowerCase()).toList();

    final hasName = texts.contains('name');
    final hasLength = texts.any(
      (t) => t.contains('length') || t.contains('duration'),
    );

    if (hasName && hasLength) {
      startRowIndex = i + 1;
      for (var c = 0; c < texts.length; c++) {
        final h = texts[c];
        if (h.contains('era')) {
          colMap['era'] = c;
        } else if (h == 'name') {
          colMap['name'] = c;
        } else if (h.contains('notes')) {
          colMap['notes'] = c;
        } else if ((h.contains('length') || h.contains('time')) &&
            !h.contains('available')) {
          colMap['length'] = c;
        } else if (h == 'length') {
          colMap['length'] = c;
        } else if (h.contains('release') || h.contains('date')) {
          colMap['date'] = c;
        } else if (h.contains('type')) {
          colMap['type'] = c;
        } else if (h.contains('streaming')) {
          colMap['streaming'] = c;
        } else if (h.contains('link')) {
          colMap['link'] = c;
        }
      }
      break;
    }
  }

  if (!colMap.containsKey('name')) return [];

  final tracks = <Track>[];
  var lastEra = '';
  var lastEraImage = '';
  final regExpGoogle = RegExp(r'[?&]q=([^&]+)');

  final idxName = colMap['name']!;
  final idxLength = colMap['length'] ?? -1;
  final idxLink = colMap['link'] ?? -1;
  final idxEra = colMap['era'] ?? -1;
  final idxNotes = colMap['notes'] ?? -1;
  final idxDate = colMap['date'] ?? -1;
  final idxType = colMap['type'] ?? -1;
  final idxStreaming = colMap['streaming'] ?? -1;

  // --- 3. Parsing Rows ---
  for (var i = startRowIndex; i < rows.length; i++) {
    final cells = rows[i].children;

    // --- Image Detection ---
    // More robust check: look for any img tag within the row
    final imgs = rows[i].querySelectorAll('img');
    if (imgs.isNotEmpty) {
      for (final img in imgs) {
        final src = img.attributes['src'];
        if (src != null && src.startsWith('http')) {
          lastEraImage = src;
          // Break on first valid image to avoid grabbling small icons if any
          break;
        }
      }
    }

    if (cells.length <= idxName) continue;

    final rawName = cells[idxName].text.trim();
    if (rawName.isEmpty || rawName == 'Name') continue;

    final len = (idxLength > -1 && idxLength < cells.length)
        ? cells[idxLength].text.trim()
        : '';
    if (len.isEmpty) continue;

    var lnk = '';
    if (idxLink > -1 && idxLink < cells.length) {
      final cell = cells[idxLink];
      final anchor = cell.querySelector('a');
      if (anchor != null) {
        lnk = anchor.attributes['href'] ?? '';
      } else if (cell.text.contains('http')) {
        lnk = cell.text.trim();
      }
    }

    var era = '';
    if (idxEra > -1 && idxEra < cells.length) {
      era = cells[idxEra].text.trim();
    }

    // Logic: If Era cell is empty, it belongs to the previous Era (merged cells logic)
    if (era.isNotEmpty) {
      lastEra = era;
    } else {
      era = lastEra;
    }

    var artist = 'Kanye West';
    var title = rawName;

    if (rawName.contains(' - ')) {
      final parts = rawName.split(' - ');
      if (parts[0].length < 60) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else {
      final type = (idxType > -1 && idxType < cells.length)
          ? cells[idxType].text.trim().toLowerCase()
          : '';
      if (type == 'production') {
        artist = '';
      }
    }

    if (lnk.isNotEmpty && lnk.contains('google.com/url')) {
      final match = regExpGoogle.firstMatch(lnk);
      if (match != null) {
        try {
          lnk = Uri.decodeComponent(match.group(1)!);
        } catch (_) {}
      }
    }

    var streaming = false;
    if (idxStreaming > -1 && idxStreaming < cells.length) {
      streaming = cells[idxStreaming].text.trim().toLowerCase() == 'yes';
    }

    tracks.add(
      Track(
        era: era,
        artist: artist,
        title: title,
        notes: (idxNotes > -1 && idxNotes < cells.length)
            ? cells[idxNotes].text.trim()
            : '',
        length: len,
        releaseDate: (idxDate > -1 && idxDate < cells.length)
            ? cells[idxDate].text.trim()
            : '',
        type: (idxType > -1 && idxType < cells.length)
            ? cells[idxType].text.trim()
            : '',
        isStreaming: streaming,
        link: lnk,
        // We assign what we found so far.
        // The Repository will back-fill gaps using the Era map.
        albumArtUrl: lastEraImage,
      ),
    );
  }

  return tracks;
}
