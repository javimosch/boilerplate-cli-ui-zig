const std = @import("std");
const Io = std.Io;
const http = std.http;
const mem = std.mem;
const g = @import("guide.zig");

// ─── Embedded UI Files ──────────────────────────────────────────
const index_html = @embedFile("ui/index.html");
const app_js = @embedFile("ui/js/app.js");
const styles_css = @embedFile("ui/css/styles.css");
const tailwind_css = @embedFile("ui/css/tailwind.css");
const app_layout_js = @embedFile("ui/js/components/AppLayout.js");
const sidebar_js = @embedFile("ui/js/components/Sidebar.js");
const status_card_js = @embedFile("ui/js/components/StatusCard.js");
const dashboard_js = @embedFile("ui/js/views/Dashboard.js");
const settings_js = @embedFile("ui/js/views/Settings.js");

// ─── Embedded Vendor Files (self-contained, no CDN) ────────────
const vue_js = @embedFile("ui/vendor/vue.global.prod.js");
const lucide_js = @embedFile("ui/vendor/lucide.js");

const VERSION = g.VERSION;
const TOOL = g.TOOL;
const DEFAULT_PORT: u16 = 8080;
const DEFAULT_HOST = "127.0.0.1";

const PID_FILE = "/tmp/boilerplate-cli-ui-zig.pid";
const LOG_FILE = "/tmp/boilerplate-cli-ui-zig.log";

// Semantic exit codes (cli-output-spec §2).
const EXIT_MISSING_ARG: u8 = 80;
const EXIT_UNKNOWN_COMMAND: u8 = 85;
const EXIT_PRECONDITION: u8 = 90;
const EXIT_EXTERNAL: u8 = 100;
const EXIT_INTERNAL: u8 = 110;

/// Environment access. std 0.16 has no std.posix.getenv; the environment
/// arrives through std.process.Init instead, so main stashes it here.
var env_map: ?*std.process.Environ.Map = null;

fn getEnv(name: []const u8) ?[]const u8 {
    const m = env_map orelse return null;
    const v = m.get(name) orelse return null;
    return if (v.len == 0) null else v;
}

/// The host the server actually bound. `/_shutdown` is token-gated whenever
/// this is not loopback (cli-daemon-spec §3).
var bound_host_buf: [64]u8 = undefined;
var bound_host: []const u8 = DEFAULT_HOST;

// ─── Output helpers ─────────────────────────────────────────────

fn out(io: Io, s: []const u8) void {
    Io.File.stdout().writeStreamingAll(io, s) catch {};
}

/// Context goes to stderr so stdout carries only data (cli-output-spec §1).
fn err(io: Io, s: []const u8) void {
    Io.File.stderr().writeStreamingAll(io, s) catch {};
}

fn outf(io: Io, comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    out(io, s);
}

fn errf(io: Io, comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
    err(io, s);
}

/// Emits a typed error on stdout and exits with the matching code. The exit
/// status and `.error.code` are the same number by construction (§2, §3).
fn die(io: Io, code: u8, etype: []const u8, message: []const u8, suggestion: []const u8) noreturn {
    const recoverable = code >= 100 and code <= 109;
    outf(io,
        \\{{"ok":false,"error":{{"code":{d},"type":"{s}","message":"{s}","recoverable":{},"suggestions":["{s}"]}}}}
        \\
    , .{ code, etype, message, recoverable, suggestion });
    std.process.exit(code);
}

// ─── Loopback HTTP client (health probe / shutdown) ─────────────
//
// A hand-rolled HTTP/1.0 request over a TCP stream rather than a client
// dependency: it is one request/response on loopback, and this boilerplate is a
// binary-size comparison instrument.

fn loopbackRequest(io: Io, port: u16, request: []const u8, response: []u8) ?usize {
    const addr = Io.net.IpAddress.parse("127.0.0.1", port) catch return null;
    const stream = Io.net.IpAddress.connect(&addr, io, .{ .mode = .stream }) catch return null;
    defer stream.close(io);

    var send_buf: [1024]u8 = undefined;
    var writer = stream.writer(io, &send_buf);
    writer.interface.writeAll(request) catch return null;
    writer.interface.flush() catch return null;

    var recv_buf: [4096]u8 = undefined;
    var reader = stream.reader(io, &recv_buf);
    const n = reader.interface.readSliceShort(response) catch return null;
    return n;
}

