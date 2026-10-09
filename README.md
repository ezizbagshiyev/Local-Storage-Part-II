# Fall Festival Roster — Local Storage Lab

**Student:** Eziz Bagshiyev  
**Pathway:** Undergraduate  
**Storage:** SQLite / sqflite

## What is included
- One SQLite table: `_id`, `name`, `age`
- Add, Edit, Delete, Refresh
- Reused Add/Edit form
- Name validation
- Integer age validation: 0–130
- Generated SQLite IDs
- Record count
- Delete confirmation
- Loading/error feedback
- T1–T6 test record template
- Reflection answers ready for actual evidence

The supplied lab requires a small scope: one screen, one table, two fields, a list/count, and one reused Add/Edit form. fileciteturn0file0L81-L85

## Setup
1. Put `lib/main.dart` and `lib/database_helper.dart` into your Flutter project.
2. Merge the dependencies in `pubspec.yaml`; do not create a second `dependencies:` block. fileciteturn0file0L48-L56
3. Run `flutter pub get`.
4. Fully restart after adding the native SQLite packages. fileciteturn0file0L69-L69
5. If the generated `test/widget_test.dart` still tests the default counter app, remove/update that obsolete scaffold test. fileciteturn0file0L102-L102
6. Run the app.

## Required validation
The lab requires a trimmed nonempty name and integer age from 0 through 130. Blank names, decimals, nonnumbers, and out-of-range ages must not write a row. fileciteturn0file0L140-L155

## T1–T6 results

| Test | Action / input | Expected | Observed | Pass/Fail |
|---|---|---|---|---|
| T1 | Refresh with no rows | Count 0; empty state | TODO | TODO |
| T2 | Add River 21 and River 34 | Count 2; distinct IDs A/B | TODO | TODO |
| T3 | Edit B to 99 then Cancel; edit B to 35 and Save | Cancel keeps 34; Save changes only B | TODO | TODO |
| T4 | Stop/force-stop and relaunch without clearing data | Same IDs/names/ages/count | TODO | TODO |
| T5 | Cancel deletion of A, then confirm deletion | Only B remains after Refresh | TODO | TODO |
| T6 | Invalid values, then age 0 and 130 | Invalid rejected; boundaries accepted | TODO | TODO |

The required T1–T6 sequence and observations are defined by the supplied lab. fileciteturn0file0L204-L214

### T6 detailed record
1. Space-only name, age 21 → TODO
2. Maple, `abc` → TODO
3. Maple, `1.5` → TODO
4. Maple, `-1` → TODO
5. Maple, `131` → TODO
6. Acorn, `0` → accepted, ID TODO
7. Oak, `130` → accepted, ID TODO

## Screenshots
Capture:
- `T4_before.png`
- `T4_after.png`
- `T6_invalid.png`

T4 must be a genuine stop/relaunch while keeping the same installation and data. Hot reload/hot restart, uninstalling, and clearing data do not count. fileciteturn0file0L214-L218

## Reflection 1 — Disappearing-data mystery
Before T4, I predicted that River ID A and River ID B would survive the stop/relaunch because the records were written to SQLite instead of only being held in the Dart list. My actual IDs were A=TODO and B=TODO, and the count before restart was TODO. I stopped/relaunched the app using TODO, and `T4_before.png` / `T4_after.png` show TODO.

## Reflection 2 — Two Rivers, one wrong edit
The app uses the integer `_id` as the record identity instead of the name or list position. This matters because both guests are named River. In my test, editing B changed only B from age 34 to 35 while A stayed at 21.

## Reflection 3 — Usability walkthrough
The clearest parts were the Name/Age labels, record count, Edit/Delete buttons, and validation messages. One small improvement I would make is TODO because TODO.

## Analyzer evidence
From the project root, save the final output as:
`evidence/analysis_output.txt`

PowerShell:
`flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt`

The lab requires saving the analyzer output and retaining actual findings. fileciteturn0file0L218-L220

## Important
Do **not** invent IDs, counts, observations, screenshots, or analyzer results. The source specifically requires personally collected evidence and says to record actual failures/results. fileciteturn0file0L224-L240
