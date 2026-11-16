const Tokenizer = @This();

const std = @import("std");
const Io = std.Io;
const simd = @import("simd.zig");
const bits = @import("bits.zig");

// TODO: test the table

/// Contains constant arrays, indexes of which are low or high nibbles
/// of Markdown chars, and values of which are unique flags of char groups.
///
/// Used to classify Markdown chars with vector shuffle instruction.
///
/// To isolate classified chars of a specific group,
/// the unique flag of that group is used (e.g, `chars_vec & CONTROL_FLAG`).
/// Some chars belong to multiple different groups purposely.
///
/// Char groups:
/// - Control chars of Markdown and raw HTML (`!`, `#`, `(`, `)`, `[`, `]`, `<`, `>`, `*`, `&`).
/// - List markers (`-`, `+`, `*`).
/// - Digits (`0`..`9`).
/// - Whitespaces (`\n`, \r`, ` `, `\t`).
const MARK_CHAR_TABLES = block: {
    var low_nibble_table: [16]u8 = @splat(0);
    var high_nibble_table: [16]u8 = @splat(0);

    var group_index = 0;

    var control_flag = 0;
    {
        const control_groups = .{
            // High nibble is `0x2`
            .{ '!', '#', '&', '(', ')', '*' },

            // High nibble is `0x3`, so it doesn't collide
            .{ '<', '>' },

            // High nibble is `0x5`, so it doesn't collide
            .{ '[', ']', '_' },
        };

        for (control_groups) |group| {
            const group_flag = 1 << group_index;

            for (group) |char| {
                low_nibble_table[bits.getLowNibble(char)] = group_flag;
                high_nibble_table[bits.getHighNibble(char)] = group_flag;
            }

            control_flag |= group_flag;
            group_index += 1;
        }
    }

    const list_marker_flag = 1 << group_index;
    {
        group_index += 1;

        for (.{ '-', '+', '*' }) |char| {
            // Bitwise OR `|=` because markers have
            // the same nibbles as some control chars
            low_nibble_table[bits.getLowNibble(char)] |= list_marker_flag;
            high_nibble_table[bits.getHighNibble(char)] |= list_marker_flag;
        }
    }

    const digit_flag = 1 << group_index;
    {
        group_index += 1;

        for ('0'..('9' + 1)) |char| {
            // Bitwise OR `|=` because digits have
            // the same nibbles as some chars above
            low_nibble_table[bits.getLowNibble(char)] |= digit_flag;
            high_nibble_table[bits.getHighNibble(char)] |= digit_flag;
        }
    }

    var whitespace_flag = 0;
    {
        const whitespace_groups = .{
            .{ '\r', '\n', '\t' },
            .{' '},
        };

        for (whitespace_groups) |group| {
            const group_flag = 1 << group_index;

            for (group) |char| {
                // Bitwise OR `|=` because whitespaces have
                // the same nibbles as some chars above
                low_nibble_table[bits.getLowNibble(char)] |= group_flag;
                high_nibble_table[bits.getHighNibble(char)] |= group_flag;
            }

            whitespace_flag |= group_flag;
            group_index += 1;
        }
    }

    break :block struct {
        // Align to load into registers (which have 16-, 32- or 64-byte size)
        const LOW_NIBBLE_TABLE: [16]u8 align(8) = low_nibble_table;
        const HIGH_NIBBLE_TABLE: [16]u8 align(8) = high_nibble_table;

        const CONTROL_FLAG = control_flag;
        const LIST_MARKER_FLAG = list_marker_flag;
        const DIGIT_FLAG = digit_flag;
        const WHITESPACE_FLAG = whitespace_flag;
    };
};

