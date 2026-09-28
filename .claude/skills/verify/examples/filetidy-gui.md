# Verifying a FileTidy (WinForms GUI) change

The handle is the running window. The evidence is what the preview grid
shows, what the disk looks like afterwards, and screenshots. Windows only.

## Pattern

1. Console A: create a fixture, keep its path in `$f`.
2. Console B: launch FileTidy. It blocks that console until the window closes.
3. Drive the tab the diff touches: paste `$f`, set the options, **Preview**,
   read the grid, **Apply**, answer the confirmation.
4. Console A: inspect the disk (and the Recycle Bin for the duplicate finder),
   take a screenshot.
5. Repeat for the next flow; delete the fixture at the end.

## Snippets (Console A)

```powershell
# 1. fixture
$f = & .\.claude\skills\verify\scripts\New-FileTidyFixture.ps1
Get-ChildItem -LiteralPath $f -Recurse -File |
  Select-Object @{n='Path';e={$_.FullName.Substring($f.Length+1)}}, Length, LastWriteTime

# 4a. screenshot of the primary screen -> %TEMP%\filetidy-step1.png
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b   = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$bmp.Save("$env:TEMP\filetidy-step1.png"); $g.Dispose(); $bmp.Dispose()

# 4b. what is in the Recycle Bin right now (original names)
(New-Object -ComObject Shell.Application).NameSpace(0xA).Items() | ForEach-Object Name

# 5. cleanup
Remove-Item -LiteralPath $f -Recurse -Force
```

```powershell
# Console B
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\FileTidy.ps1
```

Anything printed in red in Console B while you click is an exception that
escaped a handler. Copy it into Findings verbatim.

## Worked example

**Diff:** the Downloads Cleaner preview now tracks destinations it has
already handed out, so two files that would resolve to the same free name
get different ones.

**Claim (commit msg):** "cleaner no longer aborts when two files map to the
same destination".

**Inference:** with `Images\photo.jpg` already present and both `photo.jpg`
and `photo (1).jpg` at the top level, the preview should show two
*different* destinations and Apply should move both without an error.

**Plan:**
1. Fixture, then add the collision case:
   `Copy-Item -LiteralPath "$f\photo.jpg" -Destination "$f\photo (1).jpg"`
2. Launch, Downloads Cleaner tab, paste `$f`, Preview.
3. Read the Destination column for the two `photo*` rows.
4. Apply, Yes, then list `Images\` on disk.

**Execute / observe:**

```
Preview grid (photo rows):
  photo (1).jpg     Images\photo (1).jpg
  photo.jpg         Images\photo (2).jpg

Apply -> "Organized 18 file(s)."

PS> Get-ChildItem -LiteralPath "$f\Images" -Filter 'photo*' | ForEach-Object Name
photo (1).jpg
photo (2).jpg
photo.jpg
PS> Get-ChildItem -LiteralPath $f -File | Measure-Object | ForEach-Object Count
0
```

**Verdict:** PASS. Distinct targets in the preview, both files moved, the
pre-existing `Images\photo.jpg` untouched, top level empty.

## What FAIL looks like

- The preview shows the same destination twice: the fix is not on the path
  the preview takes.
- Apply reports fewer files than the preview, or an error dialog says a
  destination already exists: the collision still happens at move time.
- A file is missing afterwards, or a pre-existing file changed size or time:
  something overwrote. FAIL regardless of what the dialog said.
- Red text in Console B during the flow.

## Probes worth a line each

- Folder box: a nonexistent path, a file instead of a folder, a trailing
  backslash, a path containing `[` `]`, an empty box. Expect the error
  dialog, no crash, and no change on disk.
- Cleaner: Preview twice (the plan must not double); Apply then Preview
  again (the grid should be empty because everything moved); tick the age
  option with N = 1.
- Renamer: Find text with an empty Replace (deletes the text); "Replace
  spaces" and numbering together; a mix that yields two identical names
  (`a b.txt` and `a-b.txt` are in the fixture for this) should produce the
  "duplicate names" dialog and *no* rename; a case-only change
  (`notes` -> `Notes`): note what happens.
- Duplicate finder: select a KEEP row and press the Recycle Bin button (it
  must refuse or skip it); scan again right after deleting (groups should
  shrink); keep a file locked from Console A while scanning:
  `$fs = [IO.File]::Open("$f\dupes\one\same.bin", 'Open', 'Read', 'None')`
  ... `$fs.Close()`, and note whether the locked file silently vanishes
  from the results.
- Resize the window to its minimum and back. Click "Choose folder..." on
  every tab and confirm a dialog actually opens.
