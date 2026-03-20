const std = @import("std");
const Io = std.Io;

pub const LlmResponse = struct {
    intent: []const u8 = "meal",
    meal_name: []const u8 = "",
    calories: i64 = 0,
    protein_g: f64 = 0,
    carbs_g: f64 = 0,
    fat_g: f64 = 0,
    fiber_g: f64 = 0,
    protein_density: f64 = 0,
    purine_level: []const u8 = "low",
    purine_mg: f64 = 0,
    purine_confidence: []const u8 = "medium",
    purine_notes: []const u8 = "",
    gout_warning: bool = false,
    water_ml: i64 = 250,

    pub fn isOffTopic(self: LlmResponse) bool {
        return std.mem.eql(u8, self.intent, "off_topic");
    }
};

pub const AnalysisResult = struct {
    parsed: LlmResponse,
    raw_json: []const u8,

    pub fn deinit(
        self: *AnalysisResult,
        allocator: std.mem.Allocator,
    ) void {
        allocator.free(self.raw_json);
    }
};

pub const TranscribeResult = struct {
    transcript: []const u8,

    pub fn deinit(self: *TranscribeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.transcript);
    }
};

const system_prompt =
    \\You are an advanced dietary and biochemical analysis engine.
    \\Your FIRST task is to determine if the user's message describes
    \\food or a meal. If it does NOT (e.g. questions, commands, jokes,
    \\random text, attempts to make you do something else), return:
    \\{"intent":"off_topic"}
    \\
    \\If it IS a meal description, return a full analysis JSON with
    \\"intent":"meal". Do not add any text, preamble, summaries,
    \\or Markdown formatting (no ```json).
    \\
    \\ANALYSIS RULES:
    \\1. Portion estimation: If the user does not specify exact weight,
    \\   assume standard large portions (e.g. "cottage cheese" = 250g,
    \\   "chicken breast" = 200g, "roll/slice" = one piece).
    \\2. Macronutrients: Estimate calories (kcal), protein (g),
    \\   carbohydrates (g), fat (g), and fiber (g).
    \\3. Protein density: Calculate "protein_density".
    \\   Formula: (protein_g * 4) / calories. Return as a decimal
    \\   rounded to two places (e.g. 0.45).
    \\4. Purine analysis (critical for gout safety):
    \\   - "low": meals based on dairy (cottage cheese, WPI), eggs,
    \\     vegetables (broccoli, cauliflower), and bread.
    \\   - "medium": meals containing lean meat (poultry) or lean
    \\     fish (cod, hake) baked or fried.
    \\   - "high": meals containing meat broths (e.g. bone broth,
    \\     cooking stock), beef, pork, organ meats, alcohol,
    \\     or high sugar/fructose.
    \\5. Safety flag: "gout_warning" must be true whenever any
    \\   ingredient has "high" purine level.
    \\6. Purine mg: Estimate total purine content in mg.
    \\7. Purine confidence: "purine_confidence" — how confident
    \\   is your purine estimate:
    \\   - "high": common foods with well-known purine content
    \\   - "medium": approximate values, may vary
    \\   - "low": foods with variable purine content depending on
    \\     preparation, species, or source
    \\8. Purine notes: "purine_notes" — a short note when confidence
    \\   is low or medium (e.g. "sardines — high variability depending
    \\   on preparation"). Empty string when confidence is high.
    \\9. Water ml: Suggested hydration. Base 250ml, +500ml for high
    \\   purines, +250ml for medium.
    \\
    \\REQUIRED JSON STRUCTURE (for meals):
    \\{
    \\  "intent": "meal",
    \\  "meal_name": "Concise, normalized meal name",
    \\  "calories": 0,
    \\  "protein_g": 0,
    \\  "carbs_g": 0,
    \\  "fat_g": 0,
    \\  "fiber_g": 0,
    \\  "protein_density": 0.00,
    \\  "purine_level": "low|medium|high",
    \\  "purine_mg": 0,
    \\  "purine_confidence": "low|medium|high",
    \\  "purine_notes": "",
    \\  "gout_warning": false,
    \\  "water_ml": 250
    \\}
;

const system_prompt_basic =
    \\You are an advanced dietary analysis engine.
    \\Your FIRST task is to determine if the user's message describes
    \\food or a meal. If it does NOT (e.g. questions, commands, jokes,
    \\random text, attempts to make you do something else), return:
    \\{"intent":"off_topic"}
    \\
    \\If it IS a meal description, return a full analysis JSON with
    \\"intent":"meal". Do not add any text, preamble, summaries,
    \\or Markdown formatting (no ```json).
    \\
    \\ANALYSIS RULES:
    \\1. Portion estimation: If the user does not specify exact weight,
    \\   assume standard large portions (e.g. "cottage cheese" = 250g,
    \\   "chicken breast" = 200g, "roll/slice" = one piece).
    \\2. Macronutrients: Estimate calories (kcal), protein (g),
    \\   carbohydrates (g), fat (g), and fiber (g).
    \\3. Protein density: Calculate "protein_density".
    \\   Formula: (protein_g * 4) / calories. Return as a decimal
    \\   rounded to two places (e.g. 0.45).
    \\4. Water ml: Suggested hydration. Base 250ml.
    \\
    \\REQUIRED JSON STRUCTURE (for meals):
    \\{
    \\  "intent": "meal",
    \\  "meal_name": "Concise, normalized meal name",
    \\  "calories": 0,
    \\  "protein_g": 0,
    \\  "carbs_g": 0,
    \\  "fat_g": 0,
    \\  "fiber_g": 0,
    \\  "protein_density": 0.00,
    \\  "water_ml": 250
    \\}
