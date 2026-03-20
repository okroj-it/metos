const std = @import("std");
const kinetics = @import("kinetics");

pub const DatePrefix = struct {
    date: ?[]const u8,
    rest: []const u8,
};

pub fn parseDatePrefix(text: []const u8) DatePrefix {
    if (text.len < 10)
        return .{ .date = null, .rest = text };

    const candidate = text[0..10];
    if (candidate[4] != '-' or candidate[7] != '-')
        return .{ .date = null, .rest = text };

    for (candidate, 0..) |c, i| {
        if (i == 4 or i == 7) continue;
        if (c < '0' or c > '9')
            return .{ .date = null, .rest = text };
    }

    const rest = if (text.len > 10)
        std.mem.trimStart(u8, text[10..], " ")
    else
        "";

    if (rest.len == 0)
        return .{ .date = null, .rest = text };

    return .{ .date = candidate, .rest = rest };
}

pub const InjectionArgs = struct {
    dose_mg: f64,
    site_buf: [16]u8,
    site_len: usize,
    notes_start: usize,
    has_notes: bool,

    pub fn site(self: *const InjectionArgs) []const u8 {
        return self.site_buf[0..self.site_len];
    }
};

pub fn parseInjectionText(
    text: []const u8,
    default_dose: f64,
    default_site: []const u8,
) InjectionArgs {
    var result = InjectionArgs{
        .dose_mg = default_dose,
        .site_buf = undefined,
        .site_len = @min(default_site.len, 16),
        .notes_start = 0,
        .has_notes = false,
    };
    @memcpy(
        result.site_buf[0..result.site_len],
        default_site[0..result.site_len],
    );
    if (text.len == 0) return result;

    var pos: usize = 0;

    var num_end: usize = 0;
    for (text[pos..], 0..) |c, i| {
        if ((c >= '0' and c <= '9') or c == '.') {
            num_end = pos + i + 1;
        } else break;
    }
    if (num_end > pos) {
        if (std.fmt.parseFloat(
            f64,
            text[pos..num_end],
        )) |v| {
            result.dose_mg = v;
            pos = num_end;
            while (pos < text.len and text[pos] == ' ')
                pos += 1;
        } else |_| {}
    }

    for (kinetics.injection_sites) |known| {
        if (pos + known.len <= text.len and
            std.mem.eql(
            u8,
            text[pos .. pos + known.len],
            known,
        )) {
            result.site_len = known.len;
            @memcpy(
                result.site_buf[0..known.len],
                known,
            );
            pos += known.len;
            while (pos < text.len and text[pos] == ' ')
                pos += 1;
            break;
        }
    }

    if (pos < text.len) {
        result.notes_start = pos;
        result.has_notes = true;
    }
    return result;
}
