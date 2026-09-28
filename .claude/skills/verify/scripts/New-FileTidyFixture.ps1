<#
.SYNOPSIS
  Creates a disposable folder of sample files for exercising FileTidy by hand.

.DESCRIPTION
  Builds a fresh folder (default: a timestamped folder under $env:TEMP) whose
  contents reach every branch of the three FileTidy tools:

    Downloads Cleaner  - at least one file per category, a file with no
                         extension (Other), two files older than 30 days for
                         the Archive option, and an existing Images\photo.jpg
                         so the top-level photo.jpg has to be renamed on the
                         way in (exercises Get-UniquePath).
    Bulk Renamer       - names with spaces, brackets and a non-ASCII letter,
                         plus "a b.txt" / "a-b.txt" so "Replace spaces with
                         dashes" produces a duplicate name and must be refused.
    Duplicate Finder   - exact copies in different subfolders (one twin at the
                         top level), two files with equal size but different
                         content, and two zero-byte files.

  Nothing outside the new folder is touched. Delete it afterwards with:
    Remove-Item -LiteralPath <path> -Recurse -Force

.PARAMETER Path
  Folder to create. Must not exist yet.

.OUTPUTS
  System.String. The full path of the fixture folder.

.EXAMPLE
  $f = & .\.claude\skills\verify\scripts\New-FileTidyFixture.ps1
  # paste $f into the folder box of each FileTidy tab
#>
[CmdletBinding()]
param(
    [string]$Path = (Join-Path $env:TEMP ('FileTidy-fixture-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $Path) { throw "Refusing to reuse an existing folder: $Path" }
$root = (New-Item -ItemType Directory -Path $Path).FullName

function Add-Fixture {
    param([string]$Relative, [string]$Content, [int]$AgeDays = 0)
    $full = Join-Path $root $Relative
    $dir  = Split-Path -LiteralPath $full -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($full, $Content)   # exact bytes, so duplicate pairs really are identical
    if ($AgeDays -gt 0) { (Get-Item -LiteralPath $full).LastWriteTime = (Get-Date).AddDays(-$AgeDays) }
}

$eAcute      = [string][char]0xE9              # e with acute accent, independent of this file's encoding
$sameBytes   = ('duplicate payload ' * 256)
$reportBytes = 'quarterly report, identical in two places'

# --- Downloads Cleaner: one file per category plus edge cases (all top level) ---
Add-Fixture 'photo.jpg'                      'jpeg one'
Add-Fixture 'Screenshot 2026-01-01.png'      'png with spaces in the name'
Add-Fixture 'diagram.svg'                    '<svg/>'
Add-Fixture 'report.pdf'                     $reportBytes
Add-Fixture 'notes.txt'                      'plain notes'
Add-Fixture 'data.csv'                       'a,b,c'
Add-Fixture "R${eAcute}sum${eAcute}.docx"    'non-ascii file name'
Add-Fixture 'setup.exe'                      'not really an installer'
Add-Fixture 'song.mp3'                       'not really audio'
Add-Fixture 'clip.mp4'                       'not really video'
Add-Fixture 'bundle.zip'                     'not really an archive'
Add-Fixture 'README'                         'no extension, goes to Other'
Add-Fixture 'weird[1].txt'                   'brackets are wildcard characters for -Path'
Add-Fixture 'a b.txt'                        'renaming spaces to dashes collides with a-b.txt'
Add-Fixture 'a-b.txt'                        'already dashed'
Add-Fixture 'old-invoice.pdf'                'sixty days old'            -AgeDays 60
Add-Fixture 'old-photo.jpg'                  'four hundred days old'     -AgeDays 400
Add-Fixture 'Images\photo.jpg'               'jpeg zero, already filed'  # forces top-level photo.jpg -> Images\photo (1).jpg

# --- Duplicate Finder: nested duplicates and near misses ---
Add-Fixture 'dupes\one\same.bin'             $sameBytes
Add-Fixture 'dupes\two\same-copy.bin'        $sameBytes
Add-Fixture 'dupes\two\report (copy).pdf'    $reportBytes                # twin of the top-level report.pdf
Add-Fixture 'dupes\size-match-a.bin'         ('A' * 64)                  # same size as -b, different bytes
Add-Fixture 'dupes\size-match-b.bin'         ('B' * 64)
Add-Fixture 'dupes\empty1.txt'               ''
Add-Fixture 'dupes\empty2.txt'               ''

Get-ChildItem -LiteralPath $root -Recurse -File |
    Sort-Object FullName |
    Select-Object @{ n = 'File'; e = { $_.FullName.Substring($root.Length + 1) } }, Length, LastWriteTime |
    Format-Table -AutoSize | Out-Host

Write-Host "Fixture created: $root"
Write-Host 'Expected: Downloads Cleaner previews 17 top-level files (2 of them to Archive when the option is on);'
Write-Host '          Duplicate Finder reports 3 groups (same.bin pair, report.pdf pair, empty pair), 3 removable copies.'
$root