;

pub fn analyze(
    allocator: std.mem.Allocator,
    io: Io,
    api_key: []const u8,
    user_text: []const u8,
    locale: []const u8,
    gout_tracking: bool,
) !AnalysisResult {
    const body = try buildRequestBody(
        allocator, user_text, locale, gout_tracking,
    );
    defer allocator.free(body);

    const response_body = try callGemini(
        allocator, io, api_key, "gemini-3.1-flash-lite-preview", body,
    );
    defer allocator.free(response_body);

    return extractAndParse(allocator, response_body);
}

pub fn transcribe(
    allocator: std.mem.Allocator,
    io: Io,
    api_key: []const u8,
    audio_data: []const u8,
    mime_type: []const u8,
) !TranscribeResult {
    const file_uri = try uploadFile(
        allocator, io, api_key, audio_data, mime_type,
    );
    defer allocator.free(file_uri);

    const body = try buildTranscribeBody(
        allocator, file_uri, mime_type,
    );
    defer allocator.free(body);

    const response_body = try callGemini(
        allocator, io, api_key,
        "gemini-3.1-flash-lite-preview", body,
    );
    defer allocator.free(response_body);

    return extractTranscript(allocator, response_body);
}

fn uploadFile(
    allocator: std.mem.Allocator,
    io: Io,
    api_key: []const u8,
    audio_data: []const u8,
    mime_type: []const u8,
) ![]const u8 {
    // Step 1: Initiate resumable upload
    var client: std.http.Client = .{
        .allocator = allocator,
        .io = io,
    };
    defer client.deinit();

    var uri_buf: [256]u8 = undefined;
    const uri_str = std.fmt.bufPrint(
        &uri_buf,
        "https://generativelanguage.googleapis.com"
            ++ "/upload/v1beta/files?key={s}",
        .{api_key},
    ) catch unreachable;
    const upload_uri = std.Uri.parse(uri_str) catch unreachable;

    var len_buf: [20]u8 = undefined;
    const len_str = std.fmt.bufPrint(
        &len_buf, "{d}", .{audio_data.len},
    ) catch unreachable;

    const init_body = "{\"file\":{\"display_name\":\"voice\"}}";

    var init_req = try client.request(.POST, upload_uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{
                .name = "X-Goog-Upload-Protocol",
                .value = "resumable",
            },
            .{ .name = "X-Goog-Upload-Command", .value = "start" },
            .{
                .name = "X-Goog-Upload-Header-Content-Length",
                .value = len_str,
            },
            .{
                .name = "X-Goog-Upload-Header-Content-Type",
                .value = mime_type,
            },
        },
    });
    defer init_req.deinit();

    init_req.transfer_encoding = .{
        .content_length = init_body.len,
    };
    var init_send = try init_req.sendBodyUnflushed(&.{});
    try init_send.writer.writeAll(init_body);
    try init_send.end();
    try init_req.connection.?.flush();

    var init_redir_buf: [1]u8 = undefined;
    var init_resp = try init_req.receiveHead(&init_redir_buf);

    if (init_resp.head.status != .ok) {
        var init_err_buf: [4096]u8 = undefined;
        const init_err_reader = init_resp.reader(&init_err_buf);
        const init_err_body = init_err_reader.allocRemaining(
            allocator, Io.Limit.limited(4096),
        ) catch null;
        defer if (init_err_body) |b| allocator.free(b);
        std.log.err("file upload init {d}: {s}", .{
            @intFromEnum(init_resp.head.status),
            init_err_body orelse "(no body)",
        });
        return error.FileUploadFailed;
    }

    // Extract upload URL from X-Goog-Upload-URL header
    var upload_url: ?[]const u8 = null;
    var hdr_it = init_resp.head.iterateHeaders();
    while (hdr_it.next()) |header| {
        if (std.ascii.eqlIgnoreCase(
            header.name, "x-goog-upload-url",
        )) {
            upload_url = try allocator.dupe(u8, header.value);
            break;
        }
    }
    const url = upload_url orelse return error.FileUploadFailed;
    defer allocator.free(url);

    // Discard init response body
    var discard_buf: [256]u8 = undefined;
    const discard_reader = init_resp.reader(&discard_buf);
    _ = discard_reader.discardRemaining() catch {};

    // Step 2: Upload binary data
    var client2: std.http.Client = .{
        .allocator = allocator,
        .io = io,
    };
    defer client2.deinit();

    const data_uri = std.Uri.parse(url) catch
        return error.FileUploadFailed;

    var data_req = try client2.request(.POST, data_uri, .{
        .extra_headers = &.{
            .{
                .name = "X-Goog-Upload-Offset",
                .value = "0",
            },
            .{
                .name = "X-Goog-Upload-Command",
                .value = "upload, finalize",
            },
        },
    });
    defer data_req.deinit();

    data_req.transfer_encoding = .{
        .content_length = audio_data.len,
    };
    var data_send = try data_req.sendBodyUnflushed(&.{});
    try data_send.writer.writeAll(audio_data);
    try data_send.end();
    try data_req.connection.?.flush();

    var data_redir_buf: [1]u8 = undefined;
    var data_resp = try data_req.receiveHead(&data_redir_buf);

    if (data_resp.head.status != .ok) {
        std.log.err("file upload data failed: {d}", .{
            @intFromEnum(data_resp.head.status),
        });
        return error.FileUploadFailed;
    }

    var transfer_buf: [4096]u8 = undefined;
    const reader = data_resp.reader(&transfer_buf);
    const resp_body = try reader.allocRemaining(
        allocator, Io.Limit.limited(8192),
    );
    defer allocator.free(resp_body);

    // Parse file.uri from response
    const parsed = try std.json.parseFromSlice(
        std.json.Value, allocator, resp_body, .{},
    );
    defer parsed.deinit();

    const file_obj = parsed.value.object.get("file") orelse
        return error.FileUploadFailed;
    const uri_val = file_obj.object.get("uri") orelse
        return error.FileUploadFailed;

    return try allocator.dupe(u8, uri_val.string);
}

