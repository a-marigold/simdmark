const std = @import("std");
const testing = std.testing;

const Tokenizer = @import("Tokenizer.zig");

test {
    testing.refAllDecls(Tokenizer);
}
