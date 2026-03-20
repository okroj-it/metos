const std = @import("std");
const database = @import("db.zig");
const kinetics = @import("kinetics");
const strings = @import("strings");
const core = @import("notifications");

pub fn checkWaterReminder(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    const key: []const u8 = if (hour < 15)
        "water_am"
    else
        "water_pm";
    if (db.isAlertSentToday(key, date) catch false)
        return null;

    const drunk = db.getDailyWater(date) catch
        return null;
    const goal = db.getGoal() catch null;
    const target: i64 = if (goal) |g|
        g.target_water_ml orelse 3000
    else
        3000;

    const idx = db.pickMsgIndex("water", 15) catch
        return null;

    const msg = core.formatWaterReminder(
        hour,
        .{ .drunk = drunk, .target = target },
        idx,
        locale,
        buf,
    ) orelse return null;

    db.markAlertSent(key, date) catch {};
    return msg;
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
    ) catch false) return null;

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse
        return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;

    const idx = db.pickMsgIndex("protein", 15) catch
        return null;

    const msg = core.formatProteinDeficit(
        date,
        .{ .target = target, .current = current },
        idx,
        locale,
        buf,
    ) orelse return null;

    db.markAlertSent("protein_deficit", date) catch {};
    return msg;
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
    const water = db.getDailyWater(date) catch
        return null;

    const idx = db.pickMsgIndex("concrete", 15) catch
        return null;

    const msg = core.formatConcreteIndex(
        fiber, water, idx, locale, buf,
    ) orelse return null;

    db.markAlertSent("concrete", date) catch {};
    return msg;
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
    if (db.isAlertSentToday(
        "stomach_load",
        date,
    ) catch false) return null;

    const msg = core.formatStomachLoad(
        hour, calories, fat, locale, buf,
    ) orelse return null;

    db.markAlertSent("stomach_load", date) catch {};
    return msg;
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

    const msg = core.formatPurine72h(
        high_days, locale, buf,
    ) orelse return null;

    db.markAlertSent("purine_72h", date) catch {};
    return msg;
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

    const msg = core.formatAntiCatabolic(
        pct, locale, buf,
    ) orelse return null;

    db.markAlertSent("anti_catabolic", date) catch {};
    return msg;
}

pub fn checkForceFeed(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday("force_feed", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );

    const goal = (db.getGoal() catch return null)
        orelse return null;
    const target = goal.target_protein_g orelse
        return null;
    const current = db.getDailyProteinTotal(date) catch
        return null;

    const msg = core.formatForceFeed(
        hour, suppression, target, current,
        locale, buf,
    ) orelse return null;

    db.markAlertSent("force_feed", date) catch {};
    return msg;
}

pub fn checkPurineSentry(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    if (db.isAlertSentToday("purine_sentry", date) catch false)
        return null;

    const inj = db.getRecentInjections(
        date, hour,
    ) catch return null;
    if (inj.len == 0) return null;

    const suppression = kinetics.appetiteSuppression(
        inj.records[0].hours_ago,
    );

    const msg = core.formatPurineSentry(
        hour, suppression, locale, buf,
    ) orelse return null;

    db.markAlertSent("purine_sentry", date) catch {};
    return msg;
}

pub fn checkInjection(
    db: database.Db,
    date: []const u8,
    hour: u8,
    locale: strings.Locale,
    buf: []u8,
) ?[]const u8 {
    const days = (db.daysSinceInjection(date) catch
        return null) orelse return null;

    if (days >= 7) {
        if (db.isAlertSentToday(
            "injection_due",
            date,
        ) catch false) return null;

        const msg = core.formatInjectionPhase(
            hour, days, locale, buf,
        ) orelse return null;

        db.markAlertSent(
            "injection_due",
            date,
        ) catch {};
        return msg;
    }

    if (db.isAlertSentToday(
        "injection_phase",
        date,
    ) catch false) return null;

    const msg = core.formatInjectionPhase(
        hour, days, locale, buf,
    ) orelse return null;

    db.markAlertSent(
        "injection_phase",
        date,
    ) catch {};
    return msg;
}