fn probeHealth(io: Io, port: u16) bool {
    var req_buf: [256]u8 = undefined;
    const req = std.fmt.bufPrint(&req_buf, "GET /_health HTTP/1.0\r\nHost: 127.0.0.1:{d}\r\n\r\n", .{port}) catch return false;
    var resp: [1024]u8 = undefined;
    const n = loopbackRequest(io, port, req, &resp) orelse return false;
    return mem.indexOf(u8, resp[0..n], " 200") != null;
}

/// Polls every 100ms for up to 5s, rather than sleeping a fixed amount and
/// hoping (cli-daemon-spec §4).
fn waitFor(io: Io, port: u16, want: bool) bool {
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        if (probeHealth(io, port) == want) return true;
        Io.sleep(io, .fromMilliseconds(100), .awake) catch return false;
    }
    return false;
}

// ─── Request handling ───────────────────────────────────────────

fn respondJson(request: *http.Server.Request, body: []const u8, status: http.Status) !void {
    try request.respond(body, .{
        .status = status,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "connection", .value = "close" },
        },
    });
}

fn isLoopback(host: []const u8) bool {
    return mem.eql(u8, host, "127.0.0.1") or
        mem.eql(u8, host, "localhost") or
        mem.eql(u8, host, "::1");
}

/// Off-loopback, an open shutdown route is a remote kill switch, so the request
/// must carry X-Shutdown-Token matching $SHUTDOWN_TOKEN (§3).
fn shutdownAuthorized(request: *http.Server.Request, io: Io) bool {
    _ = io;
    if (isLoopback(bound_host)) return true;

    const token = getEnv("SHUTDOWN_TOKEN") orelse return false;
    if (token.len == 0) return false;

    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "x-shutdown-token")) {
            return mem.eql(u8, h.value, token);
        }
    }
    return false;
}

