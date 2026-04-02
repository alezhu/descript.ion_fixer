const std = @import("std");
const windows = std.os.windows;
const build_options = @import("build_options");

const args = @import("args.zig");
const Handler = @import("handler.zig");
const ConsoleLogger = @import("console_logger.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Set UTF-8 for console
    _ = windows.kernel32.SetConsoleOutputCP(65001);

    var console = try ConsoleLogger.init(allocator);
    defer console.deinit();
    const logger = console.getLogger();
    const msg = try std.fmt.allocPrint(allocator, "descript.ion fixer {s}\n",.{build_options.version});
    defer allocator.free(msg);

    logger.info(msg);

    // Parse command line arguments
    var parsed_args = args.parseArgs(allocator, logger) catch {
        return;
    };
    defer parsed_args.deinit();

    // Open specified directory
    const cwd = std.fs.cwd();
    var dir = try cwd.openDir(parsed_args.folder_path, .{ .iterate = true });
    defer dir.close();

    var handler = try Handler.init(allocator, parsed_args.recursive, logger);
    defer handler.deinit();

    try handler.handlePath(&dir);
}
