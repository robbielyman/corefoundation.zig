const objz = @import("objz");

pub const Index = enum(c_long) { _ };
pub const OptionFlags = enum(c_ulong) { _ };
pub const HashCode = enum(c_ulong) { _ };
pub const TypeID = enum(c_ulong) {
    _,

    extern "c" fn CFCopyTypeIDDescription(type_id: TypeID) ?*NSString;

    pub fn copyTypeIDDescription(type_id: TypeID) ?*NSString {
        return CFCopyTypeIDDescription(type_id);
    }
};

pub const Range = extern struct {
    location: Index,
    length: Index,

    pub fn make(loc: Index, len: Index) Range {
        return .{
            .location = loc,
            .length = len,
        };
    }
};

pub const ComparisonResult = enum(c_long) {
    less_than = -1,
    equal_to = 0,
    greater_than = 1,
};

pub const ComparatorFunction = *const fn (val1: ?*const anyopaque, val2: ?*const anyopaque, contex: ?*anyopaque) callconv(.c) ComparisonResult;

pub const AllocatorContext = extern struct {
    version: Index,
    info: ?*anyopaque,
    retain: ?*const fn (info: ?*const anyopaque) callconv(.c) ?*const anyopaque,
    release: ?*const fn (info: ?*const anyopaque) callconv(.c) void,
    copy_description: ?*const fn (info: ?*const anyopaque) callconv(.c) ?*NSString,
    allocate: ?*const fn (alloc_size: Index, hint: OptionFlags, info: ?*anyopaque) callconv(.c) ?*anyopaque,
    reallocate: ?*const fn (ptr: ?*anyopaque, newsize: Index, opts: OptionFlags, info: ?*anyopaque) callconv(.c) ?*anyopaque,
    deallocate: ?*const fn (ptr: ?*anyopaque, info: ?*anyopaque) callconv(.c) void,
    preferred_size: ?*const fn (size: Index, hint: OptionFlags, info: ?*anyopaque) callconv(.c) Index,
};

extern "c" fn CFAllocatorGetTypeId() TypeID;

pub const AllocatorRef = opaque {
    extern "c" fn CFAllocatorSetDefault(?*AllocatorRef) void;

    pub fn setAsDefault(self: *AllocatorRef) void {
        return CFAllocatorSetDefault(self);
    }

    extern "c" fn CFAllocatorGetDefault() ?*AllocatorRef;

    pub fn getDefault() ?*AllocatorRef {
        return CFAllocatorGetDefault();
    }

    extern "c" fn CFAllocatorCreate(allocator: ?*AllocatorRef, context: *AllocatorContext) ?*AllocatorRef;

    pub fn create(allocator: ?*AllocatorRef, context: *AllocatorContext) ?*AllocatorRef {
        return CFAllocatorCreate(allocator, context);
    }

    pub const use_context = @extern(*AllocatorRef, .{
        .name = "kCFAllocatorUseContext",
    });

    pub fn fromZigAllocator(allocator: std.mem.Allocator) !struct { *AllocatorRef, *Data } {
        const data = try allocator.create(Data);
        errdefer allocator.destroy(data);
        data.* = .{
            .info = allocator,
            .ctx = .{
                .version = @enumFromInt(1),
                .info = &data.info,
                .retain = null,
                .release = null,
                .copy_description = null,
                .allocate = allocate,
                .reallocate = reallocate,
                .deallocate = deallocate,
                .preferred_size = null,
            },
        };
        return .{
            create(null, &data.ctx) orelse return error.CreationFailed,
            data,
        };
    }

    pub const Data = struct {
        info: std.mem.Allocator,
        ctx: AllocatorContext,
    };

    pub fn getContext(allocator: *AllocatorRef) AllocatorContext {
        var ctx: AllocatorContext = undefined;
        CFAllocatorGetContext(allocator, &ctx);
        return ctx;
    }

    extern "c" fn CFAllocatorGetContext(allocator: ?*AllocatorRef, ctx: ?*AllocatorContext) void;
};

const alignment: std.mem.Alignment = .of(std.c.max_align_t);
const offset: usize = @max(alignment.toByteUnits(), @sizeOf(Header));
fn totalSize(size: Index) usize {
    const total_size: usize = @intCast(@intFromEnum(size));
    return total_size + offset;
}

fn getAllocator(info: ?*anyopaque) ?std.mem.Allocator {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(info orelse return null));
    return allocator.*;
}

fn allocate(size: Index, _: OptionFlags, info: ?*anyopaque) callconv(.c) ?*anyopaque {
    const total_size = totalSize(size);
    const allocator = getAllocator(info) orelse return null;
    const bytes = allocator.alignedAlloc(u8, alignment, total_size) catch return null;
    const header_ptr: *Header = @ptrCast(bytes.ptr);
    header_ptr.* = .{ .allocated_size = total_size };
    return bytes.ptr + offset;
}

