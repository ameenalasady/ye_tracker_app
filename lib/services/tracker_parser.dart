import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/sheet_tab.dart';
import '../models/track.dart';

class TrackerParser {
  final String sourceUrl;
  TrackerParser(this.sourceUrl);

  String get _baseUrl {
    var url = sourceUrl;
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<List<SheetTab>> fetchTabs() async {
    final response = await http.get(Uri.parse(_baseUrl)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception("Failed to load source: ${response.statusCode}");

    final tabList = <SheetTab>[];
    // Regex is faster than parsing full HTML for just these strings
    final tabReg = RegExp(r'name: "(.*?)",.*?gid: "(\d+)"');
    final matches = tabReg.allMatches(response.body);

    for (final m in matches) {
      final name = m.group(1)!;
      final gid = m.group(2)!;
      // Filter out utility tabs
      if (!const ['Key', 'Template', 'Fakes', 'Stats', 'Updates', 'Links'].contains(name)) {
        if (!tabList.any((t) => t.gid == gid)) {
          tabList.add(SheetTab(name: name, gid: gid));
        }
      }
    }
    if (tabList.isEmpty) { throw Exception("No tabs found. Check URL."); }
    return tabList;
  }

  Future<List<Track>> fetchTracksForTab(String gid) async {
    final url = '$_baseUrl/htmlview/sheet?headers=true&gid=$gid';
    debugPrint("Fetching: $url");

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception("Failed to load Tab HTML");

    // Dart 2.19/3.0+: Isolate.run is lighter and cleaner than compute
    return await Isolate.run(() => _parseHtml(response.body));
  }
}

List<Track> _parseHtml(String htmlBody) {
  final document = html_parser.parse(htmlBody);
  // Fail fast if table missing
  final table = document.querySelector('table.waffle');
  if (table == null) return [];

  final rows = table.querySelectorAll('tbody tr');
  if (rows.isEmpty) return [];

  // --- 1. Header Detection ---
  Map<String, int> colMap = {};
  int startRowIndex = 0;

  // Scan first 20 rows to find headers
  for (int i = 0; i < rows.length && i < 20; i++) {
    final cells = rows[i].children;
    if (cells.isEmpty) continue;

    // Convert only once
    final texts = cells.map((e) => e.text.trim().toLowerCase()).toList();

    bool hasName = texts.contains('name');
    bool hasLength = texts.any((t) => t.contains('length') || t.contains('duration'));

    if (hasName && hasLength) {
      startRowIndex = i + 1;
      for (int c = 0; c < texts.length; c++) {
        final h = texts[c];
        if (h.contains('era')) {
          colMap['era'] = c;
        } else if (h == 'name') { colMap['name'] = c; }
        else if (h.contains('notes')) { colMap['notes'] = c; }
        else if ((h.contains('length') || h.contains('time')) && !h.contains('available')) { colMap['length'] = c; }
        else if (h == 'length') { colMap['length'] = c; }
        else if (h.contains('release') || h.contains('date')) { colMap['date'] = c; }
        else if (h.contains('type')) { colMap['type'] = c; }
        else if (h.contains('streaming')) { colMap['streaming'] = c; }
        else if (h.contains('link')) { colMap['link'] = c; }
      }
      break;
    }
  }

  if (!colMap.containsKey('name')) { return []; }

  final List<Track> tracks = [];
  String lastEra = "";
  final regExpGoogle = RegExp(r'[?&]q=([^&]+)');

  // Pre-fetch column indices for speed inside loop
  final idxName = colMap['name']!;
  final idxLength = colMap['length'] ?? -1;
  final idxLink = colMap['link'] ?? -1;
  final idxEra = colMap['era'] ?? -1;
  final idxNotes = colMap['notes'] ?? -1;
  final idxDate = colMap['date'] ?? -1;
  final idxType = colMap['type'] ?? -1;
  final idxStreaming = colMap['streaming'] ?? -1;

  // --- 3. Parsing Rows ---
  for (int i = startRowIndex; i < rows.length; i++) {
    final cells = rows[i].children;
    if (cells.length <= idxName) { continue; }

    String rawName = cells[idxName].text.trim();
    if (rawName.isEmpty || rawName == "Name") { continue; }

    String len = (idxLength > -1 && idxLength < cells.length) ? cells[idxLength].text.trim() : "";
    String lnk = "";

    if (idxLink > -1 && idxLink < cells.length) {
      final cell = cells[idxLink];
      // Check anchor tag first (faster than text search)
      final anchor = cell.querySelector('a');
      if (anchor != null) {
        lnk = anchor.attributes['href'] ?? "";
      } else if (cell.text.contains("http")) {
        lnk = cell.text.trim();
      }
    }

    if (len.isEmpty && (lnk.isEmpty || !lnk.contains('http'))) continue;

    String era = "";
    if (idxEra > -1 && idxEra < cells.length) {
      era = cells[idxEra].text.trim();
    }

    if (era.isNotEmpty) {
      lastEra = era;
    } else {
      era = lastEra;
    }

    String artist = "Kanye West"; // Default
    String title = rawName;

    if (rawName.contains(" - ")) {
      final parts = rawName.split(" - ");
      if (parts[0].length < 60) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(" - ").trim();
      }
    } else {
      String type = (idxType > -1 && idxType < cells.length) ? cells[idxType].text.trim().toLowerCase() : "";
      if (type == 'production') { artist = ""; }
    }

    // Clean Google Redirection Links
    if (lnk.isNotEmpty && lnk.contains('google.com/url')) {
      final match = regExpGoogle.firstMatch(lnk);
      if (match != null) {
        try { lnk = Uri.decodeComponent(match.group(1)!); } catch (_) {}
      }
    }

    bool streaming = false;
    if (idxStreaming > -1 && idxStreaming < cells.length) {
       streaming = cells[idxStreaming].text.trim().toLowerCase() == 'yes';
    }

    tracks.add(
      Track(
        era: era,
        artist: artist,
        title: title,
        notes: (idxNotes > -1 && idxNotes < cells.length) ? cells[idxNotes].text.trim() : "",
        length: len,
        releaseDate: (idxDate > -1 && idxDate < cells.length) ? cells[idxDate].text.trim() : "",
        type: (idxType > -1 && idxType < cells.length) ? cells[idxType].text.trim() : "",
        isStreaming: streaming,
        link: lnk,
      ),
    );
  }

  return tracks;
}