const std = @import("std");

const Uuid = @This();

/// Nil UUID with all bits set to zero.
pub const NIL = fromInt(0);

bytes: [16]u8,

/// Creates a new UUID from a 16-byte slice.
pub fn fromSlice(bytes: []const u8) Uuid {
    var uuid: Uuid = undefined;
    @memcpy(uuid.bytes[0..], bytes);
    return uuid;
}

/// Creates a new UUID from a u128-bit integer.
pub fn fromInt(int: u128) Uuid {
    var uuid: Uuid = undefined;
    std.mem.writeIntBig(u128, uuid.bytes[0..], int);
    return uuid;
}

/// Formats the UUID according to RFC-4122.
pub fn format(self: Uuid, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    var buf: [36]u8 = undefined;
    self.formatBuf(buf[0..]);
    try writer.writeAll(buf[0..]);
}

/// Formats the UUID to the buffer according to RFC-4122.
pub fn formatBuf(self: Uuid, buf: []u8) void {
    std.debug.assert(buf.len >= 36);

    formatHex(buf[0..8], self.bytes[0..4]);
    buf[8] = '-';
    formatHex(buf[9..13], self.bytes[4..6]);
    buf[13] = '-';
    formatHex(buf[14..18], self.bytes[6..8]);
    buf[18] = '-';
    formatHex(buf[19..23], self.bytes[8..10]);
    buf[23] = '-';
    formatHex(buf[24..], self.bytes[10..]);
}

fn formatHex(dst: []u8, src: []const u8) void {
    std.debug.assert(dst.len >= 2 * src.len);

    const alphabet = "0123456789abcdef";
    var d: usize = 0;
    var s: usize = 0;
    while (d < dst.len and s < src.len) {
        const byte = src[s];
        dst[d] = alphabet[byte >> 4];
        dst[d + 1] = alphabet[byte & 0xF];
        d += 2;
        s += 1;
    }
}

test "format" {
    var buf: [36]u8 = undefined;
    _ = try std.fmt.bufPrint(buf[0..], "{}", .{NIL});
    try std.testing.expectEqualStrings("00000000-0000-0000-0000-000000000000", buf[0..]);
    _ = try std.fmt.bufPrint(buf[0..], "{}", .{fromInt(0x0123456789ABCDEF0123456789ABCDEF)});
    try std.testing.expectEqualStrings("01234567-89ab-cdef-0123-456789abcdef", buf[0..]);
}

fn parseHex(dst: []u8, src: []const u8) error{InvalidCharacter}!void {
    std.debug.assert(src.len & 1 != 1 and dst.len >= src.len / 2);

    var d: usize = 0;
    var s: usize = 0;
    while (d < dst.len and s < src.len) {
        dst[d] = switch (src[s]) {
            '0'...'9' => |c| c - '0',
            'A'...'F' => |c| c - 'A' + 10,
            'a'...'f' => |c| c - 'a' + 10,
            else => return error.InvalidCharacter,
        } << 4 | switch (src[s + 1]) {
            '0'...'9' => |c| c - '0',
            'A'...'F' => |c| c - 'A' + 10,
            'a'...'f' => |c| c - 'a' + 10,
            else => return error.InvalidCharacter,
        };
        d += 1;
        s += 2;
    }
}

/// Parses a RFC-4122-format string, tolerant of separators.
pub fn parse(str: []const u8) error{InvalidCharacter}!Uuid {
    std.debug.assert(str.len >= 36);

    var uuid: Uuid = undefined;
    try parseHex(uuid.bytes[0..4], str[0..8]);
    try parseHex(uuid.bytes[4..6], str[9..13]);
    try parseHex(uuid.bytes[6..8], str[14..18]);
    try parseHex(uuid.bytes[8..10], str[19..23]);
    try parseHex(uuid.bytes[10..], str[24..]);

    return uuid;
}

test "parse" {
    const uuid = try parse("01234567-89ab-cdef-0123-456789abcdef");
    try std.testing.expectEqual(fromInt(0x0123456789ABCDEF0123456789ABCDEF).bytes, uuid.bytes);
}