/// Classifies Markdown chars of the chunk and returns bit masks of them.
inline fn getMarkCharMasks(
    comptime chunk_len: comptime_int,
    chunk_low_nibbles: @Vector(chunk_len, u8),
    chunk_high_nibbles: @Vector(chunk_len, u8),
) struct {
    control: u64,
    list_markers: u64,
    digits: u64,
    whitespace: u64,
} {
    const char_low_nibble_table: @Vector(16, u8) = MARK_CHAR_TABLES.LOW_NIBBLE_TABLE;
    const char_high_nibble_table: @Vector(16, u8) = MARK_CHAR_TABLES.HIGH_NIBBLE_TABLE;

    const control_flag_vec: @Vector(chunk_len, u8) = @splat(MARK_CHAR_TABLES.CONTROL_FLAG);
    const list_markers_flag_vec: @Vector(chunk_len, u8) = @splat(MARK_CHAR_TABLES.LIST_MARKER_FLAG);
    const digits_flag_vec: @Vector(chunk_len, u8) = @splat(MARK_CHAR_TABLES.DIGIT_FLAG);
    const whitespace_flag_vec: @Vector(chunk_len, u8) = @splat(MARK_CHAR_TABLES.WHITESPACE_FLAG);

    switch (comptime chunk_len) {
        16 => {
            const low_nibbles_match = simd.x64.shuffle128(char_low_nibble_table, chunk_low_nibbles);
            const high_nibbles_match = simd.x64.shuffle128(char_high_nibble_table, chunk_high_nibbles);

            const chars_match = low_nibbles_match & high_nibbles_match;

            return .{
                .control = simd.x64.notEqlToBits128(chars_match & control_flag_vec, @splat(0)),
                .list_markers = simd.x64.notEqlToBits128(chars_match & list_markers_flag_vec, @splat(0)),
                .digits = simd.x64.notEqlToBits128(chars_match & digits_flag_vec, @splat(0)),
                .whitespace = simd.x64.notEqlToBits128(chars_match & whitespace_flag_vec, @splat(0)),
            };
        },
        32 => {
            // TODO: compiler explorer for `++`

            // Shuffle of AVX2 (32-byte vectors) does two parallel shuffles
            // for two 16-byte halves instead of a single 32-byte wide shuffle
            const low_nibbles_match = simd.x64.shuffle256(char_low_nibble_table ++ char_low_nibble_table, chunk_low_nibbles);
            const high_nibbles_match = simd.x64.shuffle256(char_high_nibble_table ++ char_high_nibble_table, chunk_high_nibbles);

            const chars_match = low_nibbles_match & high_nibbles_match;

            return .{
                .control = simd.x64.notEqlToBits256(chars_match & control_flag_vec, @splat(0)),
                .list_markers = simd.x64.notEqlToBits256(chars_match & list_markers_flag_vec, @splat(0)),
                .digits = simd.x64.notEqlToBits256(chars_match & digits_flag_vec, @splat(0)),
                .whitespace = simd.x64.notEqlToBits128(chars_match & whitespace_flag_vec, @splat(0)),
            };
        },
        64 => {
            // TODO: compiler explorer for `++`
            const char_low_nibble_tables =
                char_low_nibble_table ++ char_low_nibble_table ++ char_low_nibble_table ++ char_low_nibble_table;

            const char_high_nibble_tables =
                char_high_nibble_table ++ char_high_nibble_table ++ char_high_nibble_table ++ char_high_nibble_table;

            const low_nibbles_match = simd.x64.shuffle512(char_low_nibble_tables, chunk_low_nibbles);
            const high_nibbles_match = simd.x64.shuffle512(char_high_nibble_tables, chunk_high_nibbles);

            const chars_match = low_nibbles_match & high_nibbles_match;

            return .{
                .control = simd.x64.andToBits512(chars_match, control_flag_vec),
                .list_markers = simd.x64.andToBits512(chars_match, list_markers_flag_vec),
                .digits = simd.x64.andToBits512(chars_match, digits_flag_vec),
                .whitespace = simd.x64.andToBits512(chars_match, whitespace_flag_vec),
            };
        },
    }
}

// TODO:
// min3 = backticks & (backticks >> 1) & (backticks >> 2)
// starts = bt & ~(bt << 1)
// fence_candidates = m3 & starts & line_start_mask

// TODO:
// N = new line
// Containers mask:
// `N>> 1. - 16. # abc>> 1. - 16. # abc`
// `01111111111110100011111111111101000`
// N mask:
// `10000000000000000000000000000000000`
// N mask + containers mask:
// `00000000000001100011111111111101000`
// Invert the result
// Inverted & Containers mask: to get containers starting from N