fn reallocate(ptr: ?*anyopaque, newsize: Index, opts: OptionFlags, info: ?*anyopaque) callconv(.c) ?*anyopaque {
    const pointer = ptr orelse return allocate(newsize, opts, info);
    const total_size = totalSize(newsize);
    const allocator = getAllocator(info) orelse return null;
    const bytes: [*]align(alignment.toByteUnits()) u8 = @ptrCast(@alignCast(pointer));
    const header_ptr: *Header = @ptrCast(bytes - offset);
    const old_slice: []align(alignment.toByteUnits()) u8 = old_slice: {
        const slice_start: [*]align(alignment.toByteUnits()) u8 = @ptrCast(@alignCast(header_ptr));
        break :old_slice slice_start[0..header_ptr.allocated_size];
    };
    const new_bytes = allocator.realloc(old_slice, total_size) catch return null;
    const new_header_ptr: *Header = @ptrCast(new_bytes.ptr);
    new_header_ptr.* = .{ .allocated_size = total_size };
    return new_bytes.ptr + offset;
}

fn deallocate(ptr: ?*anyopaque, info: ?*anyopaque) callconv(.c) void {
    const pointer = ptr orelse return;
    const allocator = getAllocator(info) orelse return;
    const bytes: [*]align(alignment.toByteUnits()) u8 = @ptrCast(@alignCast(pointer));
    const header_ptr: *Header = @ptrCast(bytes - offset);
    const old_slice: []align(alignment.toByteUnits()) u8 = old_slice: {
        const slice_start: [*]align(alignment.toByteUnits()) u8 = @ptrCast(@alignCast(header_ptr));
        break :old_slice slice_start[0..header_ptr.allocated_size];
    };
    allocator.free(old_slice);
}

const Header = struct {
    allocated_size: usize,
};

pub const TypeRef = opaque {
    pub fn fromId(id: *objz.Id) *TypeRef {
        return @ptrCast(id);
    }

    pub fn asId(type_ref: *TypeRef) *objz.Id {
        return @ptrCast(type_ref);
    }

    extern "c" fn CFGetTypeID(type_ref: ?*TypeRef) TypeID;

    pub fn getTypeID(type_ref: *TypeRef) TypeID {
        return CFGetTypeID(type_ref);
    }

    extern "c" fn CFRetain(type_ref: ?*TypeRef) ?*TypeRef;

    pub fn retain(type_ref: *TypeRef) ?*TypeRef {
        return CFRetain(type_ref);
    }

    extern "c" fn CFRelease(type_ref: ?*TypeRef) void;

    pub fn release(type_ref: *TypeRef) void {
        return CFRelease(type_ref);
    }

    extern "c" fn CFAutorelease(type_ref: ?*TypeRef) ?*TypeRef;

    pub fn autorelease(type_ref: *TypeRef) ?*TypeRef {
        return CFAutorelease(type_ref);
    }

    extern "c" fn CFGetRetainCount(type_ref: ?*TypeRef) Index;

    pub fn getRetainCount(type_ref: *TypeRef) Index {
        return CFGetRetainCount(type_ref);
    }

    extern "c" fn CFEqual(cf1: ?*TypeRef, cf2: ?*TypeRef) bool;

    pub fn eql(self: *TypeRef, other: ?*TypeRef) bool {
        return CFEqual(self, other);
    }

    extern "c" fn CFHash(type_ref: ?*TypeRef) HashCode;

    pub fn hash(type_ref: *TypeRef) HashCode {
        return CFHash(type_ref);
    }

    extern "c" fn CFCopyDescription(type_ref: ?*TypeRef) ?*NSString;

    pub fn copyDescription(type_ref: *TypeRef) ?*NSString {
        return CFCopyDescription(type_ref);
    }

    extern "c" fn CFGetAllocator(typer_ref: ?*TypeRef) ?*AllocatorRef;

    pub fn getAllocator(type_ref: *TypeRef) ?*AllocatorRef {
        return CFGetAllocator(type_ref);
    }
};

const NSString = @import("NSString.zig").NSString;
const std = @import("std");

test AllocatorRef {
    const default = AllocatorRef.getDefault() orelse return error.SkipZigTest;
    const allocator, const data = try AllocatorRef.fromZigAllocator(std.testing.allocator);
    defer std.testing.allocator.destroy(data);
    allocator.setAsDefault();
    default.setAsDefault();
}

test "ref" {
    _ = AllocatorRef;
    _ = TypeRef;
    _ = Index;
    _ = OptionFlags;
    _ = HashCode;
    _ = Range;
    _ = ComparisonResult;
    _ = ComparatorFunction;
}
