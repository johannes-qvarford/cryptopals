const std = @import("std");
const hex = @import("./hex.zig");

pub fn score_english(text: []const u8) i64 {
    var sum: i64 = 0;
    for (text) |c| {
        sum += switch (c) {
            // Control characters.
            0x0...0x1f => -10,
            ' ' => 5,
            '!'...'@' => 1,
            'A'...'Z' => 3,
            '['...'`' => 1,
            'a'...'z' => 4,
            '{'...'~' => 1,
            // DEL
            0x7f => -10,
            else => -100,
        };
    }
    return sum;
}

const S = struct {
    const Self = @This();

    pub fn hash(_: Self, x: u8) u32 {
        return x;
    }
    pub fn eql(_: Self, a: u8, b: u8) bool {
        return a == b;
    }
};

test "Can decrypt secret english message" {
    const key = 0x58;

    const allocator = std.testing.allocator;

    const encoded = "1b37373331363f78151b7f2b783431333d78397828372d363c78373e783a393b3736";
    var original = try hex.hex_to_bytes(allocator, encoded);

    defer {
        allocator.free(original);
    }
    for (0..original.len) |i| {
        original[i] ^= @intCast(key);
    }
    const score = score_english(original);

    try std.testing.expectEqual(136, score);
    try std.testing.expectEqualStrings("Cooking MC's like a pound of bacon", original);
}
