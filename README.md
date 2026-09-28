# FileTidy

A local Windows utility for cleaning up folders, bulk-renaming files, and locating exact duplicates.

## Start it

Double-click **Start FileTidy.bat**. It uses Windows PowerShell already included with Windows, so there is nothing to install.

Each tool has a **Choose folder...** button. Use it to select any accessible folder or drive on your PC; it is not limited to Downloads.

## What it does

- **Downloads Cleaner** sorts the files at the top level of your chosen folder into Images, Documents, Installers, Audio, Video, Archives, or Other. Optionally, older files go to `Archive`.
- **Bulk Renamer** previews every new name before changing anything. It only renames files directly inside the folder selected.
- **Duplicate Finder** scans the selected folder and its subfolders, checking file contents with MD5 hashes. The first copy in each match group is marked **KEEP**; select only **DUPLICATE** rows to move them to Recycle Bin.

Always look at the preview before confirming a move or rename.