/// UUID variant or family.
pub const Variant = enum {
    /// Legacy Apollo Network Computing System UUIDs.
    ncs,
    /// RFC 4122/DCE 1.1 UUIDs, or "Leach–Salz" UUIDs.
    rfc4122,
    /// Backwards-compatible Microsoft COM/DCOM UUIDs.
    microsoft,
    /// Reserved for future definition UUIDs.
    future,
};

/// Returns the UUID variant.
pub fn getVariant(self: Uuid) Variant {
    const byte = self.bytes[8];
    if (byte >> 7 == 0b0) {
        return .ncs;
    } else if (byte >> 6 == 0b10) {
        return .rfc4122;
    } else if (byte >> 5 == 0b110) {
        return .microsoft;
    } else {
        return .future;
    }
}

/// Sets the UUID variant.
pub fn setVariant(uuid: *Uuid, variant: Variant) void {
    uuid.bytes[8] = switch (variant) {
        .ncs => uuid.bytes[8] & 0b01111111,
        .rfc4122 => 0b10000000 | (uuid.bytes[8] & 0b00111111),
        .microsoft => 0b11000000 | (uuid.bytes[8] & 0b00011111),
        .future => 0b11100000 | (uuid.bytes[8] & 0b0001111),
    };
}

/// UUID version or subtype.
pub const Version = enum {
    /// Version 0 is unused.
    unused,
    /// Version 1 is the Gregorian time-based UUID from RFC4122.
    time_based_gregorian,
    /// Version 2 is the DCE Security UUID with embedded POSIX UIDs from RFC4122.
    dce_security,
    /// Version 3 is the Name-based UUID using MD5 hashing from RFC4122.
    name_based_md5,
    /// Version 4 is the UUID generated using a pseudo-randomly generated number from RFC4122.
    random,
    /// Version 5 is the Name-based UUID using SHA-1 hashing from RFC4122.
    name_based_sha1,
    /// Version 6 is the Reordered Gregorian time-based UUID from IETF "New UUID Formats" Draft.
    time_based_gregorian_reordered,
    /// Version 7 is the Unix Epoch time-based UUID specified from IETF "New UUID Formats" Draft.
    time_based_unix,
    /// Version 8 is reserved for custom UUID formats from IETF "New UUID Formats" Draft.
    custom,
};

/// Returns the UUID version.
pub fn getVersion(self: Uuid) error{InvalidEnumTag}!Version {
    const version_int: u4 = @truncate(self.bytes[6] >> 4);
    return try std.meta.intToEnum(Version, version_int);
}

/// Sets the UUID version.
pub fn setVersion(uuid: *Uuid, version: Version) void {
    uuid.bytes[6] = @as(u8, @intFromEnum(version)) << 4 | (uuid.bytes[6] & 0xF);
}

test "getVariant/setVariant and getVersion/setVersion" {
    var uuid = try parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
    try std.testing.expectEqual(Variant.rfc4122, uuid.getVariant());
    try std.testing.expectEqual(Version.time_based_gregorian, try uuid.getVersion());

    uuid = try parse("3d813cbb-47fb-32ba-91df-831e1593ac29");
    try std.testing.expectEqual(Variant.rfc4122, uuid.getVariant());
    try std.testing.expectEqual(Version.name_based_md5, try uuid.getVersion());

    uuid = NIL;
    uuid.setVariant(.rfc4122);
    uuid.setVersion(.random);
    try std.testing.expectEqual(Variant.rfc4122, uuid.getVariant());
    try std.testing.expectEqual(Version.random, try uuid.getVersion());
}

