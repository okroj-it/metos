const std = @import("std");

/// Pharmacokinetic parameters for GLP-1 receptor agonists.
/// Swap this config to support a different medication.
pub const Config = struct {
    /// Elimination half-life (hours)
    t_half_elim_h: f64,
    /// Subcutaneous absorption half-life (hours)
    t_half_abs_h: f64,
    /// Effective appetite suppression half-life (hours)
    t_half_suppression_h: f64,
    /// Time to peak suppression (hours)
    t_peak_h: f64,
    /// Default dose when historical data missing (mg)
    default_dose_mg: f64,
    /// Injection cycle length (days)
    cycle_days: u8,

    fn kElim(self: Config) f64 {
        return LN2 / self.t_half_elim_h;
    }
    fn kAbs(self: Config) f64 {
        return LN2 / self.t_half_abs_h;
    }
    fn kSuppression(self: Config) f64 {
        return LN2 / self.t_half_suppression_h;
    }
};

const LN2: f64 = 0.693147;

/// Tirzepatide (Mounjaro) — weekly 2.5–15 mg SC
pub const tirzepatide = Config{
    .t_half_elim_h = 120.0,
    .t_half_abs_h = 24.0,
    .t_half_suppression_h = 72.0,
    .t_peak_h = 72.0,
    .default_dose_mg = 2.5,
    .cycle_days = 7,
};

/// Active drug config. Change this to switch medication.
const cfg = tirzepatide;

pub const Dose = struct {
    hours_ago: f64,
    dose_mg: f64,
};

/// Raw single-dose plasma contribution at t hours
/// (two-compartment absorption-elimination model).
fn singleDoseRaw(t: f64, dose_mg: f64) f64 {
    if (t <= 0) return 0;
    const elim = @exp(-cfg.kElim() * t);
    const abs = @exp(-cfg.kAbs() * t);
    return dose_mg * @max(elim - abs, 0.0);
}

/// Summed plasma level from recent doses (mg-equivalent).
/// Linear superposition — correct for first-order kinetics.
pub fn plasmaLevel(doses: []const Dose) f64 {
    var total: f64 = 0;
    for (doses) |d| {
        total += singleDoseRaw(d.hours_ago, d.dose_mg);
    }
    return total;
}

/// Appetite suppression scale 0.0–1.0.
/// 0–t_peak: quadratic ease-out ramp to 1.0
/// t_peak+: exponential decay with effective t½
/// At 168h (7 days): ~0.40
pub fn appetiteSuppression(hours_since_last: f64) f32 {
    if (hours_since_last < 0) return 0;
    if (hours_since_last <= cfg.t_peak_h) {
        const t = hours_since_last / cfg.t_peak_h;
        return @floatCast(1.0 - (1.0 - t) * (1.0 - t));
    }
    const decay = @exp(
        -cfg.kSuppression() * (hours_since_last - cfg.t_peak_h),
    );
    return @floatCast(@max(0.0, decay));
}

/// Injection site rotation (6 sites for lipodystrophy
/// prevention).
pub const injection_sites = [_][]const u8{
    "brzuch_L", "brzuch_P",
    "udo_L",    "udo_P",
    "ramie_L",  "ramie_P",
};

/// Suggest next injection site — least-recently-used.
pub fn suggestSite(recent: []const []const u8) []const u8 {
    for (injection_sites) |candidate| {
        var found = false;
        for (recent) |used| {
            if (std.mem.eql(u8, candidate, used)) {
                found = true;
                break;
            }
        }
        if (!found) return candidate;
    }
    if (recent.len > 0) {
        const oldest = recent[recent.len - 1];
        for (injection_sites, 0..) |site, i| {
            if (std.mem.eql(u8, site, oldest)) {
                return injection_sites[
                    (i + 1) % injection_sites.len
                ];
            }
        }
    }
    return injection_sites[0];
}
