//! Utils for bit masks.

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