/// UUID version 1 created from a Gregorian Epoch nanosecond timestamp and
/// pseudo-randomly generated MAC address.
pub const V1 = struct {
    /// Number of 100-nanosecond intervals from Gregorian Epoch (1582-10-15T00:00:00Z) to UNIX Epoch (1970-01-01T00:00:00Z).
    pub const NUM_INTERVALS_BEFORE_UNIX = 12_219_292_800 * (std.time.ns_per_s / 100);

    random: std.rand.Random,
    clock: *Clock,

    /// Thread-safe wrapping monotonic clock sequence ticking over 100-nanosecond intervals
    /// and being reinitialized with a pseudo-randomly generated number.
    pub const Clock = struct {
        mutex: std.Thread.Mutex = .{},
        random: std.rand.Random,
        timestamp: u60 = 0,
        sequence: u14 = 0,

        pub fn init(random: std.rand.Random) Clock {
            return .{ .random = random };
        }

        fn next(self: *Clock, timestamp: u60) u14 {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (timestamp > self.timestamp) {
                self.sequence = self.random.int(u14);
                self.timestamp = timestamp;
            }

            const sequence = self.sequence;
            self.sequence +%= 1;
            return sequence;
        }
    };

    pub fn init(clock: *Clock, random: std.rand.Random) V1 {
        return .{ .clock = clock, .random = random };
    }

    pub fn next(self: V1) Uuid {
        const timestamp = nanosToTimestamp(std.time.nanoTimestamp());
        var mac: [6]u8 = undefined;
        self.random.bytes(mac[0..]);
        mac[0] |= 1;

        var uuid: Uuid = undefined;

        const sequence = self.clock.next(timestamp);
        setTimestamp(&uuid, timestamp);
        std.mem.writeIntBig(u16, uuid.bytes[8..10], sequence);
        @memcpy(uuid.bytes[10..], mac[0..]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.time_based_gregorian);
        return uuid;
    }

    /// Converts a nanosecond timestamp to a version 1 UUID timestamp.
    pub fn nanosToTimestamp(nanos: i128) u60 {
        const num_intervals_SINCE_UNIX = @divTrunc(nanos, 100);
        const num_intervals: u128 = @bitCast(num_intervals_SINCE_UNIX + NUM_INTERVALS_BEFORE_UNIX);
        return @truncate(num_intervals);
    }

    pub fn getTimestamp(uuid: Uuid) u60 {
        const lo = std.mem.readIntBig(u32, uuid.bytes[0..4]);
        const md = std.mem.readIntBig(u16, uuid.bytes[4..6]);
        const hi = std.mem.readIntBig(u16, uuid.bytes[6..8]) & 0xFFF;
        return @as(u60, hi) << 48 | @as(u60, md) << 32 | @as(u60, lo);
    }

    fn setTimestamp(uuid: *Uuid, timestamp: u60) void {
        const timestamp_u32: u32 = @truncate(timestamp);
        std.mem.writeIntBig(u32, uuid.bytes[0..4], timestamp_u32);
        var timestamp_u16: u16 = @truncate(timestamp >> 32);
        std.mem.writeIntBig(u16, uuid.bytes[4..6], timestamp_u16);
        timestamp_u16 = @truncate(timestamp >> 48);
        std.mem.writeIntBig(u16, uuid.bytes[6..8], timestamp_u16);
    }

    test "V1" {
        var prng = std.rand.DefaultPrng.init(0);
        var clock = V1.Clock.init(prng.random());
        const v1 = V1.init(&clock, prng.random());
        const uuid1 = v1.next();
        const uuid2 = v1.next();
        try std.testing.expect(!std.mem.eql(u8, &uuid1.bytes, &uuid2.bytes));
        try std.testing.expect(!std.mem.eql(u8, uuid1.bytes[10..], uuid2.bytes[10..]));
    }

    pub fn fromV6(uuid_v6: Uuid) Uuid {
        var uuid_v1 = uuid_v6;
        setTimestamp(&uuid_v1, V6.getTimestamp(uuid_v6));
        uuid_v1.setVersion(.time_based_gregorian);
        return uuid_v1;
    }

    test "fromV6" {
        var clock = V1.Clock.init(V6.RANDOM);
        const v6 = V6.init(&clock);
        const uuid_v6 = v6.next();
        const uuid_v1 = V1.fromV6(uuid_v6);
        try std.testing.expectEqual(uuid_v6.getVariant(), uuid_v1.getVariant());
        try std.testing.expectEqual(Version.time_based_gregorian, try uuid_v1.getVersion());
        try std.testing.expectEqualSlices(u8, uuid_v6.bytes[10..], uuid_v1.bytes[10..]);
    }
};