fn handleRequest(request: *http.Server.Request, start_time: *Io.Timestamp, port: u16, io: Io) !void {
    const path = request.head.target;

    // ── Daemon lifecycle (cli-daemon-spec §2, §3) ──
    if (mem.eql(u8, path, "/_health")) {
        var buf: [256]u8 = undefined;
        const body = std.fmt.bufPrint(&buf,
            \\{{"ok":true,"service":"{s}","pid":{d},"port":{d}}}
        , .{ TOOL, std.os.linux.getpid(), port }) catch "{\"ok\":true}";
        try respondJson(request, body, .ok);
        return;
    }

    if (mem.eql(u8, path, "/_shutdown")) {
        if (request.head.method != .POST) {
            try respondJson(request,
                \\{"ok":false,"error":{"code":85,"type":"method_not_allowed","message":"POST /_shutdown","recoverable":false}}
            , .method_not_allowed);
            return;
        }
        if (!shutdownAuthorized(request, io)) {
            // 403, and the process MUST NOT stop.
            try respondJson(request,
                \\{"ok":false,"error":{"code":90,"type":"forbidden","message":"X-Shutdown-Token required when bound off-loopback","recoverable":false}}
            , .forbidden);
            return;
        }
        // Answer before exiting, so the caller learns the request was accepted.
        try respondJson(request,
            \\{"ok":true,"stopping":true}
        , .ok);
        Io.Dir.cwd().deleteFile(io, PID_FILE) catch {};
        std.process.exit(0);
    }

    // ── The guide over HTTP (cli-guide-spec §3) ──
    if (mem.eql(u8, path, "/guide")) {
        try respondJson(request, g.guide_json, .ok);
        return;
    }
    if (mem.eql(u8, path, "/llms.txt")) {
        try request.respond(g.llms_txt, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain; charset=utf-8" },
                .{ .name = "connection", .value = "close" },
            },
        });
        return;
    }

    // ── App API ──
    if (mem.eql(u8, path, "/api/status")) {
        const now = Io.Timestamp.now(io, .awake);
        const elapsed_ns = now.nanoseconds - start_time.nanoseconds;
        const elapsed_s = @as(i64, @intCast(@divTrunc(elapsed_ns, @as(i96, std.time.ns_per_s))));
        var uptime_buf: [32]u8 = undefined;
        const uptime = formatUptime(elapsed_s, &uptime_buf);

        var buf: [256]u8 = undefined;
        const body = std.fmt.bufPrint(&buf,
            \\{{"status":"running","port":{},"uptime":"{s}","version":"{s}"}}
        , .{ port, uptime, VERSION }) catch "{}";

        try respondJson(request, body, .ok);
        return;
    }

    if (mem.eql(u8, path, "/api/health")) {
        var buf: [256]u8 = undefined;
        const body = std.fmt.bufPrint(&buf,
            \\{{"ok":true,"service":"{s}","pid":{d},"port":{d}}}
        , .{ TOOL, std.os.linux.getpid(), port }) catch "{\"ok\":true}";
        try respondJson(request, body, .ok);
        return;
    }

    // ── Static UI Files ──
    inline for (&.{
        .{ .path = "/", .content = index_html, .mime = "text/html" },
        .{ .path = "/js/app.js", .content = app_js, .mime = "application/javascript" },
        .{ .path = "/css/styles.css", .content = styles_css, .mime = "text/css" },
        .{ .path = "/js/components/AppLayout.js", .content = app_layout_js, .mime = "application/javascript" },
        .{ .path = "/js/components/Sidebar.js", .content = sidebar_js, .mime = "application/javascript" },
        .{ .path = "/js/components/StatusCard.js", .content = status_card_js, .mime = "application/javascript" },
        .{ .path = "/js/views/Dashboard.js", .content = dashboard_js, .mime = "application/javascript" },
        .{ .path = "/js/views/Settings.js", .content = settings_js, .mime = "application/javascript" },
        .{ .path = "/vendor/vue.global.prod.js", .content = vue_js, .mime = "application/javascript" },
        .{ .path = "/vendor/lucide.js", .content = lucide_js, .mime = "application/javascript" },
        .{ .path = "/css/tailwind.css", .content = tailwind_css, .mime = "text/css" },
    }) |file| {
        if (mem.eql(u8, path, file.path)) {
            try request.respond(file.content, .{
                .extra_headers = &.{
                    .{ .name = "content-type", .value = file.mime },
                    .{ .name = "cache-control", .value = "no-cache, no-store, must-revalidate" },
                    .{ .name = "connection", .value = "close" },
                },
            });
            return;
        }
    }

    // ── 404 ──
    try request.respond("Not found", .{
        .status = .not_found,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "text/plain" },
            .{ .name = "connection", .value = "close" },
        },
    });
}

fn formatUptime(seconds: i64, buf: []u8) []const u8 {
    const hours = @divTrunc(seconds, 3600);
    const minutes = @divTrunc(@rem(seconds, 3600), 60);
    const secs = @rem(seconds, 60);

    if (hours > 0) {
        return std.fmt.bufPrint(buf, "{d}h{d}m{d}s", .{ hours, minutes, secs }) catch "0s";
    } else if (minutes > 0) {
        return std.fmt.bufPrint(buf, "{d}m{d}s", .{ minutes, secs }) catch "0s";
    } else {
        return std.fmt.bufPrint(buf, "{d}s", .{secs}) catch "0s";
    }
}

// ─── Server ─────────────────────────────────────────────────────

