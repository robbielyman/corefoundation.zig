pub const NSString = opaque {
    pub const Encoding = enum(NS.Unsigned) {
        ascii = 1,
        nextstep = 2,
        japanese_EUC = 3,
        utf8 = 4,
        iso_latin_1 = 5,
        symbol = 6,
        nonlossy_ascii = 7,
        shift_jis = 8,
        iso_latin_2 = 9,
        unicode = 10,
        windows_cp1251 = 11,
        windows_cp1252 = 12,
        windosw_cp1253 = 13,
        windows_cp1254 = 14,
        windows_cp1250 = 15,
        iso_2022_jp = 21,
        macos_roman = 30,
        utf16_big_endian = 0x90000100,
        utf16_little_endian = 0x94000100,
        utf32 = 0x8c000100,
        utf32_big_endian = 0x98000100,
        utf32_little_endian = 0x9c000100,

        pub const utf16: Encoding = .unicode;
    };

    const Inner = objz.Type("NSString");

    pub const msgSend = Inner.msgSend;
    pub const msgSendSuper = Inner.msgSendSuper;

    pub const class = Inner.class;
    pub fn asId(self: *NSString) *objz.Id {
        const inner: *Inner = @ptrCast(self);
        return inner.asId();
    }

    pub fn fromId(id: *objz.Id) *NSString {
        return @ptrCast(id);
    }

    pub const encoding = Inner.encoding;

    pub fn fromUTF8Slice(slice: []const u8) ?*NSString {
        const cl = Inner.class() orelse return null;
        return cl.msgSend(?*NSString, "stringWithBytes:length:encoding:", .{
            slice.ptr,
            @as(NS.Unsigned, @intCast(slice.len)),
            @intFromEnum(Encoding.utf8),
        });
    }

    /// allocator is used to free slice when the string is released
    pub fn fromOwnedUTF8Slice(slice: []const u8, allocator: std.mem.Allocator) ?*NSString {
        const cl = Inner.class() orelse return null;
        const nsstring = cl.msgSend(*objz.Id, "alloc", .{});
        const context = deallocationBlockFromAllocator(allocator);
        const blk: *DeallocationBlock = .copyFromContext(&context);
        defer blk.release();
        return nsstring.msgSend(?*NSString, "initWithBytesNoCopy:length:encoding:deallocator:", .{
            slice.ptr,
            @as(NS.Unsigned, @intCast(slice.len)),
            @intFromEnum(Encoding.utf8),
            blk,
        });
    }

    pub fn fromZigFmt(comptime format: []const u8, args: anytype) ?*NSString {
        const mutable_string = (NSMutableString.class() orelse return null)
            .msgSend(*NSMutableString, "alloc", .{})
            .msgSend(*NSMutableString, "init", .{});
        defer mutable_string.msgSend(void, "release", .{});
        const writer = mutable_string.writer();
        writer.print(format, args) catch return null;
        return mutable_string.toImmutable();
    }

    /// caller does not own returned memory
    pub fn getUTF8String(self: *NSString) ?[:0]const u8 {
        const ptr = self.msgSend(?[*:0]const u8, "UTF8String", .{}) orelse return null;
        return std.mem.sliceTo(ptr, 0);
    }
};

pub const NSMutableString = struct {
    pub const Encoding = NSString.Encoding;

    const Inner = objz.Type("NSMutableString");

    pub const msgSend = Inner.msgSend;
    pub const msgSendSuper = Inner.msgSendSuper;

    pub const encoding = Inner.encoding;

    pub const class = Inner.class;
    pub fn asId(self: *NSMutableString) *objz.Id {
        const inner: *Inner = @ptrCast(self);
        return inner.asId();
    }

    pub fn fromId(id: *objz.Id) *NSMutableString {
        return @ptrCast(id);
    }

    pub fn fromUTF8Slice(slice: []const u8) ?*NSMutableString {
        const cl = Inner.class() orelse return null;
        return cl.msgSend(?*NSMutableString, "stringWithBytes:length:encoding:", .{
            slice.ptr,
            @as(NS.Unsigned, @intCast(slice.len)),
            @intFromEnum(Encoding.utf8),
        });
    }

    /// allocator is used to free slice when the string is released
    pub fn fromOwnedUTF8Slice(slice: []const u8, allocator: std.mem.Allocator) ?*NSMutableString {
        const cl = Inner.class() orelse return null;
        const nsstring = cl.msgSend(*objz.Id, "alloc", .{});
        const ctx = deallocationBlockFromAllocator(allocator);
        const blk: *DeallocationBlock = .copyFromContext(&ctx);
        defer blk.release();
        return nsstring.msgSend(?*NSMutableString, "initWithBytesNoCopy:length:encoding:deallocator:", .{
            slice.ptr,
            @as(NS.Unsigned, @intCast(slice.len)),
            @intFromEnum(Encoding.utf8),
            blk,
        });
    }

    pub fn writer(self: *NSMutableString) Writer {
        return .{ .context = self };
    }

    pub const Writer = std.io.GenericWriter(*NSMutableString, error{UTF8StringCreationFailed}, writeFn);

    fn writeFn(self: *NSMutableString, bytes: []const u8) error{UTF8StringCreationFailed}!usize {
        const string = NSString.fromUTF8Slice(bytes) orelse return error.UTF8StringCreationFailed;
        defer string.msgSend(void, "release", .{});
        self.msgSend(void, "appendString:", .{string});
        return bytes.len;
    }

    pub fn toImmutable(self: *NSMutableString) *NSString {
        return NSString.class().?.msgSend(*NSString, "stringWithString:", .{self});
    }

    /// caller does not own returned memory
    pub fn getUTF8String(self: *NSMutableString) ?[:0]const u8 {
        const ptr = self.msgSend(?[*:0]const u8, "UTF8String", .{}) orelse return null;
        return std.mem.sliceTo(ptr, 0);
    }

    test Writer {
        const string = NSString.fromZigFmt("this string is {d} lil string, that's for sure!", .{1}) orelse return error.Failed;
        defer string.msgSend(void, "release", .{});
        const slice = string.getUTF8String() orelse return error.Failed;
        try std.testing.expectEqualStrings("this string is 1 lil string, that's for sure!", slice);
    }
};

const deallocation = @import("deallocation_block.zig");
const DeallocationBlock = deallocation.DeallocationBlock;
const deallocationBlockFromAllocator = deallocation.deallocationBlockFromAllocator;
const objz = @import("objz");
const NS = @import("root.zig").NS;
const std = @import("std");

test NSString {
    const unowned = NSString.fromUTF8Slice("slice!") orelse return error.Failed;
    defer unowned.msgSend(void, "release", .{});

    const owned_slice = try std.testing.allocator.dupe(u8, "slice!");
    const owned = NSString.fromOwnedUTF8Slice(owned_slice, std.testing.allocator) orelse return error.Failed;
    defer owned.msgSend(void, "release", .{});

    try std.testing.expect(owned.msgSend(bool, "isEqualToString:", .{unowned}));
}

test "ref" {
    _ = NSString;
    _ = NSMutableString;
}
