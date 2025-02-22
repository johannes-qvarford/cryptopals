const std = @import("std");
const base64 = @import("./base64.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("LEAK");
    }

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    const hex = "49276d206b696c6c696e6720796f757220627261696e206c696b65206120706f69736f6e6f7573206d757368726f6f6d";
    const b = try base64.hex_ascii_to_base64(allocator, hex);
    defer {
        b.deinit();
    }
    std.debug.print("This hex {s} is converted to base64 {s}\n", .{ hex, b.items });
}
