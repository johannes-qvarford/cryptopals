const std = @import("std");
const plaintext = @import("./plaintext.zig");
const hex = @import("./hex.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("LEAK");
    }

    try do(allocator);
}

fn do(allocator: std.mem.Allocator) !void {
    const encoded = "1b37373331363f78151b7f2b783431333d78397828372d363c78373e783a393b3736";

    const original = try hex.hex_to_bytes(allocator, encoded);
    defer {
        allocator.free(original);
    }

    const copy = try allocator.alloc(u8, original.len);
    defer {
        allocator.free(copy);
    }

    const Entry = struct {
        score: i64,
        char: u8,
        const Self = @This();

        fn greaterThan(context: void, a: Self, b: Self) bool {
            _ = context;
            return a.score > b.score;
        }
    };

    var scores: [0x100]Entry = undefined;

    for (0..0x100) |c| {
        std.mem.copyForwards(u8, copy, original);
        for (0..original.len) |i| {
            copy[i] ^= @intCast(c);
        }

        scores[c] = Entry{ .score = plaintext.score_english(copy), .char = @intCast(c) };
    }

    std.mem.sort(Entry, &scores, {}, comptime Entry.greaterThan);

    // Top 10
    for (0..10) |c| {
        const score = scores[c].score;
        const char = scores[c].char;

        std.mem.copyForwards(u8, copy, original);
        for (0..original.len) |i| {
            copy[i] ^= @intCast(char);
        }

        std.debug.print("score: {d}.\nchar: {x}\ntext: {s}\n", .{ score, char, copy });
    }
}
