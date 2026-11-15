//! Utils for bit masks.

/// For each sequence of `1` bits in an unsigned integer `mask`,
/// leaves only the first least significant bit of the sequence.
///
/// Example:\
/// `01101111` -> `00100001` (right bits are least significant).
pub inline fn getStartsOfMaskSequences(mask: u64) u64 {
    // Example:
    // Mask =                  `0110111100000000`.
    // Shifted = `Mask << 1` = `1101111000000000`
    // Inverted = `~Shifted` = `0010000111111111`
    // Result = `Mask & Inverted` = `0110111100000000` &
    //                              `0010000111111111` =
    //                              `0010000100000000`
    return mask & ~(mask << 1);
}

/// For each sequence of `1` bits in an unsigned integer `mask`,
/// leaves only the last most significant bit of the sequence, **shifted to the left by 1**.
///
/// *shifted to the left* means the resulting mask doesn't contain just ends of sequences,
/// but contains ends shifted to the left by 1.
pub inline fn getEndsOfMaskSequences(mask: u64, mask_starts: u64) u64 {
    // E.g `starts` is `00000100`, `mask` is `00011100`.
    // Addition carries `starts` bits to the left, forming ends of sequences:
    // `00000100` + `00111000` = `01000000`
    return mask + mask_starts;
}

/// Deletes the first trailing 1 from `value`.
///
/// Examples:
/// - `0011` -> `0010`
/// - `0100` -> `0000`
pub inline fn omitTrailBit(value: u64) u8 {
    return value & (value - 1);
}

/// Returns the low nibble of `byte`.
pub inline fn getLowNibble(byte: u8) u8 {
    return byte & 0b00001111;
}

/// Returns the high nibble of `byte`.
pub inline fn getHighNibble(byte: u8) u8 {
    return byte >> 4;
}
