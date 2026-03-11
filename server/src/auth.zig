const std = @import("std");
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const base64url = std.base64.url_safe_no_pad;

pub const Auth = struct {
    signing_key: [32]u8,
    password: []const u8,

    const header_b64 = blk: {
        const header_json = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
        var buf: [base64url.Encoder.calcSize(header_json.len)]u8 =
            undefined;
        _ = base64url.Encoder.encode(&buf, header_json);
        break :blk buf;
    };

    const Payload = struct {
        iat: i64,
        exp: i64,
    };

    pub fn init(io: std.Io, password: []const u8) Auth {
        var key: [32]u8 = undefined;
        io.random(&key);
        return .{
            .signing_key = key,
            .password = password,
        };
    }

    pub fn checkPassword(self: *const Auth, attempt: []const u8) bool {
        return std.mem.eql(u8, attempt, self.password);
    }

    pub fn createToken(
        self: *const Auth,
        allocator: std.mem.Allocator,
        now: i64,
    ) ![]u8 {
        const exp = now + 86400;

        var payload_json_buf: [128]u8 = undefined;
        const payload_json = std.fmt.bufPrint(
            &payload_json_buf,
            "{{\"iat\":{d},\"exp\":{d}}}",
            .{ now, exp },
        ) catch unreachable;

        const payload_b64_len = base64url.Encoder.calcSize(
            payload_json.len,
        );
        const payload_b64 = try allocator.alloc(u8, payload_b64_len);
        defer allocator.free(payload_b64);
        _ = base64url.Encoder.encode(payload_b64, payload_json);

        const signing_input = try std.fmt.allocPrint(
            allocator,
            "{s}.{s}",
            .{ header_b64, payload_b64 },
        );
        defer allocator.free(signing_input);

        var mac: [HmacSha256.mac_length]u8 = undefined;
        HmacSha256.create(&mac, signing_input, &self.signing_key);

        var sig_b64: [base64url.Encoder.calcSize(
            HmacSha256.mac_length,
        )]u8 = undefined;
        _ = base64url.Encoder.encode(&sig_b64, &mac);

        return std.fmt.allocPrint(
            allocator,
            "{s}.{s}.{s}",
            .{ header_b64, payload_b64, sig_b64 },
        );
    }

    pub fn validateToken(
        self: *const Auth,
        token: []const u8,
        now: i64,
    ) bool {
        const dot1 = std.mem.indexOf(u8, token, ".") orelse
            return false;
        const rest = token[dot1 + 1 ..];
        const dot2 = std.mem.indexOf(u8, rest, ".") orelse
            return false;

        const header_payload = token[0 .. dot1 + 1 + dot2];
        const sig_b64 = rest[dot2 + 1 ..];
        const payload_b64 = token[dot1 + 1 ..][0..dot2];

        const sig_len = base64url.Decoder.calcSizeForSlice(
            sig_b64,
        ) catch return false;
        if (sig_len != HmacSha256.mac_length) return false;
        var received_sig: [HmacSha256.mac_length]u8 = undefined;
        base64url.Decoder.decode(
            &received_sig,
            sig_b64,
        ) catch return false;

        var expected_sig: [HmacSha256.mac_length]u8 = undefined;
        HmacSha256.create(
            &expected_sig,
            header_payload,
            &self.signing_key,
        );

        if (!std.crypto.timing_safe.eql(
            [HmacSha256.mac_length]u8,
            received_sig,
            expected_sig,
        )) return false;

        const payload_len = base64url.Decoder.calcSizeForSlice(
            payload_b64,
        ) catch return false;
        if (payload_len > 512) return false;
        var payload_buf: [512]u8 = undefined;
        base64url.Decoder.decode(
            payload_buf[0..payload_len],
            payload_b64,
        ) catch return false;

        const parsed = std.json.parseFromSlice(
            Payload,
            std.heap.page_allocator,
            payload_buf[0..payload_len],
            .{ .ignore_unknown_fields = true },
        ) catch return false;
        defer parsed.deinit();

        return parsed.value.exp > now;
    }
};
