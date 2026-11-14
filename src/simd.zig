//! SIMD utils.

const std = @import("std");
const meta = std.meta;

/// Expands `vec` so it has `new_len`, filling expanded bytes with zeros.
pub fn expandVec(
    vec: anytype,
    comptime new_len: comptime_int,
) @Vector(new_len, meta.Child(@TypeOf(vec))) {
    return vec ++ @as(@Vector(new_len - vec.len, u8), @splat(0));
}

pub const x86 = struct {
    /// Permutates elements in `vector` based on `mask` elements.
    ///
    /// Uses only 0..4 bits (low bits) of `mask` indexes,
    /// and if the 7 (the highest) bit equals `1`, the `result[index]` is set to `0`.
    ///
    /// Example:
    /// 1. First iteration - `result[0] = vector[mask[0]]`.
    /// 2. Second - `result[1] = vector[ mask[1] ]`.
    /// 3. ...
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle128(
        vector: @Vector(16, u8),
        mask: @Vector(16, u8),
    ) @TypeOf(vector) {
        return asm ("pshufb %[mask], %[vector]" // `vector` is mutated
            : [vector] "+v" (vector),
            : [mask] "v" (mask),
        );
    }

    /// 0..16 elements of `mask` index 0..16 elements of `vector`,
    /// and 16..32 elements of mask index 16..32 elements of `vector`.
    ///
    /// That is, it is like a parallel `shuffle128` for two masks and vectors.
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle256(
        vector: @Vector(32, u8),
        mask: @Vector(32, u8),
    ) @TypeOf(vector) {
        return asm ("vpshufb %[mask], %[vector], %[result]"
            : [result] "=v" (-> @Vector(32, u8)),
            : [vector] "v" (vector),
              [mask] "v" (mask),
        );
    }

    /// Like `shuffle128`, but uses 0..6 bits of `mask` elements,
    /// allowing indexing the whole 512-bit vector.
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle512(
        vector: @Vector(64, u8),
        mask: @Vector(64, u8),
    ) @TypeOf(vector) {
        return asm ("vpshufb %[mask], %[vector], %[result]"
            : [result] "=v" (-> @Vector(64, u8)),
            : [vector] "v" (vector),
              [mask] "v" (mask),
        );
    }
};

/// Returns a vector with only low nibbles of each `vec` byte.
pub fn getLowNibbles(vec: anytype) @TypeOf(vec) {
    return vec & @as(@TypeOf(vec), @splat(0b00001111));
}

/// Returns a vector with only high nibbles of each `vec` byte.
pub fn getHighNibbles(vec: anytype) @TypeOf(vec) {
    return vec >> @as(@TypeOf(vec), @splat(4));
}
