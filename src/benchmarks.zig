const std = @import("std");
const Uuid = @import("Uuid.zig");

const HELP =
    \\uuid-bench [options]
    \\
    \\Options:
    \\  -v <u3>     Provide a specific UUID version (default: 7).
    \\  -d <string> Set domain name for v3 and v5.
    \\  -i <usize>  Set the number of iterations.
    \\  -h          Display this help.
    \\
;

const V = union(enum) {
    v1: Uuid.V1,
    v2: Uuid.V2,
    v3: Uuid.V3,
    v4: Uuid.V4,
    v5: Uuid.V5,
    v6: Uuid.V6,
    v7: Uuid.V7,

    pub fn next(self: *V, name: []const u8) Uuid {
        return switch (self.*) {
            .v1 => |v1| v1.next(),
            .v2 => |v2| v2.nextForPerson(),
            .v3 => |v3| v3.next(name),
            .v4 => |v4| v4.next(),
            .v5 => |v5| v5.next(name),
            .v6 => |v6| v6.next(),
            .v7 => Uuid.V7.next(),
        };
    }
};

pub fn main() anyerror!void {
    const stderr = std.io.getStdErr().writer();
    _ = stderr;
    const stdout = std.io.getStdOut().writer();

    var buf: [1024]u8 = undefined;
    var fixed_buf = std.heap.FixedBufferAllocator.init(buf[0..]);
    const args = try std.process.argsAlloc(fixed_buf.allocator());

    var domain_name: []const u8 = "www.example.com";
    var num_iters: usize = 10;
    var version_int: u3 = 7;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-d")) {
            i += 1;
            if (i == args.len) {
                std.debug.print(HELP, .{});
                std.os.exit(1);
            }
            domain_name = args[i];
        } else if (std.mem.eql(u8, args[i], "-v")) {
            i += 1;
            if (i == args.len) {
                std.debug.print(HELP, .{});
                std.os.exit(1);
            }
            version_int = try std.fmt.parseUnsigned(u3, args[i], 10);
        } else if (std.mem.eql(u8, args[i], "-i")) {
            i += 1;
            if (i == args.len) {
                std.debug.print(HELP, .{});
                std.os.exit(1);
            }
            num_iters = try std.fmt.parseUnsigned(usize, args[i], 10);
        } else if (std.mem.eql(u8, args[i], "-h")) {
            std.debug.print(HELP, .{});
            return;
        } else {
            std.debug.print(HELP, .{});
            std.os.exit(1);
        }
    }

    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    var clock = Uuid.V1.Clock.init(random);

    var v: V = switch (version_int) {
        0 => @panic("PANIC: Version 0 is unused!"),
        1 => .{ .v1 = Uuid.V1.init(&clock, random) },
        2 => .{ .v2 = Uuid.V2.init(&clock, random) },
        3 => .{ .v3 = Uuid.V3.init(Uuid.V3.DNS) },
        4 => .{ .v4 = Uuid.V4.init(random) },
        5 => .{ .v5 = Uuid.V5.init(Uuid.V3.DNS) },
        6 => .{ .v6 = Uuid.V6.init(&clock) },
        7 => .{ .v7 = .{} },
    };
    try stdout.print("UUIDv{d}:\n", .{version_int});

    var timer = try std.time.Timer.start();
    const start = timer.lap();
    i = 1;
    while (i <= num_iters) : (i += 1) {
        const uuid = v.next(domain_name);
        try stdout.print("    iteration {d}, uuid: {s} \n", .{ i, uuid });
    }
    const end = timer.read();

    try stdout.print("Total duration: {s}\n", .{std.fmt.fmtDuration(end - start)});
}