fn serve(io: Io, host: []const u8, port: u16) !void {
    // Bind the requested host, not 0.0.0.0: a server told to serve localhost
    // must not be reachable from the whole network (cli-daemon-spec §1).
    const address = Io.net.IpAddress.parse(host, port) catch {
        die(io, EXIT_MISSING_ARG, "bad_flag_value", "--host is not a valid IP address", "boilerplate-cli-ui-zig serve --host 127.0.0.1");
    };
    var server = address.listen(io, .{ .reuse_address = true }) catch {
        var msg: [128]u8 = undefined;
        const m = std.fmt.bufPrint(&msg, "cannot bind {s}:{d}", .{ host, port }) catch "cannot bind";
        die(io, EXIT_PRECONDITION, "port_unavailable", m, "boilerplate-cli-ui-zig serve --port 8081");
    };
    defer server.deinit(io);

    @memcpy(bound_host_buf[0..host.len], host);
    bound_host = bound_host_buf[0..host.len];

    // Startup lines are context — stderr, never stdout (§1).
    errf(io, "{s} serving on http://{s}:{d}/\n", .{ TOOL, host, port });
    errf(io, "  API: http://{s}:{d}/api/status\n", .{ host, port });

    var start_time = Io.Timestamp.now(io, .awake);

    while (true) {
        const stream = server.accept(io) catch |e| switch (e) {
            error.Canceled => return,
            else => continue,
        };
        defer stream.close(io);

        var recv_buf: [65536]u8 = undefined;
        var send_buf: [65536]u8 = undefined;
        var conn_reader = stream.reader(io, &recv_buf);
        var conn_writer = stream.writer(io, &send_buf);

        var http_conn = http.Server.init(&conn_reader.interface, &conn_writer.interface);

        while (http_conn.reader.state == .ready) {
            var request = http_conn.receiveHead() catch break;
            handleRequest(&request, &start_time, port, io) catch break;
        }
    }
}

// ─── Daemon (cli-daemon-spec §4) ────────────────────────────────
//
// /_health is the source of truth for liveness, not the pid file, which goes
// stale when a process dies without cleaning up. Every subcommand is idempotent.

fn selfExePath(io: Io, buf: []u8) ![]const u8 {
    // std 0.16 has no selfExePath; /proc/self/exe is the Linux answer.
    const n = try Io.Dir.cwd().readLink(io, "/proc/self/exe", buf);
    return buf[0..n];
}

fn daemonStart(io: Io, gpa: std.mem.Allocator, host: []const u8, port: u16) void {
    if (probeHealth(io, port)) {
        outf(io,
            \\{{"ok":true,"running":true,"already_running":true,"port":{d}}}
            \\
        , .{port});
        return;
    }

    var exe_buf: [4096]u8 = undefined;
    const exe = selfExePath(io, &exe_buf) catch {
        die(io, EXIT_INTERNAL, "no_executable_path", "cannot resolve own path via /proc/self/exe", "run the binary by an absolute path");
    };

    const log = Io.Dir.cwd().createFile(io, LOG_FILE, .{ .truncate = false }) catch {
        die(io, EXIT_PRECONDITION, "log_unwritable", "cannot open " ++ LOG_FILE, "check permissions on /tmp");
    };
    defer log.close(io);

    var host_arg_buf: [96]u8 = undefined;
    var port_arg_buf: [32]u8 = undefined;
    const host_arg = std.fmt.bufPrint(&host_arg_buf, "--host={s}", .{host}) catch unreachable;
    const port_arg = std.fmt.bufPrint(&port_arg_buf, "--port={d}", .{port}) catch unreachable;

    var child = std.process.spawn(io, .{
        .argv = &.{ exe, "serve", host_arg, port_arg },
        .stdin = .ignore,
        .stdout = .{ .file = log },
        .stderr = .{ .file = log },
        // Its own process group: the daemon must outlive the shell that started it.
        .pgid = 0,
    }) catch {
        die(io, EXIT_INTERNAL, "spawn_failed", "cannot start the daemon", "boilerplate-cli-ui-zig serve");
    };
    _ = gpa;

    // child.id is optional on platforms where a pid is not meaningful.
    const pid: i32 = child.id orelse 0;
    writePid(io, pid);

    if (!waitFor(io, port, true)) {
        child.kill(io);
        Io.Dir.cwd().deleteFile(io, PID_FILE) catch {};
        die(io, EXIT_EXTERNAL, "daemon_unhealthy", "started but /_health never answered (see " ++ LOG_FILE ++ ")", "boilerplate-cli-ui-zig serve");
    }

    outf(io,
        \\{{"ok":true,"running":true,"already_running":false,"pid":{d},"port":{d},"log":"{s}"}}
        \\
    , .{ pid, port, LOG_FILE });
}

