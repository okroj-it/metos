const std = @import("std");

pub const Locale = enum {
    en,
    pl,

    pub fn llmName(self: Locale) []const u8 {
        return switch (self) {
            .en => "English",
            .pl => "Polish",
        };
    }

    pub fn llmCode(self: Locale) []const u8 {
        return switch (self) {
            .en => "en",
            .pl => "pl",
        };
    }
};

pub const Key = enum {
    // err_*
    access_denied,
    err_send_text_or_voice,
    err_invalid_weight,
    err_invalid_number,
    err_invalid_calories,
    err_invalid_protein,
    err_meal_analysis_failed,
    err_meal_save_failed,
    err_weight_save_failed,
    err_water_reset_failed,
    err_water_save_failed,
    err_goal_reset_failed,
    err_goal_save_failed,
    err_undo_failed,
    err_injection_save_failed,
    err_goal_fetch_failed,
    err_stats_fetch_failed,
    err_meals_fetch_failed,
    err_history_fetch_failed,
    err_audio_download_failed,
    err_transcribe_failed,
    err_memory,

    // usage_*
    usage_weight,
    usage_water,
    usage_goal,

    // confirm_*
    confirm_weight,
    confirm_weight_no_note,
    confirm_weight_fallback,
    confirm_water_reset,
    confirm_water_subtract,
    confirm_water_add,
    confirm_water_fallback,
    confirm_goal_reset,
    confirm_goal,
    confirm_goal_fallback,
    confirm_injection,
    confirm_injection_fallback,
    confirm_undo,

    // ok_*
    ok_weight,
    ok_weight_fallback,
    ok_water_reset,
    ok_water,
    ok_water_fallback,
    ok_goal_reset,
    ok_goal,
    ok_goal_fallback,
    ok_undo,
    ok_undo_fallback,
    ok_injection,
    ok_injection_fallback,
    no_meals_to_undo,

    // cmd_*
    cmd_start,
    cmd_help,

    // menu descriptions
    menu_start,
    menu_help,
    menu_weight,
    menu_water,
    menu_stats,
    menu_meals,
    menu_history,
    menu_goal,
    menu_injection,
    menu_undo,

    // meal
    meal_summary,
    meal_summary_basic,
    meal_date_note,
    gout_warning_line,
    meal_saved_fallback,

    // stats
    stats_template,
    stats_pharma,
    stats_gout_alert,
    stats_fallback,
    stats_no_data,

    // meals/history
    meals_header,
    no_meals,
    history_header,
    no_weigh_ins,

    // goal display
    goal_show,
    goal_show_fallback,
    no_goal,

    // voice
    voice_transcribing,
    voice_transcript_prefix,
    voice_edit_prompt,
    no_pending_transcript,
    no_pending_command,
    cancelled,

    // buttons
    btn_yes,
    btn_no,
    btn_approve,
    btn_edit,

    // alerts
    alert_stomach_load,
    alert_purine_72h,
    alert_anti_catabolic,
    alert_force_feed,
    alert_purine_sentry,
    alert_injection_due,
    alert_injection_phase_early,
    alert_injection_phase_peak,
    alert_injection_phase_late,

    // onboarding
    onboard_welcome,
    onboard_ask_locale,
    onboard_ask_gout,
    onboard_ask_glp1,
    onboard_done,

    // settings
    settings_current,
    settings_updated,

    // feature disabled
    feature_injection_disabled,
};

pub fn get(locale: Locale, key: Key) []const u8 {
    return switch (locale) {
        .en => enStr(key),
        .pl => plStr(key),
    };
}

pub fn siteDisplayName(
    locale: Locale,
    key: []const u8,
) []const u8 {
    const sites = switch (locale) {
        .en => &en_sites,
        .pl => &pl_sites,
    };
    for (sites) |entry| {
        if (std.mem.eql(u8, key, entry[0]))
            return entry[1];
    }
    return key;
}

const SiteEntry = [2][]const u8;

const en_sites = [_]SiteEntry{
    .{ "brzuch_L", "Abdomen L" },
    .{ "brzuch_P", "Abdomen R" },
    .{ "udo_L", "Thigh L" },
    .{ "udo_P", "Thigh R" },
    .{ "ramie_L", "Arm L" },
    .{ "ramie_P", "Arm R" },
};

const pl_sites = [_]SiteEntry{
    .{ "brzuch_L", "Brzuch L" },
    .{ "brzuch_P", "Brzuch P" },
    .{ "udo_L", "Udo L" },
    .{ "udo_P", "Udo P" },
    .{ "ramie_L", "Rami\xC4\x99 L" },
    .{ "ramie_P", "Rami\xC4\x99 P" },
};

