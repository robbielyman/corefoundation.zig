pub const ComparisonResult = enum(NSInteger) {
    ascending = -1,
    same = 0,
    descending = 1,
};

pub const NSInteger = c_long;
pub const NSUinteger = c_ulong;

pub fn Comparator(
    comptime Captures: type,
    comptime comparator_fn: fn (*const Captures, *objz.Id, *objz.Id) ComparisonResult,
) type {
    return opaque {
        const Self = @This();
        pub const ComparatorBlock = objz.Block(Captures, .{ *objz.Id, *objz.Id }, ComparisonResult);

        fn invocation(ctx: *const ComparatorBlock.Context, obj1: *objz.Id, obj2: *objz.Id) callconv(.C) ComparisonResult {
            const captures: Captures = captures: {
                var captures: Captures = undefined;
                const info = @typeInfo(Captures).Struct;
                inline for (info.fields) |field| {
                    @field(captures, field.name) = @field(ctx, field.name);
                }
                break :captures captures;
            };
            return @call(.always_inline, comparator_fn, .{ &captures, obj1, obj2 });
        }

        pub fn init(captures: Captures) !*Self {
            return @ptrCast(try ComparatorBlock.init(captures, Self.invocation));
        }

        pub fn asId(self: *Self) *objz.Id {
            const block: *ComparatorBlock = @ptrCast(self);
            return block.asId();
        }

        pub fn deinit(self: *Self) void {
            const block: *ComparatorBlock = @ptrCast(self);
            block.deinit();
        }

        pub fn invoke(self: *Self, obj1: *objz.Id, obj2: *objz.Id) ComparisonResult {
            const block: *ComparatorBlock = @ptrCast(self);
            return block.invoke(.{ obj1, obj2 });
        }
    };
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

        fn comparison(captures: *const @This(), _: *objz.Id, _: *objz.Id) ComparisonResult {
            return if (captures.flipped) .descending else .ascending;
        }
    };

    const Block = Comparator(Defs, Defs.comparison);
    const block1 = try Block.init(.{ .flipped = false });
    defer block1.deinit();
    const block2 = try Block.init(.{ .flipped = true });
    defer block2.deinit();
    const NSObject = objz.Type("NSObject");
    const obj1 = NSObject.class().?.msgSend(*NSObject, "alloc", .{});
    defer obj1.msgSend(void, "release", .{});
    const obj2 = NSObject.class().?.msgSend(*NSObject, "alloc", .{});
    defer obj2.msgSend(void, "release", .{});

    obj1.msgSend(void, "init", .{});
    obj2.msgSend(void, "init", .{});

    try std.testing.expectEqual(.ascending, block1.invoke(obj1.asId(), obj2.asId()));
    try std.testing.expectEqual(.descending, block2.invoke(obj1.asId(), obj2.asId()));
}