fn daemonStop(io: Io, port: u16) void {
    if (!probeHealth(io, port)) {
        // A no-op success: an agent stopping an already-stopped daemon has got
        // what it asked for (§4).
        Io.Dir.cwd().deleteFile(io, PID_FILE) catch {};
        outf(io,
            \\{{"ok":true,"running":false,"stopped":false,"port":{d}}}
            \\
        , .{port});
        return;
    }

    var req_buf: [512]u8 = undefined;
    const token = getEnv("SHUTDOWN_TOKEN") orelse "";
    const req = if (token.len > 0)
        std.fmt.bufPrint(&req_buf, "POST /_shutdown HTTP/1.0\r\nHost: 127.0.0.1:{d}\r\nX-Shutdown-Token: {s}\r\nContent-Length: 0\r\n\r\n", .{ port, token }) catch unreachable
    else
        std.fmt.bufPrint(&req_buf, "POST /_shutdown HTTP/1.0\r\nHost: 127.0.0.1:{d}\r\nContent-Length: 0\r\n\r\n", .{port}) catch unreachable;

    var resp: [1024]u8 = undefined;
    const n = loopbackRequest(io, port, req, &resp) orelse {
        die(io, EXIT_EXTERNAL, "shutdown_failed", "POST /_shutdown failed", "boilerplate-cli-ui-zig daemon status");
    };

    if (mem.indexOf(u8, resp[0..n], " 200") == null) {
        die(io, EXIT_EXTERNAL, "shutdown_refused", "POST /_shutdown was refused", "set SHUTDOWN_TOKEN if the daemon is bound off-loopback");
    }

    _ = waitFor(io, port, false);
    Io.Dir.cwd().deleteFile(io, PID_FILE) catch {};
    outf(io,
        \\{{"ok":true,"running":false,"stopped":true,"port":{d}}}
        \\
    , .{port});
}

fn daemonStatus(io: Io, port: u16) void {
    // Status only ever reads — it never carries the shutdown token (§4).
    if (!probeHealth(io, port)) {
        outf(io,
            \\{{"ok":true,"running":false,"port":{d}}}
            \\
        , .{port});
        return;
    }
    outf(io,
        \\{{"ok":true,"running":true,"pid":{d},"port":{d},"log":"{s}"}}
        \\
    , .{ readPid(io), port, LOG_FILE });
}

fn writePid(io: Io, pid: i32) void {
    const f = Io.Dir.cwd().createFile(io, PID_FILE, .{}) catch return;
    defer f.close(io);
    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{pid}) catch return;
    var wbuf: [64]u8 = undefined;
    var w = f.writer(io, &wbuf);
    w.interface.writeAll(s) catch {};
    w.interface.flush() catch {};
}

fn readPid(io: Io) i32 {
    const f = Io.Dir.cwd().openFile(io, PID_FILE, .{}) catch return 0;
    defer f.close(io);
    var buf: [32]u8 = undefined;
    var rbuf: [64]u8 = undefined;
    var r = f.reader(io, &rbuf);
    const n = r.interface.readSliceShort(&buf) catch return 0;
    return std.fmt.parseInt(i32, mem.trim(u8, buf[0..n], " \n\r"), 10) catch 0;
}

// ─── Help ───────────────────────────────────────────────────────

fn printHelp(io: Io) void {
    err(io,
        \\boilerplate-cli-ui-zig - Zig CLI with an embedded web UI
        \\
        \\Usage:
        \\  boilerplate-cli-ui-zig <command> [options]
        \\
        \\Commands:
        \\  serve [--host H] [--port N]   run the HTTP server in the foreground
        \\  daemon start [--port N]       start it in the background
        \\  daemon stop [--port N]        stop the background server
        \\  daemon status [--port N]      report background server status
        \\  guide [--human]               the embedded operator guide
        \\  help-json                     machine-readable command catalog
        \\  version [--json]              show version information
        \\  help                          show this help message
        \\
        \\Endpoints:
        \\  GET  /            Web UI
        \\  GET  /api/status  Server status (JSON)
        \\  GET  /_health     Liveness: {ok,service,pid}
        \\  POST /_shutdown   Stop the server (token-gated off-loopback)
        \\
        \\Exit codes: 0 ok, 80-89 input, 90-99 state, 100-109 external, 110-119 internal
        \\
    );
}

