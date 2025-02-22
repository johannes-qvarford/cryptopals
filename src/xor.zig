const std = @import("std");
const hex = @import("./hex.zig");

fn xor_in_place(a: []u8, b: []const u8) void {
    for (b, 0..) |bv, i| {
        a[i] ^= bv;
    }
}

fn xor(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    try std.testing.expectEqual(a.len, b.len);
    const ret = try allocator.alloc(u8, a.len);
    std.mem.copyForwards(u8, ret, a);
    xor_in_place(ret, b);
    return ret;
}

test "xor_in_place works" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(a: []const u8, b: []const u8, expected: []const u8) !void {
            const actual = try xor(allocator, a, b);
            defer {
                allocator.free(actual);
            }
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    };

    try S.t(&[1]u8{0b00_11_00_11}, &[1]u8{0b11_00_11_00}, &[1]u8{0b11_11_11_11});
    try S.t(&[2]u8{ 0b00_11_00_11, 0b11_11_11_11 }, &[2]u8{ 0b11_00_11_00, 0b11_11_11_11 }, &[2]u8{ 0b11_11_11_11, 0b00_00_00_00 });
}

fn xor_hex(allocator: std.mem.Allocator, a_hex: []const u8, b_hex: []const u8) ![]const u8 {
    const a = try hex.hex_to_bytes(allocator, a_hex);
    defer {
        allocator.free(a);
    }
    const b = try hex.hex_to_bytes(allocator, b_hex);
    defer {
        allocator.free(b);
    }

    const c = try xor(allocator, a, b);
    defer {
        allocator.free(c);
    }
    return try hex.bytes_to_hex(allocator, c);
}

test "xor_hex works" {
    const S = struct {
        const allocator = std.testing.allocator;
        fn t(a: []const u8, b: []const u8, expected: []const u8) !void {
            const actual = try xor_hex(allocator, a, b);
            defer {
                allocator.free(actual);
            }
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    };

    try S.t("1c", "68", "74");
    try S.t("1c0111001f010100061a024b53535009181c", "686974207468652062756c6c277320657965", "746865206b696420646f6e277420706c6179");
}
