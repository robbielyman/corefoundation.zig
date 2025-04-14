const runtime = @import("runtime.zig");
const base = @import("base.zig");
const string = @import("NSString.zig");

pub const NS = struct {
    pub const Integer = runtime.NSInteger;
    pub const Unsigned = runtime.NSUinteger;
    pub const String = string.NSString;
    pub const MutableString = string.NSMutableString;
    pub const NotFound = runtime.NSNotFound;
    pub const ComparisonResult = runtime.ComparisonResult;
    pub const Comparator = runtime.Comparator;
    pub const EnumerationOptions = runtime.EnumerationOptions;
    pub const SortOptions = runtime.SortOptions;
    pub const QualityOfService = runtime.QualityOfService;
};

pub const CF = struct {
    pub const Index = base.Index;
    pub const TypeID = base.TypeID;
    pub const OptionFlags = base.OptionFlags;
    pub const HashCode = base.HashCode;
    pub const Range = base.Range;
    pub const AllocatorRef = base.AllocatorRef;
    pub const AllocatorContext = base.AllocatorContext;
    pub const TypeRef = base.TypeRef;
    pub const Status = i32;
};

test "ref" {
    _ = runtime;
    _ = base;
    _ = string;
}

test "allocation" {
    // if (true) return error.SkipZigTest;
    const std = @import("std");

    // set up Zig allocator and CFAllocatorRef
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const ally, const data = try base.AllocatorRef.fromZigAllocator(allocator);
    defer allocator.destroy(data);

    // replace the CoreFoundation allocator
    const default = base.AllocatorRef.getDefault().?;
    ally.setAsDefault();
    defer default.setAsDefault();

    const cheesy_line = NS.String.fromUTF8Slice("all your base are belong to us!").?;
    // commenting out this line produces a leak that the GPA can detect!
    defer cheesy_line.msgSend(void, "release", .{});

    const desc = base.TypeRef.fromId(cheesy_line.asId()).copyDescription().?;
    // but commenting out this line does not!
    defer desc.msgSend(void, "release", .{});
    // std.debug.print("{s}\n", .{desc.getUTF8String().?});
}
