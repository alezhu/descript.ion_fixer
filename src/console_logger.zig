const std = @import("std");
const ILogger = @import("ilogger.zig").ILogger;

// Реализация логгера, который просто выводит в консоль
pub const ConsoleLogger = struct {
    _buffer: [4096]u8,
    _log_file: std.fs.File,
    _writers: [2]std.fs.File.Writer,

    fn _infoFn(ctx: *anyopaque, message: []const u8) void {
        const self: *ConsoleLogger = @ptrCast(@alignCast(ctx));

        for (&self._writers) |*writer| {
            writer.interface.writeAll(message) catch |err| {
                std.debug.print("Write error: {s}\n", .{@errorName(err)});
            };
            writer.interface.flush() catch |err| {
                std.debug.print("Flush error: {s}\n", .{@errorName(err)});
            };
        }
    }

    pub fn getLogger(self: *const ConsoleLogger) ILogger {
        return ILogger{
            ._ctx = @constCast(self),
            ._info_fn = _infoFn,
        };
    }

    pub fn deinit(self: * ConsoleLogger) void {
        self._log_file.close();
    }
};

pub fn init(allocator: std.mem.Allocator) !ConsoleLogger {
    // Получаем временную директорию
    const temp_dir_path = std.process.getEnvVarOwned(allocator, "TEMP") catch
        std.process.getEnvVarOwned(allocator, "TMP") catch
        std.process.getEnvVarOwned(allocator, "TMPDIR") catch "/tmp";
    defer allocator.free(temp_dir_path);

    var temp_dir = try std.fs.cwd().openDir(temp_dir_path, .{});
    defer temp_dir.close();

    const log_file_name = "description_fixer.log";
    const log_file = try temp_dir.createFile(log_file_name, .{});

    var self = ConsoleLogger{
        ._buffer = undefined,
        ._log_file = log_file,
        ._writers = undefined,
    };
    self._writers[0] = std.fs.File.stdout().writer(&self._buffer);
    self._writers[1] = self._log_file.writer(&self._buffer);

    return self;
}
