const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;

const ConversionError = error{CharIsNotNib};

fn hex_char_to_nib(char: u8) anyerror!u8 {
    return try switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => (char - 'a') + ((9 - 0) + 1),
        'A'...'F' => (char - 'A') + ((9 - 0) + 1),
        else => blk: {
            std.log.warn("\nIncorrect char {X}\n", .{char});
            break :blk error.ConversionError;
        },
    };
}

test "hex_char_to_nib converts to correct nib" {
    try std.testing.expectEqual(hex_char_to_nib('0'), 0);
    try std.testing.expectEqual(hex_char_to_nib('9'), 9);
    try std.testing.expectEqual(hex_char_to_nib('a'), 0xa);
    try std.testing.expectEqual(hex_char_to_nib('f'), 0xf);
    try std.testing.expectEqual(hex_char_to_nib('A'), 0xA);
    try std.testing.expectEqual(hex_char_to_nib('F'), 0xF);
    try std.testing.expectEqual(hex_char_to_nib('g'), error.ConversionError);
}

fn hex_pairs_to_bytes(allocator: std.mem.Allocator, pairs: []const u8) ![]const u8 {
    _ = try std.math.divExact(usize, pairs.len, 2);

    const bytes = try allocator.alloc(u8, pairs.len / 2);
    errdefer {
        allocator.free(bytes);
    }

    for (0..bytes.len) |i| {
        const first_i: u8 = @intCast(i * 2);
        const second_i = first_i + 1;

        //std.log.warn("\nIncorrect char {X} and {X} for i={}\n", .{ first_char, second_char, i });

        const high_char = pairs[first_i];
        const low_char = pairs[second_i];

        const high_nib = try hex_char_to_nib(high_char);
        const low_nib = try hex_char_to_nib(low_char);

        bytes[i] = (high_nib << 4) + low_nib;
    }

    return bytes;
}

test "hex_pairs_to_bytes converts to correct nib" {
    const S = struct {
        fn test_hex_pairs_to_bytes(allocator: std.mem.Allocator, expected: []const u8, pairs: []const u8) !void {
            const a = try hex_pairs_to_bytes(allocator, pairs);
            defer {
                allocator.free(a);
            }
            try std.testing.expectEqualSlices(u8, expected, a);
        }
    };

    const allocator = std.testing.allocator;

    try S.test_hex_pairs_to_bytes(allocator, &([1]u8{0x0}), "00"[0..]);
    try S.test_hex_pairs_to_bytes(allocator, &([1]u8{0x82}), "82"[0..]);
    try S.test_hex_pairs_to_bytes(allocator, &([1]u8{0xFF}), "FF"[0..]);
    try S.test_hex_pairs_to_bytes(allocator, &([3]u8{ 0x77, 0x12, 0x34 }), "771234"[0..]);
}

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
        fn test_bytes_to_base64(allocator: std.mem.Allocator, expected: []const u8, bytes: []const u8) !void {
            const a = try bytes_to_base64(allocator, bytes);
            defer {
                a.deinit();
            }
            const p = a.items;
            try std.testing.expectEqualSlices(u8, expected, p);
        }
    };

    const allocator = std.testing.allocator;

    try S.test_bytes_to_base64(allocator, "AA", &[1]u8{0x00});
    try S.test_bytes_to_base64(allocator, "BA", &[1]u8{0x04});
    try S.test_bytes_to_base64(allocator, "AAAA", &[3]u8{ 0x00, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "BAAA", &[3]u8{ 0x04, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "CAAA", &[3]u8{ 0x08, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "aAAA", &[3]u8{ 0x68, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "zAAA", &[3]u8{ 0xcc, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "0AAA", &[3]u8{ 0xd0, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "9AAA", &[3]u8{ 0xf4, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "+AAA", &[3]u8{ 0xf8, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "/AAA", &[3]u8{ 0xfc, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "/AAA", &[3]u8{ 0xfc, 0x00, 0x00 });
    try S.test_bytes_to_base64(allocator, "TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu", "Many hands make light work.");
}

pub fn hex_ascii_to_base64(allocator: std.mem.Allocator, hex_ascii: []const u8) !ArrayList(u8) {
    const bytes = try hex_pairs_to_bytes(allocator, hex_ascii);
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