/// UUID version 2 created from a version 1 UUID and user's UID or GID on POSIX systems.
pub const V2 = struct {
    /// Domain represents the ID domain.
    const Domain = enum {
        person,
        group,
        org,
    };

    v1: V1,

    pub fn init(clock: *V1.Clock, random: std.rand.Random) V2 {
        return .{ .v1 = V1.init(clock, random) };
    }

    pub fn next(self: V2, domain: Domain, id: u32) Uuid {
        var uuid = self.v1.next();
        uuid.setVariant(.rfc4122);
        uuid.setVersion(.dce_security);
        setDomain(&uuid, domain);
        setId(&uuid, id);
        return uuid;
    }

    pub fn nextForPerson(self: V2) Uuid {
        return self.next(Domain.person, std.os.linux.getuid());
    }

    pub fn nextForGroup(self: V2) Uuid {
        return self.next(Domain.group, std.os.linux.getgid());
    }

    // Returns the domain for a version 2 UUID.
    pub fn getDomain(uuid: Uuid) error{InvalidEnumTag}!Domain {
        return try std.meta.intToEnum(Domain, uuid.bytes[6]);
    }

    // Sets the domain for a version 2 UUID.
    pub fn setDomain(uuid: *Uuid, domain: Domain) void {
        uuid.bytes[6] = @intFromEnum(domain);
    }

    // Returns the id for a version 2 UUID.
    pub fn getId(uuid: Uuid) u32 {
        return std.mem.readIntBig(u32, uuid.bytes[0..4]);
    }

    // Sets the id for a version 2 UUID.
    pub fn setId(uuid: *Uuid, id: u32) void {
        std.mem.writeIntBig(u32, uuid.bytes[0..4], id);
    }

    test "V2" {
        var prng = std.rand.DefaultPrng.init(0);
        var clock = V1.Clock.init(prng.random());
        const v2 = V2.init(&clock, prng.random());
        const uuid = v2.next(Domain.person, 12345678);
        try std.testing.expectEqual(Domain.person, try V2.getDomain(uuid));
        try std.testing.expectEqual(@as(u32, 12345678), V2.getId(uuid));
    }
};

/// UUID version 3 created from an MD5-hashed name.
pub const V3 = struct {
    pub const DNS = fromInt(0x6BA7B8109DAD11D180B400C04FD430C8);

    md5: std.crypto.hash.Md5,

    pub fn init(uuid: Uuid) V3 {
        var md5 = std.crypto.hash.Md5.init(.{});
        md5.update(&uuid.bytes);
        return .{ .md5 = md5 };
    }

    pub fn next(self: V3, name: []const u8) Uuid {
        var uuid: Uuid = undefined;

        var md5 = self.md5;
        md5.update(name);
        md5.final(uuid.bytes[0..]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.name_based_md5);
        return uuid;
    }

    test "V3" {
        const v3 = V3.init(V3.DNS);
        const uuid1 = v3.next("www.example.com");
        try std.testing.expectEqual(fromInt(0x5DF418813AED351588A72F4A814CF09E), uuid1);
        const uuid2 = v3.next("www.example.com");
        try std.testing.expectEqual(uuid1, uuid2);
    }
};

/// UUID version 4 created from a pseudo-randomly generated number.
pub const V4 = struct {
    random: std.rand.Random,

    pub fn init(random: std.rand.Random) V4 {
        return .{ .random = random };
    }

    pub fn next(self: V4) Uuid {
        var uuid: Uuid = undefined;

        self.random.bytes(uuid.bytes[0..]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.random);
        return uuid;
    }

    test "V4" {
        var prng = std.rand.DefaultPrng.init(0);
        var v4 = V4.init(prng.random());
        const uuid1 = v4.next();
        const uuid2 = v4.next();
        try std.testing.expect(!std.mem.eql(u8, uuid1.bytes[0..], uuid2.bytes[0..]));
    }
};

/// UUID version 5 created from a SHA-1-hashed name.
pub const V5 = struct {
    sha1: std.crypto.hash.Sha1,

    pub fn init(uuid: Uuid) V5 {
        var sha1 = std.crypto.hash.Sha1.init(.{});
        sha1.update(uuid.bytes[0..]);
        return .{ .sha1 = sha1 };
    }

    pub fn next(self: V5, name: []const u8) Uuid {
        var uuid: Uuid = undefined;

        var sha1 = self.sha1;
        sha1.update(name);
        var buf: [20]u8 = undefined;
        sha1.final(buf[0..]);
        @memcpy(uuid.bytes[0..], buf[0..16]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.name_based_sha1);
        return uuid;
    }

    test "V5" {
        const v5 = V5.init(V3.DNS);
        const uuid1 = v5.next("www.example.com");
        try std.testing.expectEqual(fromInt(0x2ED6657DE927568B95E12665A8AEA6A2), uuid1);
        const uuid2 = v5.next("www.example.com");
        try std.testing.expectEqual(uuid1, uuid2);
    }
};

