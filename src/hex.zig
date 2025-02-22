const std = @import("std");
const ConversionError = error{CharIsNotNib};

fn hex_char_to_nib(char: u8) anyerror!u8 {
    return try switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => (char - 'a') + ((9 - 0) + 1),
        'A'...'F' => (char - 'A') + ((9 - 0) + 1),
        else => blk: {
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

pub fn hex_to_bytes(allocator: std.mem.Allocator, pairs: []const u8) ![]const u8 {
    _ = try std.math.divExact(usize, pairs.len, 2);

    const bytes = try allocator.alloc(u8, pairs.len / 2);
    errdefer {
        allocator.free(bytes);
    }

    for (0..bytes.len) |i| {
        const first_i: u8 = @intCast(i * 2);
        const second_i = first_i + 1;

        const high_char = pairs[first_i];
        const low_char = pairs[second_i];

        const high_nib = try hex_char_to_nib(high_char);
        const low_nib = try hex_char_to_nib(low_char);

        bytes[i] = (high_nib << 4) + low_nib;
    }

    return bytes;
}

test "hex_to_bytes converts to correct nib" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(expected: []const u8, pairs: []const u8) !void {
            const a = try hex_to_bytes(allocator, pairs);
            defer {
                allocator.free(a);
            }
            try std.testing.expectEqualSlices(u8, expected, a);
        }
    };

    try S.t(&([1]u8{0x0}), "00"[0..]);
    try S.t(&([1]u8{0x82}), "82"[0..]);
    try S.t(&([1]u8{0xFF}), "FF"[0..]);
    try S.t(&([3]u8{ 0x77, 0x12, 0x34 }), "771234"[0..]);
}