// ─── Main ───────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    env_map = init.environ_map;

    var args_iter = try init.minimal.args.iterateAllocator(gpa);
    defer args_iter.deinit();
    _ = args_iter.next(); // program name

    var argv: [32][]const u8 = undefined;
    var argc: usize = 0;
    while (args_iter.next()) |a| {
        if (argc == argv.len) break;
        argv[argc] = a;
        argc += 1;
    }
    const args = argv[0..argc];

    if (args.len == 0) {
        printHelp(io);
        std.process.exit(EXIT_MISSING_ARG);
    }

    const cmd = args[0];
    const rest = args[1..];

    if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "--help") or mem.eql(u8, cmd, "-h")) {
        printHelp(io);
        return;
    }

    if (mem.eql(u8, cmd, "version")) {
        if (hasFlag(rest, "--json")) {
            outf(io, "{{\"version\":\"{s}\",\"name\":\"{s}\"}}\n", .{ VERSION, TOOL });
        } else {
            outf(io, "{s} v{s}\n", .{ TOOL, VERSION });
        }
        return;
    }

    if (mem.eql(u8, cmd, "guide")) {
        if (hasFlag(rest, "--human")) {
            out(io, g.guide_markdown);
        } else {
            out(io, g.guide_json);
            out(io, "\n");
        }
        return;
    }

    if (mem.eql(u8, cmd, "help-json")) {
        out(io, g.help_json);
        out(io, "\n");
        return;
    }

    if (mem.eql(u8, cmd, "serve") or mem.eql(u8, cmd, "start")) {
        const host = flagValue(rest, "--host") orelse flagValue(rest, "-host") orelse
            (getEnv("HOST") orelse DEFAULT_HOST);
        const port = resolvePort(io, rest);
        if (mem.eql(u8, cmd, "start") and (hasFlag(rest, "-daemon") or hasFlag(rest, "--daemon"))) {
            daemonStart(io, gpa, host, port);
            return;
        }
        try serve(io, host, port);
        return;
    }

    if (mem.eql(u8, cmd, "daemon")) {
        if (rest.len == 0) {
            die(io, EXIT_MISSING_ARG, "missing_argument", "daemon needs a subcommand: start, stop or status", "boilerplate-cli-ui-zig daemon status");
        }
        const sub = rest[0];
        const tail = rest[1..];
        const host = flagValue(tail, "--host") orelse DEFAULT_HOST;
        const port = resolvePort(io, tail);

        if (mem.eql(u8, sub, "start")) {
            daemonStart(io, gpa, host, port);
        } else if (mem.eql(u8, sub, "stop")) {
            daemonStop(io, port);
        } else if (mem.eql(u8, sub, "status")) {
            daemonStatus(io, port);
        } else {
            die(io, EXIT_UNKNOWN_COMMAND, "unknown_command", "unknown daemon subcommand", "boilerplate-cli-ui-zig daemon status");
        }
        return;
    }

    // Back-compat aliases for the pre-spec command names.
    if (mem.eql(u8, cmd, "stop")) {
        daemonStop(io, resolvePort(io, rest));
        return;
    }
    if (mem.eql(u8, cmd, "status")) {
        daemonStatus(io, resolvePort(io, rest));
        return;
    }

    die(io, EXIT_UNKNOWN_COMMAND, "unknown_command", "unknown command", "boilerplate-cli-ui-zig help-json");
}

fn hasFlag(args: []const []const u8, name: []const u8) bool {
    for (args) |a| {
        if (mem.eql(u8, a, name)) return true;
    }
    return false;
}

/// Reads `--name value` or `--name=value`.
fn flagValue(args: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (mem.eql(u8, args[i], name) and i + 1 < args.len) return args[i + 1];
        if (args[i].len > name.len + 1 and
            mem.startsWith(u8, args[i], name) and
            args[i][name.len] == '=')
        {
            return args[i][name.len + 1 ..];
        }
    }
    return null;
}

fn resolvePort(io: Io, args: []const []const u8) u16 {
    const s = flagValue(args, "--port") orelse flagValue(args, "-port") orelse
        flagValue(args, "-p") orelse (getEnv("PORT") orelse return DEFAULT_PORT);
    return std.fmt.parseInt(u16, s, 10) catch {
        die(io, EXIT_MISSING_ARG, "bad_flag_value", "--port must be a number", "boilerplate-cli-ui-zig serve --port 8080");
    };
}
