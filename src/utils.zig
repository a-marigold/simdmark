/// Returns the low nibble of `byte`.
pub inline fn getLowNibble(byte: u8) u8 {
    return byte & 0b00001111;
}

/// Returns the high nibble of `byte`.
pub inline fn getHighNibble(byte: u8) u8 {
    return byte >> 4;
}
