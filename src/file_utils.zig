const std = @import("std");

// Объявление SetFileAttributesW из kernel32
extern "kernel32" fn SetFileAttributesW(lpFileName: [*:0]const u16, dwFileAttributes: u32) callconv(.winapi) u32;

// Преобразование пути в UTF-16
fn pathToUtf16(allocator: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) ![:0]u16 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = try dir.realpath(filename, &buf);
    const wpath = try std.unicode.utf8ToUtf16LeAllocZ(allocator, full_path);
    return wpath;
}

/// Установка атрибута hidden у файла
pub fn setFileHidden(allocator: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8, hidden: bool) !void {
    const wpath = try pathToUtf16(allocator, dir, filename);
    defer allocator.free(wpath);

    const old_attrs = std.os.windows.GetFileAttributesW(wpath.ptr) catch return;

    const new_attrs = if (hidden)
        old_attrs | std.os.windows.FILE_ATTRIBUTE_HIDDEN
    else
        old_attrs & ~@as(u32, std.os.windows.FILE_ATTRIBUTE_HIDDEN);

    if (new_attrs != old_attrs) {
        _ = SetFileAttributesW(wpath.ptr, new_attrs);
    }
}
