// Интерфейс для логгера
pub const ILogger = struct {
    _ctx: *anyopaque,
    _info_fn: *const fn (ctx: *anyopaque,message: []const u8) void,

    pub fn info(self: ILogger, message: []const u8) void {
        self._info_fn(self._ctx,message);
    }
};
