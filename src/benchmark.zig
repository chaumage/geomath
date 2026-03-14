const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const ShapeMesher = @import("shape_mesher.zig").ShapeMesher;

const PERF_TYPE_HARDWARE: u32 = 0;
const PERF_COUNT_HW_CPU_CYCLES = 0;
const PERF_COUNT_HW_INSTRUCTIONS = 1;
const PERF_COUNT_HW_CACHE_REFERENCES = 2;
const PERF_COUNT_HW_CACHE_MISSES = 3;
const PERF_COUNT_HW_CACHE_L1D: u64 = 0; // L1 cache
const PERF_COUNT_HW_CACHE_LL: u64 = 2; // Last Level Cache
const PERF_COUNT_HW_BRANCH_INSTRUCTIONS = 4;
const PERF_COUNT_HW_BRANCH_MISSES = 5;

const perf_event_attr = extern struct {
    type: u32 = 0,
    size: u32 = @sizeOf(perf_event_attr),
    config: u64 = 0,
    sample_period: u64 = 0,
    sample_type: u64 = 0,
    read_format: u64 = 0,
    flags: u64 = 0,
    wakeup_events: u32 = 0,
    bp_type: u32 = 0,
    bp_addr: u64 = 0,
    bp_len: u64 = 0,
    branch_sample_type: u64 = 0,
    sample_regs_user: u64 = 0,
    sample_stack_user: u32 = 0,
    clockid: i32 = 0,
    sample_regs_intr: u64 = 0,
    aux_watermark: u32 = 0,
    sample_max_stack: u16 = 0,
    __reserved_2: u16 = 0,
};

fn perf_event_open(attr: *perf_event_attr, pid: i32, cpu: i32, group_fd: i32, flags: usize) !i32 {
    const rc = linux.syscall5(
        .perf_event_open,
        @intFromPtr(attr),
        @as(usize, @bitCast(@as(isize, pid))),
        @as(usize, @bitCast(@as(isize, cpu))),
        @as(usize, @bitCast(@as(isize, group_fd))),
        flags,
    );
    switch (linux.E.init(rc)) {
        .SUCCESS => return @intCast(rc),
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn openCounter(config: u64) !i32 {
    var attr = perf_event_attr{
        .type = PERF_TYPE_HARDWARE,
        .config = config,
    };
    // disable = 1, exclude_kernel = 1, exclude_hv = 1
    attr.flags = (1 << 0) | (1 << 5) | (1 << 6);
    return perf_event_open(&attr, 0, -1, -1, 0);
}

fn resetAndEnable(fd: i32) !void {
    _ = linux.syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), 0x2403, 0); // PERF_EVENT_IOC_RESET
    _ = linux.syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), 0x2400, 0); // PERF_EVENT_IOC_ENABLE
}

fn disableAndRead(fd: i32) !u64 {
    _ = linux.syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), 0x2401, 0); // PERF_EVENT_IOC_DISABLE
    var value: u64 = 0;
    const n = linux.read(@as(i32, fd), std.mem.asBytes(&value), 8);
    if (n != @sizeOf(u64)) return error.ReadFailed;
    return value;
}

// Op : READ=0, WRITE=1, PREFETCH=2
// Résultat : ACCESS=0, MISS=1
fn cacheConfig(cache_id: u64, op: u64, result: u64) u64 {
    return cache_id | (op << 8) | (result << 16);
}

test "Integration performance benchmark" {
    const iterations = 10_000_000;

    const Shape = ShapeMesher(u16, f64, 16);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    });

    // Ouvre les compteurs matériels
    const fd_cycles = try openCounter(PERF_COUNT_HW_CPU_CYCLES);
    const fd_instrs = try openCounter(PERF_COUNT_HW_INSTRUCTIONS);
    const fd_crefs = try openCounter(PERF_COUNT_HW_CACHE_REFERENCES);
    const fd_cmiss = try openCounter(PERF_COUNT_HW_CACHE_MISSES);
    const fd_branches = try openCounter(PERF_COUNT_HW_BRANCH_INSTRUCTIONS);
    const fd_bmiss = try openCounter(PERF_COUNT_HW_BRANCH_MISSES);

    defer {
        _ = linux.close(fd_cycles);
        _ = linux.close(fd_instrs);
        _ = linux.close(fd_crefs);
        _ = linux.close(fd_cmiss);
        _ = linux.close(fd_branches);
        _ = linux.close(fd_bmiss);
    }

    // Démarre tous les compteurs
    try resetAndEnable(fd_cycles);
    try resetAndEnable(fd_instrs);
    try resetAndEnable(fd_crefs);
    try resetAndEnable(fd_cmiss);
    try resetAndEnable(fd_branches);
    try resetAndEnable(fd_bmiss);

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    var sink: f64 = 0;
    while (i < iterations) : (i += 1) {
        sink += shape.integratePositiveLinearFn(2, 0.1, -1);
    }
    const elapsed_ns = timer.read();

    // Lit les compteurs
    const cycles = try disableAndRead(fd_cycles);
    const instrs = try disableAndRead(fd_instrs);
    const crefs = try disableAndRead(fd_crefs);
    const cmiss = try disableAndRead(fd_cmiss);
    const branches = try disableAndRead(fd_branches);
    const bmiss = try disableAndRead(fd_bmiss);

    std.mem.doNotOptimizeAway(sink);

    // Calculs dérivés
    const avg_ns = elapsed_ns / iterations;
    const avg_cycles = cycles / iterations;
    const avg_instrs = instrs / iterations;
    const ipc_x100 = if (cycles > 0) (instrs * 100) / cycles else 0; // IPC × 100
    const cmiss_pct = if (crefs > 0) (cmiss * 100) / crefs else 0;
    const bmiss_pct = if (branches > 0) (bmiss * 100) / branches else 0;

    std.debug.print(
        \\
        \\╔══════════════════════════════════════════╗
        \\║           BENCHMARK RÉSULTATS            ║
        \\╠══════════════════════════════════════════╣
        \\║  Itérations          : {d:>12}      ║
        \\╠══════════════════════════════════════════╣
        \\║  ⏱  Temps total      : {d:>9} ms      ║
        \\║  ⏱  Temps moyen      : {d:>9} ns/op   ║
        \\╠══════════════════════════════════════════╣
        \\║  🔁 Cycles (total)   : {d:>12}      ║
        \\║  🔁 Cycles (moy)     : {d:>12}      ║
        \\║  📜 Instructions(moy): {d:>12}      ║
        \\║  ⚡ IPC              : {d:>10}.{d:02}     ║
        \\╠══════════════════════════════════════════╣
        \\║  💾 Cache refs (tot) : {d:>12}      ║
        \\║  💾 Cache miss (tot) : {d:>12}      ║
        \\║  💾 Cache miss rate  : {d:>11} %     ║
        \\╠══════════════════════════════════════════╣
        \\║  🌿 Branches  (tot)  : {d:>12}      ║
        \\║  🌿 Br. miss  (tot)  : {d:>12}      ║
        \\║  🌿 Br. miss rate    : {d:>11} %     ║
        \\╚══════════════════════════════════════════╝
        \\
    , .{
        iterations,
        elapsed_ns / std.time.ns_per_ms,
        avg_ns,
        cycles,
        avg_cycles,
        avg_instrs,
        ipc_x100 / 100,
        ipc_x100 % 100,
        crefs,
        cmiss,
        cmiss_pct,
        branches,
        bmiss,
        bmiss_pct,
    });
}
