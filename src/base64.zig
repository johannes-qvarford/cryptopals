const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;

const hex = @import("./hex.zig");

fn bytes_to_base64(allocator: std.mem.Allocator, bytes: []const u8) !ArrayList(u8) {
    const S = struct {
        fn sextet_to_ascii(sextet: u6) u7 {
            const x: u7 = switch (sextet) {
                0...25 => 'A' + @as(u7, sextet),
                26...51 => 'a' + (@as(u7, sextet) - 26),
                52...61 => '0' + (@as(u7, sextet) - 52),
                62 => '+',
                63 => '/',
            };
            return x;
        }
    };

    var bit: u32 = 0;
    var buffer = ArrayList(u8).init(allocator);
    errdefer {
        buffer.deinit();
    }

    while (bit < bytes.len * 8) {
        const byte = bit / 8;

        const high = bytes[byte];
        const low = switch (byte == bytes.len - 1) {
            false => bytes[byte + 1],
            true => 0,
        };

        const sextet: u6 = switch (bit % 8) {
            0 => @intCast(high >> 2),
            6 => blk: {
                const high_2 = (high << 4) & 0b00_11_00_00;
                const low_4 = (low >> 4);
                break :blk @intCast(high_2 | low_4);
            },
            4 => blk: {
                const high_4 = (high << 2) & 0b00_11_11_00;
                const low_2 = (low >> 6);
                break :blk @intCast(high_4 | low_2);
            },
            2 => @intCast(high & 0b00_11_11_11),
            else => return unreachable(),
        };

        try buffer.append(S.sextet_to_ascii(sextet));

        bit += 6;
    }
    // TODO: Padding
    return buffer;
}

test "bytes_to_base64 converts to base64" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(expected: []const u8, bytes: []const u8) !void {
            const a = try bytes_to_base64(allocator, bytes);
            defer {
                a.deinit();
            }
            const p = a.items;
            try std.testing.expectEqualSlices(u8, expected, p);
        }
    };

    try S.t("AA", &[1]u8{0x00});
    try S.t("BA", &[1]u8{0x04});
    try S.t("AAAA", &[3]u8{ 0x00, 0x00, 0x00 });
    try S.t("BAAA", &[3]u8{ 0x04, 0x00, 0x00 });
    try S.t("CAAA", &[3]u8{ 0x08, 0x00, 0x00 });
    try S.t("aAAA", &[3]u8{ 0x68, 0x00, 0x00 });
    try S.t("zAAA", &[3]u8{ 0xcc, 0x00, 0x00 });
    try S.t("0AAA", &[3]u8{ 0xd0, 0x00, 0x00 });
    try S.t("9AAA", &[3]u8{ 0xf4, 0x00, 0x00 });
    try S.t("+AAA", &[3]u8{ 0xf8, 0x00, 0x00 });
    try S.t("/AAA", &[3]u8{ 0xfc, 0x00, 0x00 });
    try S.t("/AAA", &[3]u8{ 0xfc, 0x00, 0x00 });
    try S.t("TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu", "Many hands make light work.");
}

pub fn hex_ascii_to_base64(allocator: std.mem.Allocator, hex_ascii: []const u8) !ArrayList(u8) {
    const bytes = try hex.hex_to_bytes(allocator, hex_ascii);
    defer {
        allocator.free(bytes);
    }
    const base64 = try bytes_to_base64(allocator, bytes);
    return base64;
}

test "hex_ascii_to_base64 converts to base64" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(expected: []const u8, hex_ascii: []const u8) !void {
            const a = try hex_ascii_to_base64(allocator, hex_ascii);
            defer {
                a.deinit();
            }
            const p = a.items;
            try std.testing.expectEqualSlices(u8, expected, p);
        }
    };

    try S.t("SSdtIGtpbGxpbmcgeW91ciBicmFpbiBsaWtlIGEgcG9pc29ub3VzIG11c2hyb29t", "49276d206b696c6c696e6720796f757220627261696e206c696b65206120706f69736f6e6f7573206d757368726f6f6d");
}
