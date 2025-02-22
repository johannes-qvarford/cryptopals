pub const _ = @import("./base64.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