fn enStr(key: Key) []const u8 {
    return switch (key) {
        // --- errors ---
        .access_denied =>
            "No business between us "
                ++ "\xE2\x98\xA0\xEF\xB8\x8F",
        .err_send_text_or_voice =>
            "Send me text or a voice message.",
        .err_invalid_weight => "Invalid weight.",
        .err_invalid_number => "Invalid number.",
        .err_invalid_calories => "Invalid calorie count.",
        .err_invalid_protein => "Invalid protein amount.",
        .err_meal_analysis_failed =>
            "Failed to analyze meal. Try again.",
        .err_meal_save_failed =>
            "Failed to save meal.",
        .err_weight_save_failed =>
            "Failed to save weight.",
        .err_water_reset_failed =>
            "Failed to reset.",
        .err_water_save_failed =>
            "Failed to save.",
        .err_goal_reset_failed =>
            "Failed to reset goal.",
        .err_goal_save_failed =>
            "Failed to save goal.",
        .err_undo_failed =>
            "Failed to delete.",
        .err_injection_save_failed =>
            "Failed to save injection.",
        .err_goal_fetch_failed =>
            "Failed to fetch goal.",
        .err_stats_fetch_failed =>
            "Failed to fetch stats.",
        .err_meals_fetch_failed =>
            "Failed to fetch meals.",
        .err_history_fetch_failed =>
            "Failed to fetch history.",
        .err_audio_download_failed =>
            "Failed to download audio.",
        .err_transcribe_failed =>
            "Failed to transcribe audio.",
        .err_memory => "Memory error.",

        // --- usage ---
        .usage_weight =>
            "Usage: /weight 95.2 [note]",
        .usage_water =>
            "Usage: /water 500 | -200 | reset",
        .usage_goal =>
            "Usage: /goal 2000 150 (kcal, protein g)",

        // --- confirm ---
        .confirm_weight =>
            "\xE2\x9A\x96\xEF\xB8\x8F"
                ++ " Save weight {d:.1} kg ({s})?",
        .confirm_weight_no_note =>
            "\xE2\x9A\x96\xEF\xB8\x8F"
                ++ " Save weight {d:.1} kg?",
        .confirm_weight_fallback =>
            "Save weight?",
        .confirm_water_reset =>
            "\xF0\x9F\x92\xA7"
                ++ " Reset today's water?",
        .confirm_water_subtract =>
            "\xF0\x9F\x92\xA7"
                ++ " Remove {d}ml of water?",
        .confirm_water_add =>
            "\xF0\x9F\x92\xA7"
                ++ " Add {d}ml of water?",
        .confirm_water_fallback =>
            "Save water?",
        .confirm_goal_reset =>
            "\xF0\x9F\x8E\xAF Delete goal?",
        .confirm_goal =>
            "\xF0\x9F\x8E\xAF"
                ++ " Goal: {d} kcal, {d:.0}g protein?",
        .confirm_goal_fallback =>
            "Set goal?",
        .confirm_injection =>
            "\xF0\x9F\x92\x89 Save injection?"
                ++ "\n{d:.1}mg, {s}",
        .confirm_injection_fallback =>
            "Save injection?",
        .confirm_undo =>
            "\xF0\x9F\x97\x91 Delete last meal?",

        // --- ok ---
        .ok_weight =>
            "\xE2\x9C\x85 Weight: {d:.1} kg",
        .ok_weight_fallback => "Weight saved.",
        .ok_water_reset =>
            "\xE2\x9C\x85 Today's water reset.",
        .ok_water =>
            "\xE2\x9C\x85"
                ++ " Water: {d}ml (today: {d}ml)",
        .ok_water_fallback => "Water saved.",
        .ok_goal_reset =>
            "\xE2\x9C\x85 Goal deleted.",
        .ok_goal =>
            "\xE2\x9C\x85"
                ++ " Goal: {d} kcal, {d:.0}g protein",
        .ok_goal_fallback => "Goal saved.",
        .ok_undo =>
            "\xE2\x9C\x85 Deleted: {s}",
        .ok_undo_fallback => "Meal deleted.",
        .ok_injection =>
            "\xE2\x9C\x85"
                ++ " Injection: {d:.1}mg, {s}",
        .ok_injection_fallback =>
            "Injection saved.",
        .no_meals_to_undo =>
            "No meals to delete.",

        // --- commands ---
        .cmd_start =>
            "\xE2\x96\x88 MetOS \xE2\x80\x94"
                ++ " Metabolic Operating System"
                ++ "\n\nWelcome to MetOS."
                ++ " Your systematic road"
                ++ " (\xCE\xBC\xCE\xAD\xCE\xB8"
                ++ "\xCE\xBF\xCF\x82)"
                ++ " to metabolic optimization"
                ++ " starts here."
                ++ "\n\nSend text or a voice note"
                ++ " describing a meal,"
                ++ " and MetOS will analyze"
                ++ " composition and risk."
                ++ "\n\nType /help for commands.",
        .cmd_help =>
            "\xE2\x96\x88 MetOS v0.1-alpha"
                ++ "\n\nText/voice = meal analysis"
                ++ "\n/weight 95.2 [note]"
                ++ "\n/water 500 | -200 | reset"
                ++ "\n/stats [YYYY-MM-DD]"
                ++ "\n/meals [YYYY-MM-DD]"
                ++ "\n/history"
                ++ "\n/goal 2000 150"
                ++ " (kcal/protein)"
                ++ "\n/goal | /goal reset"
                ++ "\n/injection [dose]"
                ++ " [site] [note]"
                ++ "\n/undo"
                ++ "\n\n\xCE\x9A\xCE\xB1\xCF\x84"
                ++ "\xCE\xAC \xCE\x9C\xCE\xAD"
                ++ "\xCE\xB8\xCE\xBF\xCE\xB4"
                ++ "\xCE\xBF\xCE\xBD",

        // --- menu descriptions ---
        .menu_start => "Start MetOS",
        .menu_help => "Show commands",
        .menu_weight => "Log weight",
        .menu_water => "Log water intake",
        .menu_stats => "Daily summary",
        .menu_meals => "List meals",
        .menu_history => "Weight history",
        .menu_goal => "Set calorie/protein goal",
        .menu_injection => "Log Mounjaro injection",
        .menu_undo => "Delete last meal",

        // --- meal ---
        .meal_summary =>
            "\xE2\x9C\x85 {s}\n"
                ++ "{d} kcal"
                ++ " | P:{d:.0}g C:{d:.0}g F:{d:.0}g\n"
                ++ "Fiber: {d:.0}g"
                ++ " | Protein density: {d:.2}\n"
                ++ "Purines: {s} ({d:.0}mg)"
                ++ " confidence: {s}\n"
                ++ "Water: {d}ml\n"
                ++ "{s}{s}",
        .meal_summary_basic =>
            "\xE2\x9C\x85 {s}\n"
                ++ "{d} kcal"
                ++ " | P:{d:.0}g C:{d:.0}g F:{d:.0}g\n"
                ++ "Fiber: {d:.0}g"
                ++ " | Protein density: {d:.2}\n"
                ++ "Water: {d}ml",
        .meal_date_note =>
            "\xF0\x9F\x93\x85 Logged for {s}\n",
        .gout_warning_line =>
            "\xE2\x9A\xA0\xEF\xB8\x8F GOUT WARNING\n",
        .meal_saved_fallback => "Meal saved.",

        // --- stats ---
        .stats_template =>
            "\xE2\x96\x88 MetOS [v0.1]"
                ++ " \xE2\x80\x94 {s}"
                ++ "\n\n[METABOLIC LOAD]"
                ++ "\n{d}\xC3\x97 | {d} kcal"
                ++ "\nP:{d:.0}g C:{d:.0}g"
                ++ " F:{d:.0}g Fi:{d:.0}g"
                ++ "\nPurines: {s}"
                ++ "{s}"
                ++ "\n\n[SYSTEM STATUS]"
                ++ "\n\xF0\x9F\x92\xA7 {d} ml"
                ++ "\n{s}"
                ++ "\n\n\xCE\x9A\xCE\xB1\xCF\x84\xCE\xAC"
                ++ " \xCE\x9C\xCE\xAD\xCE\xB8\xCE\xBF"
                ++ "\xCE\xB4\xCE\xBF\xCE\xBD",
        .stats_pharma =>
            "\n[PHARMA STATUS]"
                ++ "\nMounjaro"
                ++ " | day {d}"
                ++ " | suppr. {d:.0}%",
        .stats_gout_alert =>
            "\xE2\x9A\xA0\xEF\xB8\x8F GOUT ALERT",
        .stats_fallback =>
            "MetOS: report unavailable.",
        .stats_no_data =>
            "No data for this day.",

        // --- meals/history ---
        .meals_header =>
            "\xF0\x9F\x8D\xBD Meals on {s}:\n{s}",
        .no_meals =>
            "No meals for this day.",
        .history_header =>
            "\xF0\x9F\x93\x88"
                ++ " Recent weigh-ins:\n{s}",
        .no_weigh_ins =>
            "No weigh-in records.",

        // --- goal display ---
        .goal_show =>
            "\xF0\x9F\x8E\xAF Current goal:\n"
                ++ "Calories: {d} kcal\n"
                ++ "Protein: {d:.0}g",
        .goal_show_fallback => "Goal set.",
        .no_goal =>
            "No goal set."
                ++ " Usage: /goal 2000 150",

        // --- voice ---
        .voice_transcribing =>
            "\xF0\x9F\x8E\x99 Transcribing...",
        .voice_transcript_prefix =>
            "\xF0\x9F\x8E\x99 Transcript:\n\n{s}",
        .voice_edit_prompt =>
            "\xE2\x9C\x8F\xEF\xB8\x8F"
                ++ " Send corrected text:",
        .no_pending_transcript =>
            "No pending transcript.",
        .no_pending_command =>
            "No pending command.",
        .cancelled => "Cancelled.",

        // --- buttons ---
        .btn_yes => "\xE2\x9C\x85 Yes",
        .btn_no => "\xE2\x9D\x8C No",
        .btn_approve =>
            "\xE2\x9C\x85 Approve",
        .btn_edit =>
            "\xE2\x9C\x8F\xEF\xB8\x8F Edit",

        // --- alerts ---
        .alert_stomach_load =>
            "\xE2\x9A\xA0\xEF\xB8\x8F"
                ++ " Heavy meal after 8 PM!"
                ++ "\n{d} kcal, {d:.0}g fat."
                ++ " Mounjaro slows gastric"
                ++ " emptying"
                ++ " \xE2\x80\x94 reflux risk!",
        .alert_purine_72h =>
            "\xF0\x9F\x92\x80"
                ++ " 72h purine buffer exceeded!"
                ++ "\n{d} of 3 days"
                ++ " with high purines."
                ++ "\nToday dairy/WPI only"
                ++ " \xE2\x80\x94 no meat!"
                ++ "\nUric acid accumulates"
                ++ " \xE2\x80\x94"
                ++ " give your joints a break.",
        .alert_anti_catabolic =>
            "\xE2\x9A\xA0\xEF\xB8\x8F"
                ++ " Weight dropping too fast!"
                ++ "\nWeekly change: {d:.1}%"
                ++ "\nThis steep a drop burns"
                ++ " muscle, not fat."
                ++ "\nAdd +150-200 kcal to"
                ++ " protect lean tissue.",
        .alert_force_feed =>
            "\xF0\x9F\xA5\xA4 Force Feed!"
                ++ " Peak suppression ({d:.0}%)."
                ++ "\nNo hunger doesn't mean"
                ++ " your body doesn't"
                ++ " need fuel."
                ++ "\nDrink a WPI/Skyr shake!",
        .alert_purine_sentry =>
            "\xF0\x9F\x94\x94 Purine Sentry!"
                ++ " Suppression dropped"
                ++ " to {d:.0}%."
                ++ "\nReturning appetite"
                ++ " = risk of breaking"
                ++ " purine buffer."
                ++ "\nStick to dairy and WPI!",
        .alert_injection_due =>
            "\xF0\x9F\x92\x89"
                ++ " Time for your Mounjaro"
                ++ " injection!"
                ++ "\nLast one: {d} days ago."
                ++ "\nAppetite is returning"
                ++ " \xE2\x80\x94 don't wait.",
        .alert_injection_phase_early =>
            "\xF0\x9F\x92\x89 Day {d}"
                ++ " post-injection."
                ++ "\nAbsorption phase."
                ++ " Possible nausea and"
                ++ " reduced appetite."
                ++ "\nEat small but"
                ++ " regular meals.",
        .alert_injection_phase_peak =>
            "\xF0\x9F\x8E\xAF Day {d}"
                ++ " post-injection."
                ++ "\nPeak appetite suppression."
                ++ "\nUse this window"
                ++ " \xE2\x80\x94 best time"
                ++ " for cutting.",
        .alert_injection_phase_late =>
            "\xF0\x9F\x93\x88 Day {d}"
                ++ " post-injection."
                ++ "\nAppetite returning."
                ++ " Watch for impulses!"
                ++ "\nStick to your"
                ++ " macro plan.",

        // --- onboarding ---
        .onboard_welcome =>
            "\xE2\x96\x88 MetOS \xE2\x80\x94"
                ++ " Metabolic Operating System"
                ++ "\n\nLet's set up your profile.",
        .onboard_ask_locale =>
            "\xF0\x9F\x8C\x90 Choose your language:",
        .onboard_ask_gout =>
            "Do you want gout/purine tracking?"
                ++ "\n(Monitors uric acid risk"
                ++ " from food)",
        .onboard_ask_glp1 =>
            "Are you taking a GLP-1 agonist"
                ++ " (Mounjaro/Ozempic/Wegovy)?"
                ++ "\n(Enables injection tracking"
                ++ " and pharmacokinetics)",
        .onboard_done =>
            "\xE2\x9C\x85 Setup complete!"
                ++ " Send a meal description"
                ++ " or type /help.",

        // --- settings ---
        .settings_current =>
            "\xE2\x9A\x99\xEF\xB8\x8F Settings:"
                ++ "\nLocale: {s}"
                ++ "\nGout tracking: {s}"
                ++ "\nGLP-1 tracking: {s}"
                ++ "\n\nUse /start to reconfigure.",
        .settings_updated =>
            "\xE2\x9C\x85 Settings updated.",

        // --- feature disabled ---
        .feature_injection_disabled =>
            "Injection tracking is disabled."
                ++ " Use /start to enable GLP-1"
                ++ " tracking.",
    };
}

