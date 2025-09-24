pub const DeallocationBlock = objz.Block(struct {
    allocator_ptr: ?*anyopaque,
    allocator_vtable: ?*const anyopaque,
}, .{ ?*const anyopaque, NS.Unsigned }, void);

pub fn deallocationBlockFromAllocator(allocator: std.mem.Allocator) DeallocationBlock.Context {
    return .{
        .allocator_ptr = allocator.ptr,
        .allocator_vtable = allocator.vtable,
        .invoke = struct {
            fn free(blk: *const anyopaque, ptr: ?*const anyopaque, len: NS.Unsigned) callconv(.c) void {
                if (ptr == null or len == 0) return;
                const ctx = DeallocationBlock.contextCast(blk);
                const ally: std.mem.Allocator = .{
                    .ptr = ctx.allocator_ptr.?,
                    .vtable = @ptrCast(@alignCast(ctx.allocator_vtable.?)),
                };
                const p: [*]const u8 = @ptrCast(@alignCast(ptr.?));
                ally.free(p[0..@intCast(len)]);
                // const block: *const DeallocationBlock = @ptrCast(ctx);
                // block.release();
            }
        }.free,
    };
}

const std = @import("std");
const NS = @import("root.zig").NS;
const objz = @import("objz");
