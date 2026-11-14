const std = @import("std");
const meta = std.meta;

/// Expands `vec` so it has `new_len`, filling expanded bytes with zeros.
pub fn expandVec(
    vec: anytype,
    comptime new_len: comptime_int,
) @Vector(new_len, meta.Child(@TypeOf(vec))) {
    return vec ++ @as(@Vector(new_len - vec.len, u8), @splat(0));
}
