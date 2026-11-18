//! Utils for bit masks.

const builtin = @import("builtin");
const ARCH = builtin.target.cpu.arch;

/// For each sequence of `1` bits in `mask`,
/// leaves only the leftmost bit of the sequence.
///
/// Example:\
/// `01101111` -> `00100001` (right bits are least significant).
pub inline fn getSequenceStarts(mask: u64) u64 {
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
pub inline fn getSequenceEnds(mask: u64, starts: u64) u64 {
    // E.g `mask` is `00011100`, `starts` is `00000100`.
    // Addition carries `starts` bits to the left, forming ends of sequences:
    // `00011100` + `00000100` = `01000000`
    return mask + starts;
}

/// Returns a mask only those of starts of mask sequences,
/// which end at ends of `filtered_ends`.
///
/// `all_ends` is a mask of all ends of sequences from `getMaskEnds`.
/// `starts` is a mask of all starts of sequences from `getMaskStarts`.
///
/// `filtered_ends` is a mask of ends, starts of which to find.
pub inline fn startsFromSequenceEnds(all_starts: u64, all_ends: u64, filtered_ends: u64) u64 {
    switch (ARCH) {
        .x86_64 => {
            // If a `filtered_ends` bit set to 1 (i.e, a bit of filtered end),
            // extracts this 1. If the bit is set to 0 (an end is filtered out), extracts 0.
            // Then `depositBits` puts this 1 or 0 to indexes of starts
            const extracted_filtered_ends = x64.extractBits(filtered_ends, all_ends);

            const filtered_starts = x64.depositBits(all_starts, extracted_filtered_ends);
            return filtered_starts;
        },
        else => unreachable,
    }
}

/// Sets all bits between `starts` and `ends` to 1.
///
/// `ends` must not be just ends of sequences,
/// but shifted ends like ones that `getSequenceEnds` returns.
///
/// Example:\
/// starts = 10000100, ends = 00010001
///
/// result - 01110011
pub inline fn sequencesFromPositions(starts: u64, ends: u64) u64 {
    return ends - starts;
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
