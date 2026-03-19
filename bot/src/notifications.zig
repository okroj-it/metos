const std = @import("std");
const database = @import("db.zig");
const kinetics = @import("kinetics.zig");
const strings = @import("strings.zig");
const strings_notif = @import("strings_notif.zig");

fn fmtAlert(
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

// --- Template variable replacement ---

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

const shake_flavors = [_][]const u8{
    "Kaktus",
    "Yummy Classic Rhubarb",
    "Jackfruit",
    "Milky Way",
};

// --- Check functions ---

pub fn checkWaterReminder(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 21) return null;
    const key: []const u8 = if (hour < 15)
        "water_am"
    else
        "water_pm";
    if (db.isAlertSentToday(key, date) catch false)
        return null;

    const drunk = db.getDailyWater(date) catch
        return null;
    const threshold: i64 = if (hour < 15) 1000 else 1500;
    if (drunk >= threshold) return null;

    const goal = db.getGoal() catch null;
    const base: i64 = if (goal) |g|
        g.target_water_ml orelse 3000
    else
        3000;
    const left = @max(base - drunk, 0);

    db.markAlertSent(key, date) catch {};
    const templates = strings_notif.waterTemplates(locale);
    const idx = db.pickMsgIndex("water", 15) catch
        return null;
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
        .{drunk},
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

pub fn checkProteinDeficit(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 20 or hour > 22) return null;
    if (db.isAlertSentToday(
        "protein_deficit",
        date,
    ) catch false)
        return null;

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse
        return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;
    const missing = target - current;
    if (missing < 30) return null;

    db.markAlertSent("protein_deficit", date) catch {};
    const templates = strings_notif.proteinTemplates(
        locale,
    );
    const idx = db.pickMsgIndex("protein", 15) catch
        return null;
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

pub fn checkConcreteIndex(
    db: database.Db,
    date: []const u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday("concrete", date) catch false)
        return null;

    const fiber = db.getDailyFiberTotal(date) catch
        return null;
    if (fiber < 30) return null;

    const water = db.getDailyWater(date) catch
        return null;
    if (water >= 1500) return null;

    db.markAlertSent("concrete", date) catch {};
    const templates = strings_notif.concreteTemplates(
        locale,
    );
    const idx = db.pickMsgIndex("concrete", 15) catch
        return null;
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

pub fn checkStomachLoad(
    db: database.Db,
    date: []const u8,
    hour: u8,
    calories: i64,
    fat: f64,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 20) return null;
    if (calories < 500 and fat < 20) return null;
    if (db.isAlertSentToday(
        "stomach_load",
        date,
    ) catch false) return null;

    db.markAlertSent("stomach_load", date) catch {};
    return fmtAlert(
        buf, .alert_stomach_load, locale,
        .{ calories, fat },
    );
}

pub fn checkPurine72h(
    db: database.Db,
    date: []const u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday(
        "purine_72h",
        date,
    ) catch false) return null;

    const high_days = db.countHighPurineDays(date) catch
        return null;
    if (high_days < 2) return null;

    db.markAlertSent("purine_72h", date) catch {};
    return fmtAlert(
        buf, .alert_purine_72h, locale,
        .{high_days},
    );
}

pub fn checkAntiCatabolic(
    db: database.Db,
    date: []const u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday(
        "anti_catabolic",
        date,
    ) catch false) return null;

    const pct = (db.getWeeklyWeightChange(date) catch
        return null) orelse return null;
    if (pct > -1.5) return null;

    db.markAlertSent("anti_catabolic", date) catch {};
    return fmtAlert(
        buf, .alert_anti_catabolic, locale,
        .{pct},
    );
}

pub fn checkForceFeed(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 12 or hour > 20) return null;
    if (db.isAlertSentToday("force_feed", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );
    if (suppression <= 0.8) return null;

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;
    const hour_f: f64 = @floatFromInt(hour);
    if (current >= target * hour_f / 24.0) return null;

    db.markAlertSent("force_feed", date) catch {};
    return fmtAlert(
        buf, .alert_force_feed, locale,
        .{suppression * 100},
    );
}

pub fn checkPurineSentry(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 10 or hour > 20) return null;
    if (db.isAlertSentToday("purine_sentry", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );
    if (suppression >= 0.4) return null;

    db.markAlertSent("purine_sentry", date) catch {};
    return fmtAlert(
        buf, .alert_purine_sentry, locale,
        .{suppression * 100},
    );
}

pub fn checkInjection(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (hour < 8 or hour > 10) return null;

    const days = (db.daysSinceInjection(date) catch
        return null) orelse return null;

    if (days >= 7) {
        if (db.isAlertSentToday(
            "injection_due",
            date,
        ) catch false) return null;
        db.markAlertSent(
            "injection_due",
            date,
        ) catch {};
        return fmtAlert(
            buf, .alert_injection_due, locale,
            .{days},
        );
    }

    if (db.isAlertSentToday(
        "injection_phase",
        date,
    ) catch false) return null;
    db.markAlertSent(
        "injection_phase",
        date,
    ) catch {};

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
