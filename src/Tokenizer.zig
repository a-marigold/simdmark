const Tokenizer = @This();

const std = @import("std");
const Io = std.Io;
const simd = @import("simd.zig");
const utils = @import("utils.zig");

/// Contains constant arrays, indexes of which are low or high nibbles
/// of Markdown chars, and values of which are unique flags of char groups.
///
/// Used to classify Markdown chars with vector shuffle instruction.
///
/// To isolate classified chars of a specific group,
/// the unique flag of that group is used (e.g, )
///
/// Char groups:
/// - Control chars of Markdown and raw HTML (`!`, `#`, `(`, `)`, `[`, `]`, `<`, `>`, `*`, `&`).
/// - List markers (`-`, `+`, `*`).
/// - Numbers (`0`..`9`).
/// - Whitespaces (`\n`, \r`, ` `, `\t`).
const MARK_CHAR_TABLES = block: {
    var low_nibble_table: [16]u8 = @splat(0);
    var high_nibble_table: [8]u8 = @splat(0);

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
                low_nibble_table[utils.getLowNibble(char)] = group_flag;
                high_nibble_table[utils.getHighNibble(char)] = group_flag;
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
            low_nibble_table[utils.getLowNibble(char)] |= list_marker_flag;
            high_nibble_table[utils.getHighNibble(char)] |= list_marker_flag;
        }
    }

    const numeric_flag = 1 << group_index;
    {
        group_index += 1;

        for ('0'..('9' + 1)) |char| {
            // Bitwise OR `|=` because numbers have
            // the same nibbles as some chars above
            low_nibble_table[utils.getLowNibble(char)] |= numeric_flag;
            high_nibble_table[utils.getHighNibble(char)] |= numeric_flag;
        }
    }

    var whitespace_flag = 0;
    {
        const whitespace_groups = .{
            .{ '\t', '\n', '\r' },
            .{' '},
        };

        for (whitespace_groups) |group| {
            const group_flag = 1 << group_index;

            for (group) |char| {
                // Bitwise OR `|=` because whitespaces have
                // the same nibbles as some chars above
                low_nibble_table[utils.getLowNibble(char)] |= group_flag;
                high_nibble_table[utils.getHighNibble(char)] |= group_flag;
            }

            whitespace_flag |= group_flag;
            group_index += 1;
        }
    }

    break :block struct {
        const LOW_NIBBLE_TABLE = low_nibble_table;
        const HIGH_NIBBLE_TABLE = high_nibble_table;

        const CONTROL_FLAG = control_flag;
        const LIST_MARKER_FLAG = list_marker_flag;
        const NUMERIC_FLAG = numeric_flag;
        const WHITESPACE_FLAG = whitespace_flag;
    };
};