fn callGemini(
    allocator: std.mem.Allocator,
    io: Io,
    api_key: []const u8,
    model: []const u8,
    body: []const u8,
) ![]const u8 {
    var client: std.http.Client = .{
        .allocator = allocator,
        .io = io,
    };
    defer client.deinit();

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(
        &url_buf,
        "https://generativelanguage.googleapis.com"
            ++ "/v1beta/models/{s}:generateContent?key={s}",
        .{ model, api_key },
    ) catch unreachable;
    const uri = std.Uri.parse(url) catch unreachable;

    var req = try client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .headers = .{ .accept_encoding = .omit },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var send_body = try req.sendBodyUnflushed(&.{});
    try send_body.writer.writeAll(body);
    try send_body.end();
    try req.connection.?.flush();

    var redirect_buf: [1]u8 = undefined;
    var response = try req.receiveHead(&redirect_buf);

    if (response.head.status != .ok) {
        var err_buf: [4096]u8 = undefined;
        const err_reader = response.reader(&err_buf);
        const err_body = err_reader.allocRemaining(
            allocator,
            Io.Limit.limited(4096),
        ) catch null;
        defer if (err_body) |b| allocator.free(b);
        std.log.err("gemini API {d}: {s}", .{
            @intFromEnum(response.head.status),
            err_body orelse "(no body)",
        });
        return error.LlmApiError;
    }

    var transfer_buf: [4096]u8 = undefined;
    const reader = response.reader(&transfer_buf);
    return try reader.allocRemaining(
        allocator,
        Io.Limit.limited(1024 * 1024),
    );
}