/// UUID version 6 created from a Gregorian Epoch nanosecond timestamp and
/// cryptographically-secure pseudo-randomly generated number.
pub const V6 = struct {
    pub const RANDOM = std.crypto.random;

    clock: *V1.Clock,

    pub fn init(clock: *V1.Clock) V6 {
        return .{ .clock = clock };
    }

    pub fn next(self: V6) Uuid {
        var uuid: Uuid = NIL;

        const timestamp = nanosToTimestamp(std.time.nanoTimestamp());
        const sequence = self.clock.next(timestamp);
        setTimestamp(&uuid, timestamp);
        std.mem.writeIntBig(u16, uuid.bytes[8..10], sequence);
        RANDOM.bytes(uuid.bytes[10..]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.time_based_gregorian_reordered);
        return uuid;
    }

    /// Converts a nanosecond timestamp to a version 6 UUID timestamp.
    pub const nanosToTimestamp = V1.nanosToTimestamp;

    pub fn getTimestamp(uuid: Uuid) u60 {
        const hi = std.mem.readIntBig(u48, uuid.bytes[0..6]);
        const lo = std.mem.readIntBig(u16, uuid.bytes[6..8]) & 0xFFF;
        return @as(u60, hi) << 12 | @as(u60, lo);
    }

    fn setTimestamp(uuid: *Uuid, timestamp: u60) void {
        const timestamp_u48: u48 = @truncate(timestamp >> 12);
        std.mem.writeIntBig(u48, uuid.bytes[0..6], timestamp_u48);
        const timestamp_u16: u16 = @truncate(timestamp & 0xFFF);
        std.mem.writeIntBig(u16, uuid.bytes[6..8], timestamp_u16);
    }

    test "V6" {
        var clock = V1.Clock.init(V6.RANDOM);
        const v6 = V6.init(&clock);
        const uuid1 = v6.next();
        const uuid2 = v6.next();
        try std.testing.expect(!std.mem.eql(u8, &uuid1.bytes, &uuid2.bytes));
    }

    pub fn fromV1(uuid_v1: Uuid) Uuid {
        var uuid_v6 = uuid_v1;
        setTimestamp(&uuid_v6, V1.getTimestamp(uuid_v1));
        uuid_v6.setVersion(.time_based_gregorian_reordered);
        return uuid_v6;
    }

    test "fromV1" {
        var prng = std.rand.DefaultPrng.init(0);
        var clock = V1.Clock.init(prng.random());
        const v1 = V1.init(&clock, prng.random());
        const uuid_v1 = v1.next();
        const uuid_v6 = fromV1(uuid_v1);
        try std.testing.expectEqual(uuid_v1.getVariant(), uuid_v6.getVariant());
        try std.testing.expectEqual(Version.time_based_gregorian_reordered, try uuid_v6.getVersion());
    }
};

/// UUID version 7 created from a UNIX Epoch millisecond timestamp and
/// cryptographically-secure pseudo-randomly generated number.
pub const V7 = struct {
    /// Cryptographically-secure pseudo-random number generator.
    pub const RANDOM = std.crypto.random;

    pub fn next() Uuid {
        var uuid: Uuid = NIL;

        const millis: u64 = @bitCast(std.time.milliTimestamp());
        const millis_u48: u48 = @truncate(millis);
        std.mem.writeIntBig(u48, uuid.bytes[0..6], millis_u48);
        RANDOM.bytes(uuid.bytes[6..]);

        uuid.setVariant(.rfc4122);
        uuid.setVersion(.time_based_unix);
        return uuid;
    }

    test "V7" {
        const uuid1 = V7.next();
        const uuid2 = V7.next();
        try std.testing.expect(!std.mem.eql(u8, &uuid1.bytes, &uuid2.bytes));
    }
};

test {
    std.testing.refAllDecls(Uuid);
}
