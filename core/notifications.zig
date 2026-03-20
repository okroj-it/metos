const std = @import("std");
const kinetics = @import("kinetics");
const strings = @import("strings");
const strings_notif = @import("strings_notif");

pub fn fmtAlert(
    buf: []u8,
    comptime key: strings.Key,
    locale: strings.Locale,
    args: anytype,
) ?[]const u8 {
    return switch (locale) {
        inline else => |loc| std.fmt.bufPrint(
            buf,
            comptime strings.get(loc, key),
            args,
        ) catch null,
    };
}

const Var = struct { name: []const u8, value: []const u8 };

fn replaceTemplate(
    tmpl: []const u8,
    vars: []const Var,
    buf: []u8,
) ?[]const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < tmpl.len) {
        if (tmpl[i] == '{') {
            var matched = false;
            for (vars) |v| {
                const end = i + 1 + v.name.len;
                if (end < tmpl.len and
                    tmpl[end] == '}' and
                    std.mem.eql(
                    u8,
                    tmpl[i + 1 .. end],
                    v.name,
                ))
                {
                    if (pos + v.value.len > buf.len)
                        return null;
                    @memcpy(
                        buf[pos .. pos + v.value.len],
                        v.value,
                    );
                    pos += v.value.len;
                    i = end + 1;
                    matched = true;
                    break;
                }
            }
            if (matched) continue;
        }
        if (pos >= buf.len) return null;
        buf[pos] = tmpl[i];
        pos += 1;
        i += 1;
    }
    return buf[0..pos];
}

pub const shake_flavors = [_][]const u8{
    "Kaktus",
    "Yummy Classic Rhubarb",
    "Jackfruit",
    "Milky Way",
};

// --- Pre-fetched data for notification checks ---

pub const WaterData = struct {
    drunk: i64,
    target: i64,
};

pub const ProteinData = struct {
    target: f64,
    current: f64,
};

// --- Pure check + format functions ---
// Callers are responsible for:
//   1. Checking isAlertSentToday before calling
//   2. Calling markAlertSent after a non-null result
//   3. Getting the template index via pickMsgIndex

pub fn formatWaterReminder(
    hour: u8,
    data: WaterData,
    idx: usize,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 21) return null;

    const threshold: i64 = if (hour < 15) 1000 else 1500;
    if (data.drunk >= threshold) return null;

    const left = @max(data.target - data.drunk, 0);

    const templates = strings_notif.waterTemplates(locale);
    if (idx >= templates.len) return null;

    var hour_buf: [8]u8 = undefined;
    const hour_str = std.fmt.bufPrint(
        &hour_buf,
        "{d}:00",
        .{hour},
    ) catch return null;
    var drunk_buf: [16]u8 = undefined;
    const drunk_str = std.fmt.bufPrint(
        &drunk_buf,
        "{d}",
        .{data.drunk},
    ) catch return null;
    var left_buf: [16]u8 = undefined;
    const left_str = std.fmt.bufPrint(
        &left_buf,
        "{d}",
        .{left},
    ) catch return null;

    return replaceTemplate(
        templates[idx],
        &[_]Var{
            .{ .name = "time", .value = hour_str },
            .{
                .name = "water_drank",
                .value = drunk_str,
            },
            .{
                .name = "water_left",
                .value = left_str,
            },
        },
        buf,
    );
}

pub fn formatProteinDeficit(
    date: []const u8,
    data: ProteinData,
    idx: usize,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    const missing = data.target - data.current;
    if (missing < 30) return null;

    const templates = strings_notif.proteinTemplates(
        locale,
    );
    if (idx >= templates.len) return null;

    const day = std.fmt.parseInt(
        usize,
        date[8..10],
        10,
    ) catch 1;
    const flavor = shake_flavors[
        (idx + day) % shake_flavors.len
    ];

    var miss_buf: [16]u8 = undefined;
    const miss_str = std.fmt.bufPrint(
        &miss_buf,
        "{d:.0}",
        .{missing},
    ) catch return null;

    return replaceTemplate(
        templates[idx],
        &[_]Var{
            .{
                .name = "missing_protein",
                .value = miss_str,
            },
            .{ .name = "flavor", .value = flavor },
        },
        buf,
    );
}

pub fn formatConcreteIndex(
    fiber: f64,
    water: i64,
    idx: usize,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (fiber < 30) return null;
    if (water >= 1500) return null;

    const templates = strings_notif.concreteTemplates(
        locale,
    );
    if (idx >= templates.len) return null;

    var fiber_buf: [16]u8 = undefined;
    const fiber_str = std.fmt.bufPrint(
        &fiber_buf,
        "{d:.0}",
        .{fiber},
    ) catch return null;
    var water_buf: [16]u8 = undefined;
    const water_str = std.fmt.bufPrint(
        &water_buf,
        "{d}",
        .{water},
    ) catch return null;

    return replaceTemplate(
        templates[idx],
        &[_]Var{
            .{ .name = "fiber", .value = fiber_str },
            .{ .name = "water", .value = water_str },
        },
        buf,
    );
}

pub fn formatStomachLoad(
    hour: u8,
    calories: i64,
    fat: f64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 20) return null;
    if (calories < 500 and fat < 20) return null;
    return fmtAlert(
        buf, .alert_stomach_load, locale,
        .{ calories, fat },
    );
}

pub fn formatPurine72h(
    high_days: i64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (high_days < 2) return null;
    return fmtAlert(
        buf, .alert_purine_72h, locale,
        .{high_days},
    );
}

pub fn formatAntiCatabolic(
    weekly_pct: f64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (weekly_pct > -1.5) return null;
    return fmtAlert(
        buf, .alert_anti_catabolic, locale,
        .{weekly_pct},
    );
}

pub fn formatForceFeed(
    hour: u8,
    suppression: f64,
    protein_target: f64,
    protein_current: f64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 12 or hour > 20) return null;
    if (suppression <= 0.8) return null;

    const hour_f: f64 = @floatFromInt(hour);
    if (protein_current >= protein_target * hour_f / 24.0)
        return null;

    return fmtAlert(
        buf, .alert_force_feed, locale,
        .{suppression * 100},
    );
}

pub fn formatPurineSentry(
    hour: u8,
    suppression: f64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 20) return null;
    if (suppression >= 0.4) return null;
    return fmtAlert(
        buf, .alert_purine_sentry, locale,
        .{suppression * 100},
    );
}

pub fn formatInjectionPhase(
    hour: u8,
    days: i64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 8 or hour > 10) return null;

    if (days >= 7) {
        return fmtAlert(
            buf, .alert_injection_due, locale,
            .{days},
        );
    }

    if (days <= 2) {
        return fmtAlert(
            buf, .alert_injection_phase_early, locale,
            .{days},
        );
    } else if (days <= 5) {
        return fmtAlert(
            buf, .alert_injection_phase_peak, locale,
            .{days},
        );
    } else {
        return fmtAlert(
            buf, .alert_injection_phase_late, locale,
            .{days},
        );
    }
}
