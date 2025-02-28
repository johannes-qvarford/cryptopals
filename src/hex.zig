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

pub fn hex_to_bytes(allocator: std.mem.Allocator, pairs: []const u8) ![]u8 {
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

fn nib_to_hex_char(nib: u4) u8 {
    return switch (nib) {
        0...9 => @as(u8, '0') + nib,
        0xa...0xf => @as(u8, 'a') + (nib - 0xa),
    };
}

test "nib_to_hex_char converts to correct nib" {
    try std.testing.expectEqual(nib_to_hex_char(0), '0');
    try std.testing.expectEqual(nib_to_hex_char(9), '9');
    try std.testing.expectEqual(nib_to_hex_char(0xa), 'a');
    try std.testing.expectEqual(nib_to_hex_char(0xf), 'f');
    try std.testing.expectEqual(nib_to_hex_char(0xA), 'a');
    try std.testing.expectEqual(nib_to_hex_char(0xF), 'f');
}

pub fn bytes_to_hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const hex = try allocator.alloc(u8, bytes.len * 2);
    errdefer {
        allocator.free(hex);
    }

    for (bytes, 0..) |byte, i| {
        const high_nib: u4 = @intCast(byte >> 4);
        const low_nib: u4 = @intCast(byte & 0b0000_1111);

        const high_char = nib_to_hex_char(high_nib);
        const low_char = nib_to_hex_char(low_nib);

        hex[(i * 2)] = high_char;
        hex[(i * 2) + 1] = low_char;
    }

    return hex;
}

test "bytes_to_hex works" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(expected: []const u8, bytes: []const u8) !void {
            const a = try bytes_to_hex(allocator, bytes);
            defer {
                allocator.free(a);
            }
            try std.testing.expectEqualSlices(u8, expected, a);
        }
    };

    try S.t(&[2]u8{ 'f', 'a' }, &[1]u8{0xfa});
}
