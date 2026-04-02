# Descript.ion Fixer

A utility for managing and merging `descript.ion` files in the style of Total Commander file manager.

## What is descript.ion?

`descript.ion` is a file used by Total Commander and other file managers to store file and folder descriptions/comments. Each line contains a filename followed by its description.

## Features

- **Merge conflicting description files**: Merges `descript.*.ion` files caused by sync conflicts from cloud storage services (OneDrive, Dropbox, Google Drive, etc.)
- **Remove stale entries**: Removes descriptions for files that no longer exist
- **Recursive processing**: Optionally process subdirectories recursively
- **Smart conflict resolution**: When merging, newer files (by modification time) take precedence
- **Hidden file support**: Properly handles hidden `descript.ion` files on Windows
- **Logging**: All operations are logged to a file in the system temp directory

## Installation

### From Release

Download the latest release from the [Releases page](https://github.com/alezhu/descript.ion_fixer/releases):

- `descript.ion_fixer-vX.X.X-windows-x64.zip` - executable in ZIP archive
- `descript.ion_fixer-vX.X.X-installer.exe` - Windows installer (64-bit)

### Build from Source

Requirements:
- Zig 0.15.2 or later

```bash
git clone https://github.com/alezhu/descript.ion_fixer.git
cd descript.ion_fixer
zig build -Doptimize=ReleaseSmall
```

The executable will be created in `zig-out/bin/descript.ion_fixer.exe`.

## Usage

```bash
descript.ion_fixer.exe <folder_path> [--recursive|-r]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<folder_path>` | Path to the directory to process (required) |
| `--recursive`, `-r` | Process subdirectories recursively (optional) |

### Examples

Process a single directory:
```bash
descript.ion_fixer.exe "C:\My Files"
```

Process directory and all subdirectories:
```bash
descript.ion_fixer.exe "C:\My Files" --recursive
```

Short form:
```bash
descript.ion_fixer.exe "C:\My Files" -r
```

## How It Works

1. **Scan directory**: The tool scans the specified directory and collects:
   - All existing files
   - All `descript.*.ion` files (e.g., `descript.ion`, `descript_backup.ion`)
   - All subdirectories (if recursive mode is enabled)

2. **Load main description**: Loads `descript.ion` and removes entries for files that no longer exist

3. **Merge additional files**: For each `descript.*.ion` file:
   - Reads all key-value pairs
   - Adds new entries to the main `descript.ion`
   - Updates existing entries only if the source file is newer
   - Deletes the processed `descript.*.ion` file

4. **Save result**: Saves the merged `descript.ion` file with the hidden attribute preserved

5. **Process subdirectories**: If `--recursive` is specified, repeats the process for all subdirectories

## File Format

The `descript.ion` file format:
```
filename.txt Description for this file
"file with spaces.txt" Description for file with spaces
another_file.dat
```

- Files without spaces: `filename description`
- Files with spaces: `"filename with spaces" description`
- Empty descriptions are allowed

## Logging

All operations are logged to `%TEMP%\description_fixer.log`. This is useful for:
- Debugging issues
- Reviewing what changes were made
- Audit purposes

## Technical Details

- **Written in**: Zig 0.15.2
- **Platform**: Windows (x64)
- **License**: MIT
