pub const runtime = @import("runtime.zig");
pub const base = @import("base.zig");
pub const string = @import("NSString.zig");

test "ref" {
    _ = runtime;
    _ = base;
    _ = string;
}

test "allocators + strings" {
    const std = @import("std");
    // std.testing.log_level = .debug;
    const default = base.AllocatorRef.getDefault() orelse return error.SkipZigTest;
    const allocator, const data = try base.AllocatorRef.fromZigAllocator(std.testing.allocator);
    defer std.testing.allocator.destroy(data);
    const type_ref: *base.TypeRef = @ptrCast(allocator);
    allocator.setAsDefault();
    defer default.setAsDefault();
    const str = string.NSString.fromZigFmt("the hash of the allocator is 0x{x}", .{
        @intFromEnum(type_ref.hash()),
    }) orelse return error.Failed;
    defer str.msgSend(void, "release", .{});
    const slice = string.NSString.fromId(str.asId()).getUTF8String() orelse return error.Failed;
    std.log.debug("{s}", .{slice});
    blk: {
        const desc = base.TypeRef.fromId(str.asId()).copyDescription() orelse break :blk;
        defer desc.msgSend(void, "release", .{});
        std.log.debug("{s}", .{desc.getUTF8String() orelse break :blk});
    }
    try std.testing.expect(std.mem.startsWith(u8, slice, "the hash of the allocator is "));
    const owner = base.TypeRef.fromId(str.asId()).getAllocator() orelse return error.Failed;
    const other: *base.TypeRef = @ptrCast(owner);
    try std.testing.expect(type_ref.eql(other));
}