fn plStr(key: Key) []const u8 {
    return switch (key) {
        // --- errors ---
        .access_denied =>
            "Nie b\xC4\x99dzie mi\xC4\x99dzy nami"
                ++ " interes\xC3\xB3w"
                ++ " \xE2\x98\xA0\xEF\xB8\x8F",
        .err_send_text_or_voice =>
            "Wy\xC5\x9Blij mi tekst lub"
                ++ " wiadomo\xC5\x9B\xC4\x87"
                ++ " g\xC5\x82osow\xC4\x85.",
        .err_invalid_weight =>
            "Nieprawid\xC5\x82owa waga.",
        .err_invalid_number =>
            "Nieprawid\xC5\x82owa liczba.",
        .err_invalid_calories =>
            "Nieprawid\xC5\x82owa liczba kalorii.",
        .err_invalid_protein =>
            "Nieprawid\xC5\x82owa ilo\xC5\x9B\xC4\x87"
                ++ " bia\xC5\x82ka.",
        .err_meal_analysis_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " przeanalizowa\xC4\x87"
                ++ " posi\xC5\x82ku."
                ++ " Spr\xC3\xB3buj ponownie.",
        .err_meal_save_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zapisa\xC4\x87"
                ++ " posi\xC5\x82ku.",
        .err_weight_save_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zapisa\xC4\x87 wagi.",
        .err_water_reset_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zresetowa\xC4\x87.",
        .err_water_save_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zapisa\xC4\x87.",
        .err_goal_reset_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zresetowa\xC4\x87 celu.",
        .err_goal_save_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zapisa\xC4\x87 celu.",
        .err_undo_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " usun\xC4\x85\xC4\x87.",
        .err_injection_save_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " zapisa\xC4\x87 zastrzyku.",
        .err_goal_fetch_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " pobra\xC4\x87 celu.",
        .err_stats_fetch_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " pobra\xC4\x87 statystyk.",
        .err_meals_fetch_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " pobra\xC4\x87"
                ++ " posi\xC5\x82k\xC3\xB3w.",
        .err_history_fetch_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " pobra\xC4\x87 historii.",
        .err_audio_download_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " pobra\xC4\x87 audio.",
        .err_transcribe_failed =>
            "Nie uda\xC5\x82o si\xC4\x99"
                ++ " transkrybowa\xC4\x87 audio.",
        .err_memory =>
            "B\xC5\x82\xC4\x85d pami\xC4\x99ci.",

        // --- usage ---
        .usage_weight =>
            "U\xC5\xBCycie: /weight 95.2 [notatka]",
        .usage_water =>
            "U\xC5\xBCycie: /water 500 | -200 | reset",
        .usage_goal =>
            "U\xC5\xBCycie: /goal 2000 150"
                ++ " (kcal, bia\xC5\x82ko g)",

        // --- confirm ---
        .confirm_weight =>
            "\xE2\x9A\x96\xEF\xB8\x8F"
                ++ " Zapisa\xC4\x87"
                ++ " wag\xC4\x99 {d:.1} kg ({s})?",
        .confirm_weight_no_note =>
            "\xE2\x9A\x96\xEF\xB8\x8F"
                ++ " Zapisa\xC4\x87"
                ++ " wag\xC4\x99 {d:.1} kg?",
        .confirm_weight_fallback =>
            "Zapisa\xC4\x87 wag\xC4\x99?",
        .confirm_water_reset =>
            "\xF0\x9F\x92\xA7 Zresetowa\xC4\x87"
                ++ " wod\xC4\x99 na dzi\xC5\x9B?",
        .confirm_water_subtract =>
            "\xF0\x9F\x92\xA7 Odj\xC4\x85\xC4\x87"
                ++ " {d}ml wody?",
        .confirm_water_add =>
            "\xF0\x9F\x92\xA7 Doda\xC4\x87"
                ++ " {d}ml wody?",
        .confirm_water_fallback =>
            "Zapisa\xC4\x87 wod\xC4\x99?",
        .confirm_goal_reset =>
            "\xF0\x9F\x8E\xAF"
                ++ " Usun\xC4\x85\xC4\x87 cel?",
        .confirm_goal =>
            "\xF0\x9F\x8E\xAF Cel: {d} kcal,"
                ++ " {d:.0}g bia\xC5\x82ka?",
        .confirm_goal_fallback =>
            "Ustawi\xC4\x87 cel?",
        .confirm_injection =>
            "\xF0\x9F\x92\x89"
                ++ " Zapisa\xC4\x87 zastrzyk?"
                ++ "\n{d:.1}mg, {s}",
        .confirm_injection_fallback =>
            "Zapisa\xC4\x87 zastrzyk?",
        .confirm_undo =>
            "\xF0\x9F\x97\x91"
                ++ " Usun\xC4\x85\xC4\x87"
                ++ " ostatni posi\xC5\x82ek?",

        // --- ok ---
        .ok_weight =>
            "\xE2\x9C\x85 Waga: {d:.1} kg",
        .ok_weight_fallback =>
            "Waga zapisana.",
        .ok_water_reset =>
            "\xE2\x9C\x85 Woda na dzi\xC5\x9B"
                ++ " zresetowana.",
        .ok_water =>
            "\xE2\x9C\x85"
                ++ " Woda: {d}ml"
                ++ " (dzi\xC5\x9B: {d}ml)",
        .ok_water_fallback =>
            "Woda zapisana.",
        .ok_goal_reset =>
            "\xE2\x9C\x85 Cel usuni\xC4\x99ty.",
        .ok_goal =>
            "\xE2\x9C\x85 Cel: {d} kcal,"
                ++ " {d:.0}g bia\xC5\x82ka",
        .ok_goal_fallback =>
            "Cel zapisany.",
        .ok_undo =>
            "\xE2\x9C\x85"
                ++ " Usuni\xC4\x99to: {s}",
        .ok_undo_fallback =>
            "Posi\xC5\x82ek usuni\xC4\x99ty.",
        .ok_injection =>
            "\xE2\x9C\x85"
                ++ " Zastrzyk: {d:.1}mg, {s}",
        .ok_injection_fallback =>
            "Zastrzyk zapisany.",
        .no_meals_to_undo =>
            "Brak posi\xC5\x82k\xC3\xB3w do"
                ++ " usuni\xC4\x99cia.",

        // --- commands ---
        .cmd_start =>
            "\xE2\x96\x88 MetOS \xE2\x80\x94"
                ++ " Metabolic Operating System"
                ++ "\n\nWitaj w MetOS."
                ++ " Twoja systematyczna droga"
                ++ " (\xCE\xBC\xCE\xAD\xCE\xB8"
                ++ "\xCE\xBF\xCF\x82)"
                ++ " do optymalizacji"
                ++ " metabolicznej zaczyna"
                ++ " si\xC4\x99 tutaj."
                ++ "\n\nWy\xC5\x9Blij tekst lub"
                ++ " g\xC5\x82os\xC3\xB3wk\xC4\x99"
                ++ " z opisem posi\xC5\x82ku,"
                ++ " a MetOS przeanalizuje"
                ++ " sk\xC5\x82ad i ryzyko."
                ++ "\n\nWpisz /help po"
                ++ " list\xC4\x99 komend.",
        .cmd_help =>
            "\xE2\x96\x88 MetOS v0.1-alpha"
                ++ "\n\nTekst/g\xC5\x82os ="
                ++ " analiza posi\xC5\x82ku"
                ++ "\n/weight 95.2 [notatka]"
                ++ "\n/water 500 | -200 | reset"
                ++ "\n/stats [RRRR-MM-DD]"
                ++ "\n/meals [RRRR-MM-DD]"
                ++ "\n/history"
                ++ "\n/goal 2000 150"
                ++ " (kcal/bia\xC5\x82ko)"
                ++ "\n/goal | /goal reset"
                ++ "\n/injection [dawka]"
                ++ " [miejsce] [notatka]"
                ++ "\n/undo"
                ++ "\n\n\xCE\x9A\xCE\xB1\xCF\x84"
                ++ "\xCE\xAC \xCE\x9C\xCE\xAD"
                ++ "\xCE\xB8\xCE\xBF\xCE\xB4"
                ++ "\xCE\xBF\xCE\xBD",

        // --- menu descriptions ---
        .menu_start => "Uruchom MetOS",
        .menu_help => "Poka\xC5\xBC komendy",
        .menu_weight => "Zapisz wag\xC4\x99",
        .menu_water =>
            "Zapisz wod\xC4\x99",
        .menu_stats =>
            "Podsumowanie dnia",
        .menu_meals =>
            "Lista posi\xC5\x82k\xC3\xB3w",
        .menu_history =>
            "Historia wagi",
        .menu_goal =>
            "Ustaw cel kcal/bia\xC5\x82ko",
        .menu_injection =>
            "Zapisz zastrzyk Mounjaro",
        .menu_undo =>
            "Usu\xC5\x84 ostatni posi\xC5\x82ek",

        // --- meal ---
        .meal_summary =>
            "\xE2\x9C\x85 {s}\n"
                ++ "{d} kcal"
                ++ " | B:{d:.0}g W:{d:.0}g T:{d:.0}g\n"
                ++ "B\xC5\x82onnik: {d:.0}g"
                ++ " | G\xC4\x99sto\xC5\x9B\xC4\x87"
                ++ " bia\xC5\x82ka: {d:.2}\n"
                ++ "Puryny: {s} ({d:.0}mg)"
                ++ " pewno\xC5\x9B\xC4\x87: {s}\n"
                ++ "Woda: {d}ml\n"
                ++ "{s}{s}",
        .meal_summary_basic =>
            "\xE2\x9C\x85 {s}\n"
                ++ "{d} kcal"
                ++ " | B:{d:.0}g W:{d:.0}g T:{d:.0}g\n"
                ++ "B\xC5\x82onnik: {d:.0}g"
                ++ " | G\xC4\x99sto\xC5\x9B\xC4\x87"
                ++ " bia\xC5\x82ka: {d:.2}\n"
                ++ "Woda: {d}ml",
        .meal_date_note =>
            "\xF0\x9F\x93\x85 Zapisano na {s}\n",
        .gout_warning_line =>
            "\xE2\x9A\xA0\xEF\xB8\x8F"
                ++ " OSTRZEZENIE DNAWE\n",
        .meal_saved_fallback =>
            "Posi\xC5\x82ek zapisany.",

        // --- stats ---
        .stats_template =>
            "\xE2\x96\x88 MetOS [v0.1]"
                ++ " \xE2\x80\x94 {s}"
                ++ "\n\n[METABOLIC LOAD]"
                ++ "\n{d}\xC3\x97 | {d} kcal"
                ++ "\nB:{d:.0}g W:{d:.0}g"
                ++ " T:{d:.0}g B\xC5\x82:{d:.0}g"
                ++ "\nPuryny: {s}"
                ++ "{s}"
                ++ "\n\n[SYSTEM STATUS]"
                ++ "\n\xF0\x9F\x92\xA7 {d} ml"
                ++ "\n{s}"
                ++ "\n\n\xCE\x9A\xCE\xB1\xCF\x84\xCE\xAC"
                ++ " \xCE\x9C\xCE\xAD\xCE\xB8\xCE\xBF"
                ++ "\xCE\xB4\xCE\xBF\xCE\xBD",
        .stats_pharma =>
            "\n[PHARMA STATUS]"
                ++ "\nMounjaro"
                ++ " | dz. {d}"
                ++ " | t\xC5\x82um. {d:.0}%",
        .stats_gout_alert =>
            "\xE2\x9A\xA0\xEF\xB8\x8F ALERT DNOWY",
        .stats_fallback =>
            "MetOS: raport"
                ++ " niedost\xC4\x99pny.",
        .stats_no_data =>
            "Brak danych na ten dzie\xC5\x84.",

        // --- meals/history ---
        .meals_header =>
            "\xF0\x9F\x8D\xBD"
                ++ " Posi\xC5\x82ki na {s}:\n{s}",
        .no_meals =>
            "Brak posi\xC5\x82k\xC3\xB3w na ten"
                ++ " dzie\xC5\x84.",
        .history_header =>
            "\xF0\x9F\x93\x88 Ostatnie"
                ++ " wa\xC5\xBCenia:\n{s}",
        .no_weigh_ins =>
            "Brak zapis\xC3\xB3w"
                ++ " wa\xC5\xBCenia.",

        // --- goal display ---
        .goal_show =>
            "\xF0\x9F\x8E\xAF Aktualny cel:\n"
                ++ "Kalorie: {d} kcal\n"
                ++ "Bia\xC5\x82ko: {d:.0}g",
        .goal_show_fallback =>
            "Cel ustawiony.",
        .no_goal =>
            "Brak celu. U\xC5\xBCycie:"
                ++ " /goal 2000 150",

        // --- voice ---
        .voice_transcribing =>
            "\xF0\x9F\x8E\x99"
                ++ " Transkrybuj\xC4\x99...",
        .voice_transcript_prefix =>
            "\xF0\x9F\x8E\x99"
                ++ " Transkrypcja:\n\n{s}",
        .voice_edit_prompt =>
            "\xE2\x9C\x8F\xEF\xB8\x8F"
                ++ " Wy\xC5\x9Blij"
                ++ " poprawiony tekst:",
        .no_pending_transcript =>
            "Brak oczekuj\xC4\x85cej"
                ++ " transkrypcji.",
        .no_pending_command =>
            "Brak oczekuj\xC4\x85cej"
                ++ " komendy.",
        .cancelled => "Anulowano.",

        // --- buttons ---
        .btn_yes => "\xE2\x9C\x85 Tak",
        .btn_no => "\xE2\x9D\x8C Nie",
        .btn_approve =>
            "\xE2\x9C\x85"
                ++ " Zatwierd\xC5\xBA",
        .btn_edit =>
            "\xE2\x9C\x8F\xEF\xB8\x8F"
                ++ " Edytuj",

        // --- alerts ---
        .alert_stomach_load =>
            "\xE2\x9A\xA0\xEF\xB8\x8F"
                ++ " Ci\xC4\x99\xC5\xBCki"
                ++ " posi\xC5\x82ek po 20:00!"
                ++ "\n{d} kcal, {d:.0}g"
                ++ " t\xC5\x82uszczu."
                ++ " Mounjaro spowalnia"
                ++ " opr\xC3\xB3\xC5\xBCnianie"
                ++ " \xC5\xBCo\xC5\x82\xC4\x85"
                ++ "dka"
                ++ " \xE2\x80\x94"
                ++ " ryzyko refluksu!",
        .alert_purine_72h =>
            "\xF0\x9F\x92\x80"
                ++ " Bufor purynowy 72h"
                ++ " przekroczony!"
                ++ "\n{d} z 3 dni"
                ++ " z wysokimi purynami."
                ++ "\nDzi\xC5\x9B tylko"
                ++ " nabia\xC5\x82/WPI"
                ++ " \xE2\x80\x94 zero"
                ++ " mi\xC4\x99sa!"
                ++ "\nKwas moczowy kumuluje"
                ++ " si\xC4\x99 \xE2\x80\x94"
                ++ " daj stawom oddech.",
        .alert_anti_catabolic =>
            "\xE2\x9A\xA0\xEF\xB8\x8F"
                ++ " Zbyt szybki"
                ++ " spadek wagi!"
                ++ "\nTygodniowa zmiana:"
                ++ " {d:.1}%"
                ++ "\nTak stromy spadek pali"
                ++ " mi\xC4\x99\xC5\x9Bnie,"
                ++ " nie t\xC5\x82uszcz."
                ++ "\nDodaj +150-200 kcal,"
                ++ " \xC5\xBCeby chroni\xC4\x87"
                ++ " tkank\xC4\x99"
                ++ " mi\xC4\x99\xC5\x9Bniow"
                ++ "\xC4\x85.",
        .alert_force_feed =>
            "\xF0\x9F\xA5\xA4 Force Feed!"
                ++ " Szczyt t\xC5\x82umienia"
                ++ " ({d:.0}%)."
                ++ "\nBrak g\xC5\x82odu"
                ++ " nie znaczy,"
                ++ " \xC5\xBCe cia\xC5\x82o"
                ++ " nie potrzebuje budulca."
                ++ "\nWypij szejka WPI/Skyr!",
        .alert_purine_sentry =>
            "\xF0\x9F\x94\x94 Purine Sentry!"
                ++ " T\xC5\x82umienie spad\xC5\x82o"
                ++ " do {d:.0}%."
                ++ "\nPowracaj\xC4\x85cy apetyt"
                ++ " = ryzyko z\xC5\x82amania"
                ++ " bufora purynowego."
                ++ "\nTrzymaj si\xC4\x99"
                ++ " nabia\xC5\x82u i WPI!",
        .alert_injection_due =>
            "\xF0\x9F\x92\x89"
                ++ " Czas na zastrzyk"
                ++ " Mounjaro!"
                ++ "\nOstatni: {d} dni temu."
                ++ "\nApetyt wraca"
                ++ " \xE2\x80\x94 nie czekaj.",
        .alert_injection_phase_early =>
            "\xF0\x9F\x92\x89 Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nFaza wch\xC5\x82aniania."
                ++ " Mo\xC5\xBCliwe"
                ++ " nudno\xC5\x9Bci"
                ++ " i zmniejszony apetyt."
                ++ "\nJedz ma\xC5\x82o,"
                ++ " ale regularnie.",
        .alert_injection_phase_peak =>
            "\xF0\x9F\x8E\xAF Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nSzczyt t\xC5\x82umienia"
                ++ " apetytu."
                ++ "\nKorzystaj z okna"
                ++ " \xE2\x80\x94 to najlepszy"
                ++ " czas na"
                ++ " redukcj\xC4\x99.",
        .alert_injection_phase_late =>
            "\xF0\x9F\x93\x88 Dzie\xC5\x84 {d}"
                ++ " po zastrzyku."
                ++ "\nApetyt wraca."
                ++ " Uwa\xC5\xBCaj na impulsy!"
                ++ "\nTrzymaj si\xC4\x99"
                ++ " planu makro.",

        // --- onboarding ---
        .onboard_welcome =>
            "\xE2\x96\x88 MetOS \xE2\x80\x94"
                ++ " Metabolic Operating System"
                ++ "\n\nSkonfigurujmy Tw\xC3\xB3j"
                ++ " profil.",
        .onboard_ask_locale =>
            "\xF0\x9F\x8C\x90"
                ++ " Wybierz j\xC4\x99zyk:",
        .onboard_ask_gout =>
            "Czy chcesz \xC5\x9Bledzi\xC4\x87"
                ++ " puryny/dn\xC4\x99 moczanow\xC4\x85?"
                ++ "\n(Monitoruje ryzyko kwasu"
                ++ " moczowego z jedzenia)",
        .onboard_ask_glp1 =>
            "Czy przyjmujesz agonist\xC4\x99"
                ++ " GLP-1"
                ++ " (Mounjaro/Ozempic/Wegovy)?"
                ++ "\n(W\xC5\x82\xC4\x85cza"
                ++ " \xC5\x9Bledzenie zastrzyk\xC3\xB3w"
                ++ " i farmakokinetyk\xC4\x99)",
        .onboard_done =>
            "\xE2\x9C\x85 Konfiguracja zako\xC5\x84czona!"
                ++ " Wy\xC5\x9Blij opis posi\xC5\x82ku"
                ++ " lub wpisz /help.",

        // --- settings ---
        .settings_current =>
            "\xE2\x9A\x99\xEF\xB8\x8F Ustawienia:"
                ++ "\nJ\xC4\x99zyk: {s}"
                ++ "\n\xC5\x9Aledzenie dny: {s}"
                ++ "\n\xC5\x9Aledzenie GLP-1: {s}"
                ++ "\n\nU\xC5\xBCyj /start"
                ++ " aby zmieni\xC4\x87.",
        .settings_updated =>
            "\xE2\x9C\x85 Ustawienia zapisane.",

        // --- feature disabled ---
        .feature_injection_disabled =>
            "\xC5\x9Aledzenie zastrzyk\xC3\xB3w"
                ++ " wy\xC5\x82\xC4\x85czone."
                ++ " U\xC5\xBCyj /start aby"
                ++ " w\xC5\x82\xC4\x85czy\xC4\x87"
                ++ " GLP-1.",
    };
}
