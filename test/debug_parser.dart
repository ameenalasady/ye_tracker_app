import 'package:html/parser.dart' as html_parser;

// 1. Paste the HTML snippet you provided here
const String mockHtml = r'''
<html>
<body>
<table class="waffle">
<tbody>
  <!-- Simulated Header Row (usually row 1 or 2) -->
  <tr>
    <td>Era</td>
    <td>Name</td>
    <td>Notes</td>
    <td>Length</td>
    <td>Release Date</td>
    <td>Type</td>
    <td>Streaming</td>
    <td>Link</td>
  </tr>

  <!-- Row 126: Previous Track -->
  <tr style="height: 21px">
    <td>Before The College Dropout</td>
    <td>Rhymefest - ???</td>
    <td>Notes...</td>
    <td></td>
    <td></td>
    <td>Snippet</td>
    <td>Recording</td>
    <td>http://link.com</td>
  </tr>

  <!-- Row 127: THE ERA HEADER (Contains the Image) -->
  <tr style="height: 108px">
    <th id="34972268R126" style="height: 108px;" class="row-headers-background"><div class="row-header-wrapper" style="line-height: 108px">127</div></th>
    <td class="s68" dir="ltr">1 OG File(s)<br>47 Full...</td>
    <td class="s69" dir="ltr">The College Dropout<br><span style="font-size:12pt;font-weight:normal;font-style:italic;">(I'm Good)</span></td>
    <td class="s70" dir="ltr" colspan="2">(08/18/2002)...</td>
    <td class="s71" dir="ltr">
        <div style="width:102px;height:108px;">
            <img src="https://lh7-rt.googleusercontent.com/sheetsz/AHOq17HNSqe2bzIDD2Ysf_X682poWmIrXepqgn0Of-O1g-54wWc2q5VhpXAP6MKALZ0uM-CKJypaeQcan4Wrgo6amCkmSaG_v818DJRa8lL-D1EFrnDKwvNu4XQCv739I0-Tk_j89eXmTRhHJcVV=w102-h108?key=tq3WK_aR67PFo452BJBKgg" style="width:inherit;height:inherit;object-fit:scale-down;object-position:center center;pointer-events:none;" loading="lazy">
        </div>
    </td>
    <td class="s72" dir="ltr" colspan="4">Description...</td>
  </tr>

  <!-- Row 128: The Track that should inherit the image -->
  <tr style="height: 21px">
    <td>The College Dropout</td>
    <td>18 Years</td>
    <td>Throwaway...</td>
    <td>Full</td>
    <td>Recording</td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
</tbody>
</table>
</body>
</html>
''';

void main() {
  print("--- STARTING DEBUG ---");

  final document = html_parser.parse(mockHtml);
  final table = document.querySelector('table.waffle');

  if (table == null) {
    print("CRITICAL: Could not find table.waffle");
    return;
  }

  final rows = table.querySelectorAll('tbody tr');
  print("Found ${rows.length} rows.");

  // Simulate Column Mapping (We assume we found them successfully for this test)
  // Based on the mock HTML above:
  // Era=0, Name=1, Notes=2, Length=3, Date=4, Type=5, Streaming=6, Link=7
  // But wait, the Google Sheets HTML structure shifts heavily on merged cells.
  // Let's debug specifically looking for images in ANY row.

  String currentEraImage = "None";

  for (int i = 0; i < rows.length; i++) {
    final row = rows[i];
    print("\n--- Processing Row $i ---");

    // 1. Debug: Print raw text to identify row
    print("Row Text Preview: ${row.text.replaceAll('\n', ' ').substring(0, row.text.length > 50 ? 50 : row.text.length)}...");

    // 2. SEARCH FOR IMAGE
    // We look for 'img' tag anywhere inside this 'tr'
    final imgs = row.querySelectorAll('img');

    if (imgs.isNotEmpty) {
      print("  [IMAGE FOUND!] Count: ${imgs.length}");
      for (var img in imgs) {
        final src = img.attributes['src'];
        print("  -> SRC: $src");
        if (src != null && src.startsWith('http')) {
          currentEraImage = src;
          print("  -> UPDATED GLOBAL ARTWORK TO: $currentEraImage");
        }
      }
    } else {
      print("  [No Image] in this row.");
    }

    // 3. Simulate Track Extraction Logic
    // In the snippet, Row 127 is the header, Row 128 is the track.
    // Row 128 does NOT have an image, so it must inherit `currentEraImage`.

    // Let's pretend we identified this is a track row (Row 2 in our 0-indexed mock list)
    if (row.text.contains("18 Years")) {
      print("  -> TRACK DETECTED: '18 Years'");
      print("  -> ASSIGNING ARTWORK: $currentEraImage");

      if (currentEraImage == "None") {
         print("  !!! FAIL: Track found but artwork was not captured from previous row !!!");
      } else {
         print("  *** SUCCESS: Track has artwork! ***");
      }
    }
  }
}