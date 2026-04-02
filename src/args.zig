const std = @import("std");
const ILogger = @import("ilogger.zig").ILogger;

// Structure to hold parsed command line arguments
pub const Args = struct {
    folder_path: []const u8,
    recursive: bool,
    _allocator: std.mem.Allocator,

    pub fn deinit(self: *Args) void {
        self._allocator.free(self.folder_path);
    }
};

// Parse command line arguments and return structured result
pub fn parseArgs(allocator: std.mem.Allocator, logger: ILogger) !Args {

    // Parse command line arguments
    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    // Check if we have enough arguments
    if (raw_args.len < 2) {

        logger.info("Usage: descript.ion_fixer.exe <folder_path> [--recursive|-r]\n");
        return error.InvalidArguments;
    }

    var recursive: bool = false;
    var folder_path: ?[]const u8 = null;
    var i: usize = 1;

    // Parse arguments
    while (i < raw_args.len) {
        const arg = raw_args[i];

        if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r")) {
            recursive = true;
            i += 1;
        } else if (folder_path == null) {
            // First non-flag argument is the folder path
            folder_path = try allocator.dupe(u8, arg);
            errdefer allocator.free(folder_path);
            i += 1;
        } else {
            // Too many arguments
            logger.info("Error: Too many arguments provided\n");
            return error.InvalidArguments;
        }
    }

    // Validate that folder path was provided
    if (folder_path == null) {
        logger.info("Error: Folder path is required\n");
        return error.InvalidArguments;
    }

    return Args{
        .folder_path = folder_path.?,
        .recursive = recursive,
        ._allocator = allocator,
    };
}
