const std = @import("std");
const Allocator = std.mem.Allocator;
const time = std.time;
const file_utils = @import("file_utils.zig");

pub const KeyValueStore = struct {
    _pairs: std.StringHashMap([]const u8),
    _allocator: Allocator,
    _dir: std.fs.Dir,
    _filename: []const u8,
    last_modified_time: ?i128, // Время последнего изменения файла

    pub fn deinit(self: *KeyValueStore) void {
        var it = self._pairs.iterator();
        while (it.next()) |entry| {
            self._allocator.free(entry.key_ptr.*);
            self._allocator.free(entry.value_ptr.*);
        }
        self._pairs.deinit();
    }

    // Загрузка из файла - статический метод
    pub fn load(allocator: Allocator, dir: std.fs.Dir, filename: []const u8) !KeyValueStore {
        var self = KeyValueStore{
            ._pairs = std.StringHashMap([]const u8).init(allocator),
            ._allocator = allocator,
            .last_modified_time = null,
            ._dir = dir,
            ._filename = filename,
        };

        // Проверяем существование файла
        const file = dir.openFile(filename, .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                // Если файл не существует, устанавливаем время модификации на текущее
                self.last_modified_time = time.microTimestamp();
                return self;
            },
            else => return err,
        };

        defer file.close();

        // Получаем информацию о файле, включая время последнего изменения
        const stat = try file.stat();
        self.last_modified_time = stat.mtime;

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            // Пропускаем пустые строки
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            try self.parseAndAddLine(trimmed);
        }

        return self;
    }

    // Внутренний метод для парсинга строки
    fn parseAndAddLine(self: *KeyValueStore, line: []const u8) !void {
        var key: []const u8 = undefined;
        var value: []const u8 = undefined;

        // Проверяем, начинается ли строка с кавычки (означает, что ключ содержит пробелы)
        if (line.len > 0 and line[0] == '"') {
            // Ищем закрывающую кавычку
            var i: usize = 1; // начинаем после открывающей кавычки
            while (i < line.len and line[i] != '"') {
                i += 1;
            }

            if (i >= line.len) {
                // Не найдена закрывающая кавычка
                return error.MissingClosingQuote;
            }

            key = line[1..i];

            // Пропускаем пробелы между ключом и значением
            i += 1; // после закрывающей кавычки
            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) {
                i += 1;
            }

            if (i >= line.len) {
                // Нет значения после ключа
                value = "";
            } else {
                // Остальная часть строки - это значение
                value = line[i..];
            }
        } else {
            // Ключ не содержит пробелов, первое слово до пробела
            var space_idx: ?usize = null;
            var j: usize = 0;
            while (j < line.len) {
                if (line[j] == ' ' or line[j] == '\t') {
                    space_idx = j;
                    break;
                }
                j += 1;
            }

            if (space_idx) |idx| {
                key = line[0..idx];

                // Пропускаем пробелы между ключом и значением
                j = idx;
                while (j < line.len and (line[j] == ' ' or line[j] == '\t')) {
                    j += 1;
                }

                if (j >= line.len) {
                    value = "";
                } else {
                    value = line[j..];
                }
            } else {
                // Только ключ без значения
                key = line;
                value = "";
            }
        }

        // Обновляем или добавляем пару
        _ = try self.set(key, value);
    }

    // Установка значения по ключу (добавляет или обновляет)
    pub fn set(self: *KeyValueStore, key: []const u8, value: []const u8) !void {
        _ = self.remove(key);

        // Дублируем ключ и значение
        const duped_key = try self._allocator.dupe(u8, key);
        const duped_value = try self._allocator.dupe(u8, value);

        try self._pairs.put(duped_key, duped_value);
    }

    // Получение значения по ключу
    pub fn get(self: *KeyValueStore, key: []const u8) ?[]const u8 {
        return self._pairs.get(key);
    }

    // Удаление пары по ключу
    pub fn remove(self: *KeyValueStore, key: []const u8) bool {
        if (self._pairs.fetchRemove(key)) |entry| {
            self._allocator.free(entry.key);
            self._allocator.free(entry.value);
            return true;
        }
        return false;
    }

    // Сохранение в файл
    pub fn save(self: *KeyValueStore) !void {
        // Если записей нет - удаляем файл
        if (self._pairs.count() == 0) {
            self._dir.deleteFile(self._filename) catch |err| switch (err) {
                error.FileNotFound => {}, // Файл уже не существует - это нормально
                else => return err,
            };
            return;
        }

        try file_utils.setFileHidden(self._allocator, self._dir, self._filename, false);

        const file = try self._dir.createFile(self._filename, .{ .truncate = true });
        defer file.close();

        var it = self._pairs.iterator();
        while (it.next()) |entry| {
            var buffer: [1024]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            var writer = fbs.writer();

            // Проверяем, содержит ли ключ пробелы
            if (std.mem.indexOfScalar(u8, entry.key_ptr.*, ' ')) |_| {
                // Ключ содержит пробелы, оборачиваем в кавычки
                try writer.writeAll("\"");
                try writer.writeAll(entry.key_ptr.*);
                try writer.writeAll("\" ");
            } else {
                // Ключ не содержит пробелов
                try writer.writeAll(entry.key_ptr.*);
                try writer.writeAll(" ");
            }

            // Добавляем значение
            try writer.writeAll(entry.value_ptr.*);
            try writer.writeAll("\n");

            try file.writeAll(buffer[0..fbs.pos]);
        }

        try file_utils.setFileHidden(self._allocator, self._dir, self._filename, true);
    }

    // Получение количества пар
    pub fn count(self: *KeyValueStore) usize {
        return self._pairs.count();
    }

    // Проверка наличия ключа
    pub fn contains(self: *KeyValueStore, key: []const u8) bool {
        return self._pairs.contains(key);
    }
};