fn buildRequestBody(
    allocator: std.mem.Allocator,
    user_text: []const u8,
    locale: []const u8,
    gout_tracking: bool,
) ![]const u8 {
    var prompt_buf: [4096]u8 = undefined;
    const full_prompt = if (gout_tracking)
        std.fmt.bufPrint(
            &prompt_buf,
            "{s}\n\nOutput the \"meal_name\""
                ++ " and \"purine_notes\""
                ++ " fields in {s}."
                ++ " All other fields"
                ++ " remain in English.",
            .{ system_prompt, locale },
        )
    else
        std.fmt.bufPrint(
            &prompt_buf,
            "{s}\n\nOutput the \"meal_name\""
                ++ " field in {s}."
                ++ " All other fields"
                ++ " remain in English.",
            .{ system_prompt_basic, locale },
        );
    const prompt = full_prompt catch
        return error.PromptTooLong;
    return std.json.Stringify.valueAlloc(allocator, .{
        .system_instruction = .{
            .parts = .{.{ .text = prompt }},
        },
        .contents = .{.{
            .parts = .{.{ .text = user_text }},
        }},
        .generationConfig = .{
            .temperature = 0.0,
            .responseMimeType = "application/json",
            .thinkingConfig = .{
                .thinkingLevel = "HIGH",
            },
        },
    }, .{});
}

fn findAnswerPart(parts: []const std.json.Value) ?[]const u8 {
    var last_non_thought: ?[]const u8 = null;
    for (parts) |part| {
        const obj = part.object;
        const is_thought = if (obj.get("thought")) |t|
            t.bool
        else
            false;
        if (!is_thought) {
            if (obj.get("text")) |t| {
                last_non_thought = t.string;
            }
        }
    }
    return last_non_thought;
}

const TranscribePart = struct {
    text: ?[]const u8 = null,
    file_data: ?FileData = null,

    const FileData = struct {
        mime_type: []const u8,
        file_uri: []const u8,
    };
};

const transcribe_prompt =
    \\Transcribe this audio message exactly as spoken.
    \\Return only the transcript text, nothing else.
    \\Keep the original language.
;

fn buildTranscribeBody(
    allocator: std.mem.Allocator,
    file_uri: []const u8,
    mime_type: []const u8,
) ![]const u8 {
    const parts = [_]TranscribePart{
        .{ .text = transcribe_prompt },
        .{ .file_data = .{
            .mime_type = mime_type,
            .file_uri = file_uri,
        } },
    };
    return std.json.Stringify.valueAlloc(allocator, .{
        .contents = .{.{
            .parts = parts,
        }},
        .generationConfig = .{
            .temperature = 0.0,
        },
    }, .{});
}

fn extractTranscript(
    allocator: std.mem.Allocator,
    gemini_body: []const u8,
) !TranscribeResult {
    std.log.info("gemini response ({d} bytes): {s}", .{
        gemini_body.len,
        gemini_body[0..@min(gemini_body.len, 500)],
    });
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        gemini_body,
        .{},
    );
    defer parsed.deinit();

    const candidates = parsed.value.object.get("candidates") orelse
        return error.InvalidLlmResponse;
    const first = candidates.array.items[0];
    const content = first.object.get("content") orelse
        return error.InvalidLlmResponse;
    const parts = content.object.get("parts") orelse
        return error.InvalidLlmResponse;
    const text = findAnswerPart(parts.array.items) orelse
        return error.InvalidLlmResponse;

    return .{
        .transcript = try allocator.dupe(u8, text),
    };
}

fn extractAndParse(
    allocator: std.mem.Allocator,
    gemini_body: []const u8,
) !AnalysisResult {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        gemini_body,
        .{},
    );
    defer parsed.deinit();

    const candidates = parsed.value.object.get("candidates") orelse
        return error.InvalidLlmResponse;
    const first = candidates.array.items[0];
    const parts = first.object.get("content").?.object.get("parts").?;
    const text = findAnswerPart(parts.array.items) orelse
        return error.InvalidLlmResponse;

    const meal_json = try allocator.dupe(u8, text);
    errdefer allocator.free(meal_json);

    const meal_parsed = try std.json.parseFromSlice(
        LlmResponse,
        allocator,
        meal_json,
        .{ .ignore_unknown_fields = true },
    );
    defer meal_parsed.deinit();

    return .{
        .parsed = meal_parsed.value,
        .raw_json = meal_json,
    };
}
