const std = @import("std");
const Io = std.Io;
const http = std.http;
const mem = std.mem;

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

const VERSION = "1.0.0";
const DEFAULT_PORT = 8080;

fn printHelp(io: Io) void {
    Io.File.stdout().writeStreamingAll(io,
        \\boilerplate-cli-ui-zig - Zig CLI with embedded web UI
        \\
        \\Usage:
        \\  boilerplate-cli-ui-zig <command> [options]
        \\
        \\Commands:
        \\  start       Start HTTP server with web UI
        \\  version     Show version information
        \\  help        Show this help message
        \\
        \\Start Options:
        \\  -p, --port PORT  Port for HTTP server (default 8080)
        \\
        \\API Endpoints:
        \\  GET /            Web UI
        \\  GET /api/status  Server status (JSON)
        \\  GET /api/health  Health check (JSON)
        \\
    ) catch {};
}

// ─── Request Handler ────────────────────────────────────────────
fn handleRequest(request: *http.Server.Request, start_time: *Io.Timestamp, io: Io) !void {
    const path = request.head.target;

    // ── API Endpoints ──
    if (mem.eql(u8, path, "/api/status")) {
        const now = Io.Timestamp.now(io, .awake);
        const elapsed_ns = now.nanoseconds - start_time.nanoseconds;
        const elapsed_s = @as(i64, @intCast(@divTrunc(elapsed_ns, @as(i96, std.time.ns_per_s))));
        var uptime_buf: [32]u8 = undefined;
        const uptime = formatUptime(elapsed_s, &uptime_buf);

        var buf: [256]u8 = undefined;
        const body = std.fmt.bufPrint(&buf,
            \\{{"status":"running","port":{},"uptime":"{s}","version":"{s}"}}
        , .{ DEFAULT_PORT, uptime, VERSION }) catch "{}";

        try request.respond(body, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "cache-control", .value = "no-cache, no-store, must-revalidate" },
                .{ .name = "connection", .value = "close" },
            },
        });
        return;
    }

    if (mem.eql(u8, path, "/api/health")) {
        try request.respond(
            \\{"status":"healthy","version":"1.0.0"}
        , .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
                .{ .name = "connection", .value = "close" },
            },
        });
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

fn formatUptime(seconds: i64, out: []u8) []const u8 {
    const hours = @divTrunc(seconds, 3600);
    const minutes = @divTrunc(@rem(seconds, 3600), 60);
    const secs = @rem(seconds, 60);

    if (hours > 0) {
        return std.fmt.bufPrint(out, "{d}h{d}m{d}s", .{ hours, minutes, secs }) catch "0s";
    } else if (minutes > 0) {
        return std.fmt.bufPrint(out, "{d}m{d}s", .{ minutes, secs }) catch "0s";
    } else {
        return std.fmt.bufPrint(out, "{d}s", .{secs}) catch "0s";
    }
}

fn printlnString(io: Io, str: []const u8) void {
    Io.File.stdout().writeStreamingAll(io, str) catch {};
}

fn printlnFormatted(io: Io, comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, fmt, args) catch return;
    Io.File.stdout().writeStreamingAll(io, formatted) catch {};
}

// ─── Main ───────────────────────────────────────────────────────
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    // Parse command line args
    var args_iter = try init.minimal.args.iterateAllocator(gpa);
    defer args_iter.deinit();

    // Skip program name
    _ = args_iter.next();

    var command: []const u8 = "help";
    var port: u16 = DEFAULT_PORT;

    while (args_iter.next()) |arg| {
        if (mem.eql(u8, arg, "start")) {
            command = "start";
        } else if (mem.eql(u8, arg, "version")) {
            command = "version";
        } else if (mem.eql(u8, arg, "help")) {
            command = "help";
        } else if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--port")) {
            if (args_iter.next()) |port_str| {
                port = std.fmt.parseInt(u16, port_str, 10) catch DEFAULT_PORT;
            }
        }
    }

    if (mem.eql(u8, command, "help")) {
        printHelp(io);
        return;
    }

    if (mem.eql(u8, command, "version")) {
        Io.File.stdout().writeStreamingAll(io, "boilerplate-cli-ui-zig v" ++ VERSION ++ "\n") catch {};
        return;
    }

    // ─── Start HTTP Server ─────────────────────────────────────
    const address = try Io.net.IpAddress.parse("0.0.0.0", port);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    printlnFormatted(io, "Server starting on http://localhost:{d}/\n", .{port});
    printlnFormatted(io, "UI available at http://localhost:{d}/\n", .{port});
    printlnFormatted(io, "API available at http://localhost:{d}/api/status\n", .{port});
    printlnString(io, "Press Ctrl+C to stop\n");

    var start_time = Io.Timestamp.now(io, .awake);

    // Single-threaded accept loop
    while (true) {
        const stream = server.accept(io) catch |err| switch (err) {
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
            var request = http_conn.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => break,
                else => break,
            };

            handleRequest(&request, &start_time, io) catch {
                break;
            };
        }
    }
}
