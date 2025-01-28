const std = @import("std");
const testing = std.testing;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

const HexAscii = struct {
    byte: u8,

    const Self = @This();

    fn init_from_ascii_pair(pair: [2]u8) Self {
        const a_nib = Self.hex_byte_to_nib(pair[0]);
        const b_nib = Self.hex_byte_to_nib(pair[1]);
        return Self{ .byte = @shlExact(a_nib, 4) || b_nib };
    }

    fn hex_byte_to_nib(a: u8) u4 {
        const nib = switch (a) {
            '0'...'9' => a - '0',
            'a'...'f' => (a - 'a') + ((9 - 0) + 1),
        };
        return nib;
    }
};

const Base64 = struct {
    chars: [3]u8,
    total_bits: u8,

    const Self = @This();

    fn init_from_ascii_slice(ascii: []HexAscii) Self {
        const current_total_bits = 0;
        const chars = [3]u8{0};

        for (ascii, 0..ascii.len) |hex, _| {
            const byte = Self.ascii_char_to_sextet(hex.byte);
            const current_byte = current_total_bits / 8;
            const current_bit = current_total_bits % 8;

            chars[current_byte] = chars[current_byte] | (byte << current_bit);

            // are there leftovers?
            if (current_total_bits % 8 > 2) {
                const current_byte_2 = current_byte + 1;
                const current_bit_2 = (current_bit + 6) % 8;
                chars[current_byte] = chars[current_byte_2] | (byte >> current_bit_2);
                current_total_bits + 6;
            }

            current_total_bits + 6;
        }

        return Self{ .chars = chars, .len = (current_total_bits % 8) + 1 };
    }

    fn ascii_char_to_sextet(ascii_char: u8) u6 {
        const sextet = switch (ascii_char) {
            'a'...'z' => ascii_char - 26,
            '0'...'9' => ascii_char - 52,
            '+' => 62,
            '/' => 63,
        };
        return sextet;
    }
};

const ConversionError = error{CharIsNotNib};

fn hex_pairs_to_bytes(allocator: *std.mem.Allocator, pairs: []const u8) ![]const u8 {
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

fn test_hex_pairs_to_bytes(allocator: *std.mem.Allocator, expected: []const u8, pairs: []const u8) !void {
    const a = try hex_pairs_to_bytes(allocator, pairs);
    defer {
        allocator.free(a);
    }
    try std.testing.expectEqualSlices(u8, expected, a);
}

test "hex_pairs_to_bytes converts to correct nib" {
    var allocator = std.testing.allocator;

    try test_hex_pairs_to_bytes(&allocator, &([1]u8{0x0}), "00"[0..]);
    try test_hex_pairs_to_bytes(&allocator, &([1]u8{0x82}), "82"[0..]);
    try test_hex_pairs_to_bytes(&allocator, &([1]u8{0xFF}), "FF"[0..]);
    try test_hex_pairs_to_bytes(&allocator, &([3]u8{ 0x77, 0x12, 0x34 }), "771234"[0..]);
}

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

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    try list.append(42);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
