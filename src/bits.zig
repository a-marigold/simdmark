//! Utils for bit masks.

const builtin = @import("builtin");
const ARCH = builtin.target.cpu.arch;

/// For each sequence of `1` bits in `mask`,
/// leaves only the leftmost bit of the sequence.
///
/// Example:\
/// `01101111` -> `00100001` (right bits are least significant).
pub inline fn getMaskStarts(mask: u64) u64 {
    // Example:
    // Mask =                  `0110111100000000`.
    // Shifted = `Mask << 1` = `1101111000000000`
    // Inverted = `~Shifted` = `0010000111111111`
    // Result = `Mask & Inverted` = `0110111100000000` &
    //                              `0010000111111111` =
    //                              `0010000100000000`
    return mask & ~(mask << 1);
}

/// For each sequence of `1` bits in `mask`, leaves only
/// the rightmost bit of the sequence, **shifted to the left by 1**.
///
/// **shifted to the left** means the result doesn't contain
/// just ends of sequences, but contains ends shifted to the left by 1.
pub inline fn getMaskEnds(mask: u64, starts: u64) u64 {
    // E.g `mask` is `00011100`, `starts` is `00000100`.
    // Addition carries `starts` bits to the left, forming ends of sequences:
    // `00011100` + `00000100` = `01000000`
    return mask + starts;
}

/// Returns a mask of starts of sequences which correspond to `filtered_ends`.
///
/// That means, `filtered_ends` may contain not all
/// ends of sequences, but only several ones if they are filtered.
pub inline fn startsFromMaskEnds(mask: u64, filtered_ends: u64, starts: u64) u64 {
    switch (ARCH) {
        .x86_64 => {
            const extracted_filtered_ends = x64.extractBits(mask, filtered_ends);

            const filtered_starts = x64.depositBits(starts, extracted_filtered_ends);
            return filtered_starts;
        },
        else => unreachable,
    }
}

/// Deletes the first trailing 1 from `value`.
///
/// Examples:
/// - `0011` -> `0010`
/// - `0100` -> `0000`
pub inline fn omitTrailBit(bits: u64) u8 {
    return bits & (bits - 1);
}

/// Returns the low nibble of `byte`.
pub inline fn getLowNibble(byte: u8) u8 {
    return byte & 0b00001111;
}

/// Returns the high nibble of `byte`.
pub inline fn getHighNibble(byte: u8) u8 {
    return byte >> 4;
}

const x64 = struct {
    /// Extracts bits from `src` where `mask` has 1
    /// and packs them to the least significant bits of result.
    ///
    /// Example:
    /// 1. src = 11011011, mask = 10010000
    /// 2. Extracts **1**10**1**1011
    /// 3. Result - 00000110
    inline fn extractBits(src: u64, mask: u64) u64 {
        return asm ("pext %[mask], %[src], %[result]"
            : [result] "=x" (-> u64),
            : [src] "x" (src),
              [mask] "x" (mask),
        );
    }

    /// Deposits values of bits from `extracted_bits`
    /// to bits of `dests` (destinations), where 1 is placed.
    ///
    /// Example:
    /// 1. dests = 01001001, extracted = 00000110
    /// 2. The first bit in `extracted` is 0, so the leftmost 1
    ///    of `dests` is filled with 1. The next two bits are 1,
    ///    so the next two 1 in `dests` remain unchanged.
    /// 3. Result - 01001000
    inline fn depositBits(dests: u64, extracted_bits: u64) u64 {
        return asm ("pdep %[dests], %[extracted_bits], %[result]"
            : [result] "=x" (-> u64),
            : [extracted_bits] "x" (extracted_bits),
              [dests] "x" (dests),
        );
    }
};
