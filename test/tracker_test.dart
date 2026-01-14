import 'package:html/parser.dart' as html_parser;
import 'package:flutter_test/flutter_test.dart';

// MOCK DATA: A tiny snippet of the HTML structure from your paste
const mockHtml = r'''
<!DOCTYPE html>
<html>
<body>
<div id="sheets-viewport">
    <div id="34972268">
        <div class="grid-container">
            <table class="waffle">
                <tbody>
                    <!-- Row 1: Header -->
                    <tr style="height: 58px"><td dir="ltr">Era</td><td dir="ltr">Name</td><td dir="ltr">Notes</td><td dir="ltr">Track Length</td><td>...</td><td>...</td><td>Available Length</td><td>Quality</td><td>Link(s)</td></tr>

                    <!-- Row 2: Info Row (Skip) -->
                    <tr style="height: 104px"><td dir="ltr">1 OG File(s)</td><td>...</td></tr>

                    <!-- Row 3: Actual Track 1 -->
                    <tr style="height: 20px">
                        <td dir="ltr">Before The College Dropout</td>
                        <td dir="ltr">10 in a Benz</td>
                        <td dir="ltr">Track 10 from Go Getters...</td>
                        <td dir="ltr">4:14</td>
                        <td dir="ltr"></td>
                        <td dir="ltr"></td>
                        <td dir="ltr">Full</td>
                        <td dir="ltr">High Quality</td>
                        <td dir="ltr"><a href="https://soundcloud.com/glc">https://soundcloud.com/glc</a></td>
                    </tr>

                    <!-- Row 4: Actual Track 2 (Pillowcase) -->
                    <tr style="height: 20px">
                        <td dir="ltr">Before The College Dropout</td>
                        <td dir="ltr">187th</td>
                        <td dir="ltr">Song recorded in 1996...</td>
                        <td dir="ltr">2:56</td>
                        <td dir="ltr"></td>
                        <td dir="ltr">Apr 22, 2009</td>
                        <td dir="ltr">Full</td>
                        <td dir="ltr">Low Quality</td>
                        <td dir="ltr"><a href="https://pillows.su/f/58876d9f36b768640439466088764e87">https://pillows.su/f/58876d9f36b768640439466088764e87</a></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</div>
</body>
</html>
''';

void main() {
  test('Parses Tracks from HTML Table', () {
    final document = html_parser.parse(mockHtml);

    // 1. Find the table body
    final rows = document.querySelectorAll('table.waffle tbody tr');

    List<Map<String, String>> tracks = [];

    for (var row in rows) {
      final cells = row.children;

      // Basic validation: A valid track row usually has around 9 columns in this sheet
      if (cells.length < 8) continue;

      // Extract text from specific columns
      // Col 0: Era, Col 1: Name, Col 6: Status, Col 8: Link
      String era = cells[0].text.trim();
      String name = cells[1].text.trim();
      String status = cells[6].text.trim(); // "Available Length" column

      // Link extraction logic (sometimes it's text, sometimes an <a> tag)
      var linkElement = cells.length > 8 ? cells[8].querySelector('a') : null;
      String link = linkElement?.attributes['href'] ?? (cells.length > 8 ? cells[8].text.trim() : "");

      // Skip Headers or Metadata rows
      if (era == "Era" || era.contains("OG File")) continue;
      if (name.isEmpty) continue;

      tracks.add({
        "name": name,
        "era": era,
        "status": status,
        "link": link,
      });
    }

    // ASSERTIONS
    expect(tracks.length, 2);

    expect(tracks[0]['name'], '10 in a Benz');
    expect(tracks[0]['status'], 'Full');

    expect(tracks[1]['name'], '187th');
    expect(tracks[1]['link'], 'https://pillows.su/f/58876d9f36b768640439466088764e87');

    print("✅ Test Passed! Parsed ${tracks.length} tracks.");
    for(var t in tracks) {
      print("   - ${t['name']} (${t['link']})");
    }
  });
}