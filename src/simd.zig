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
    /// Compares each element of the two vectors producing a mask,
    /// where bit at the element index is set to 1 if the elements equal.
    pub inline fn eqlToBits128(a: @Vector(16, u8), b: @Vector(16, u8)) u64 {
        asm ("pcmpeqb %[a], %[b]"
            : [b] "=v" (b),
            : [a] "v" (a),
        );
        return vecToBits128(b);
    }

    /// Compares each element of the two vectors producing a mask,
    /// where bit at elements' index is set to 1 if the elements don't equal.
    pub inline fn notEqlToBits128(a: @Vector(16, u8), b: @Vector(16, u8)) u64 {
        return ~eqlToBits128(a, b);
    }

    /// Compares each element of the two vectors producing a mask,
    /// where bit at elements' index is set to 1 if the elements equal.
    pub inline fn eqlToBits256(a: @Vector(32, u8), b: @Vector(32, u8)) u64 {
        const result = asm ("vpcmpeqb %[a], %[b], %[result]"
            : [result] "=v" (-> @Vector(32, u8)),
            : [a] "v" (a),
              [b] "v" (b),
        );
        return vecToBits256(result);
    }

    /// Compares each element of the two vectors producing a mask,
    /// where bit at the element index is set to 1 if the elements don't equal.
    pub inline fn notEqlToBits256(a: @Vector(32, u8), b: @Vector(32, u8)) u64 {
        return ~eqlToBits256(a, b);
    }

    /// Permutates elements in `vec` based on `mask` elements.
    ///
    /// Uses only 0..4 bits (low bits) of `mask` indexes,
    /// and if the 7 (the highest) bit equals `1`, the `result[index]` is set to `0`.
    ///
    /// Example:
    /// 1. First iteration - `result[0] = vec[mask[0]]`.
    /// 2. Second - `result[1] = vec[ mask[1] ]`.
    /// 3. ...
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle128(vec: @Vector(16, u8), mask: @Vector(16, u8)) @Vector(16, u8) {
        return asm ("pshufb %[mask], %[vec]" // `vec` is mutated
            : [vec] "+v" (vec),
            : [mask] "v" (mask),
        );
    }

    /// 0..16 elements of `mask` index 0..16 elements of `vec`,
    /// and 16..32 elements of mask index 16..32 elements of `vec`.
    ///
    /// That is, it is like a parallel `shuffle128` for two masks and vectors.
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle256(vec: @Vector(32, u8), mask: @Vector(32, u8)) @Vector(32, u8) {
        return asm ("vpshufb %[mask], %[vec], %[result]"
            : [result] "=v" (-> @Vector(32, u8)),
            : [vec] "v" (vec),
              [mask] "v" (mask),
        );
    }

    /// Like `shuffle128`, but uses 0..6 bits of `mask` elements,
    /// allowing indexing the whole 512-bit vector.
    ///
    /// Returns the resulting vector.
    pub inline fn shuffle512(vec: @Vector(64, u8), mask: @Vector(64, u8)) @Vector(64, u8) {
        return asm ("vpshufb %[mask], %[vec], %[result]"
            : [result] "=v" (-> @Vector(64, u8)),
            : [vec] "v" (vec),
              [mask] "v" (mask),
        );
    }

    /// Returns a bit mask, where 1 is at bits,
    /// at which `vec` has bytes with the highest bit 1.
    inline fn vecToBits128(vec: @Vector(16, u8)) u64 {
        return asm ("pmovmskb %[vec], %[result]"
            : [result] "=r" (-> u64),
            : [vec] "v" (vec),
        );
    }

    /// Returns a bit mask, where 1 is at bits,
    /// at which `vec` has bytes with the highest bit 1.
    inline fn vecToBits256(vec: @Vector(16, u8)) u64 {
        return asm ("vpmovmskb %[vec], %[result]"
            : [result] "=r" (-> u64),
            : [vec] "v" (vec),
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
