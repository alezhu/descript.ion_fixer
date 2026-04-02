const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const KeyValueStore = @import("key_value_store.zig").KeyValueStore;
const ILogger = @import("ilogger.zig").ILogger;
const file_utils = @import("file_utils.zig");

// Определим конкретный тип Handler с фиксированным типом логгера
pub const Handler = struct {
    _allocator: Allocator,
    _recursive: bool,
    _logger: ILogger,

    pub fn deinit(self: *Handler) void {
        _ = self;
    }

    pub fn handlePath(self: *const Handler, path: *std.fs.Dir) !void {
        var arena = std.heap.ArenaAllocator.init(self._allocator);
        errdefer arena.deinit();

        var allocator = arena.allocator();

        const logf = self._get_logf(allocator);

        // Get absolute path to directory
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd_path = try path.realpath(".", &cwd_buf);

        try logf.call("Processing directory: {s}\n", .{cwd_path});

        // Collect all files, descript.*.ion files and subdirectories in one pass
        var all = std.StringHashMap(void).init(allocator);
        var descript_files: std.ArrayList([]const u8) = .empty;
        var subdirs: std.ArrayList([]const u8) = .empty;

        {
            var dir_iter = path.iterate();
            while (try dir_iter.next()) |entry| {
                const name = try allocator.dupe(u8, entry.name);
                if (entry.kind == .file) {
                    // Check if matches pattern "descript.+\.ion"
                    if (std.mem.startsWith(u8, name, "descript") and
                        std.mem.endsWith(u8, name, ".ion") and
                        name.len > "descript".len + ".ion".len)
                    {
                        try descript_files.append(allocator, name);
                        continue;
                    }
                } else if (entry.kind == .directory and self._recursive) {
                    const subdir = try self._allocator.dupe(u8, name);
                    try subdirs.append(self._allocator, subdir);
                }
                try all.put(name, {});
            }
        }

        // 1. Load description and remove keys for non-existent files
        var description = try KeyValueStore.load(allocator, path.*, "descript.ion");

        try self._exclude_absent(allocator, &description, &all, description._filename);

        // 2-4. Open each descript*.ion as KeyValueStore and merge into descript.ion
        for (descript_files.items) |name| {
            try logf.call("Processing file: {s}\n", .{name});

            var kv = try KeyValueStore.load(allocator, path.*, name);

            var it = kv._pairs.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                const value = entry.value_ptr.*;

                // Check if file exists in all_files
                if (!all.contains(key)) continue;

                // Check if key already exists in description
                if (description.get(key)) |_| {
                    // Key exists - update only if current KV date is greater
                    if (kv.last_modified_time != null and description.last_modified_time != null) {
                        if (kv.last_modified_time.? > description.last_modified_time.?) {
                            try description.set(key, value);
                            try logf.call("Updating entry in descript.ion: {s}\n", .{key});
                        }
                    }
                } else {
                    // Key doesn't exist - add it
                    try description.set(key, value);
                    try logf.call("Adding entry to descript.ion: {s}\n", .{key});
                }
            }

            try logf.call("Delete file: {s}\n", .{name});
            try file_utils.setFileHidden(allocator, path.*, name, false);
            path.deleteFile(name) catch |err| switch (err) {
                error.FileNotFound => {}, // Файл уже не существует - это нормально
                else => return err,
            };
        }

        // 5. Save final descript.ion
        description.save() catch |err| switch (err) {
            error.AccessDenied => {
                try logf.call("Access denied to descript.ion", .{});
            },
            else => return err,
        };

        arena.deinit();

        // 6. Recursively call handlePath for all subdirectories
        if (self._recursive) {
            for (subdirs.items) |dir_name| {
                var subdir = try path.openDir(dir_name, .{ .iterate = true });
                defer subdir.close();

                try self.handlePath(&subdir);
                self._allocator.free(dir_name);
            }
        }
    }

    fn _exclude_absent(self: *const Handler, allocator: Allocator, store: *KeyValueStore, exists: *const std.StringHashMap(void), storeName: []const u8) !void {
        var it = store._pairs.iterator();
        var keys_to_remove: std.ArrayList([]const u8) = .empty;
        defer keys_to_remove.deinit(allocator);

        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            // Check if exists
            if (!exists.contains(key)) {
                try keys_to_remove.append(allocator, key);
            }
        }

        // Remove marked keys
        for (keys_to_remove.items) |key| {
            const removing_entry_msg = try std.fmt.allocPrint(allocator, "Removing entry from {s}: {s}\n", .{ storeName, key });
            self._logger.info(removing_entry_msg);
            _ = store.remove(key);
        }
    }

    fn _get_logf(self: *const Handler, allocator: Allocator) struct {
        allocator: Allocator,
        logger: ILogger,

        fn call(ctx: @This(), comptime fmt: []const u8, args: anytype) anyerror!void {
            const msg = try std.fmt.allocPrint(ctx.allocator, fmt, args);
            ctx.logger.info(msg);
        }
    } {
        return .{
            .allocator = allocator,
            .logger = self._logger,
        };
    }
};

pub fn init(allocator: Allocator, recursive: bool, logger: ILogger) !Handler {
    return Handler{
        ._allocator = allocator,
        ._recursive = recursive,
        ._logger = logger,
    };
}
