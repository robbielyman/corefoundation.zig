pub const ComparisonResult = enum(NSInteger) {
    ascending = -1,
    same = 0,
    descending = 1,
};

pub const NSInteger = c_long;
pub const NSUinteger = c_ulong;

pub fn Comparator(comptime Captures: type) type {
    return objz.Block(Captures, .{ *objz.Id, *objz.Id }, ComparisonResult);
}

pub const EnumerationOptions = packed struct(NSUinteger) {
    concurrent: bool,
    reverse: bool,
};

pub const SortOptions = packed struct(NSUinteger) {
    concurrent: bool,
    _padding: u2 = 0,
    stable: bool,
};

pub const QualityOfService = enum(NSInteger) {
    user_interactive = 0x21,
    user_initiated = 0x19,
    utility = 0x11,
    background = 0x9,
    default = -1,
};

pub const NSNotFound = std.math.maxInt(NSInteger);

const objz = @import("objz");
const std = @import("std");

test Comparator {
    const Defs = struct {
        flipped: bool,

        const Block = Comparator(@This());

        fn comparison(ctx: *const anyopaque, _: *objz.Id, _: *objz.Id) callconv(.c) ComparisonResult {
            const block_context = Block.contextCast(ctx);
            return if (block_context.flipped) .descending else .ascending;
        }
    };

    const ctx_1: Defs.Block.Context = .{
        .flipped = false,
        .invoke = Defs.comparison,
    };
    const block1: *Defs.Block = .copyFromContext(&ctx_1);
    defer block1.release();
    const ctx_2: Defs.Block.Context = .{
        .flipped = true,
        .invoke = Defs.comparison,
    };
    const block2: *Defs.Block = .copyFromContext(&ctx_2);
    defer block2.release();

    const NSObject = objz.Type("NSObject");
    const obj1 = NSObject.class().?
        .msgSend(*NSObject, "alloc", .{})
        .msgSend(*NSObject, "init", .{});
    defer obj1.msgSend(void, "release", .{});
    const obj2 = NSObject.class().?
        .msgSend(*NSObject, "alloc", .{})
        .msgSend(*NSObject, "init", .{});
    defer obj2.msgSend(void, "release", .{});

    try std.testing.expectEqual(.ascending, block1.invoke(.{ obj1.asId(), obj2.asId() }));
    try std.testing.expectEqual(.descending, block2.invoke(.{ obj1.asId(), obj2.asId() }));
}
