// Chassis for eth-camera: snap-together tray (back) + lid (front).
// Units: mm. Datum: same as board.scad (corner of the perfboard front face,
// antenna short edge / switch long edge; X to RJ45, Y to terminal, Z to lens).
//
// The tray holds the perfboard on 4 pegs through its M2 holes. The lid
// clamps it down with 4 tabs and snaps onto a lip on the tray rim.
// The parting plane runs through the power cable, which is clamped between
// the two halves.
// Print: tray floor-down, lid front-face-down. No supports needed.

board_included = true;
include <BOSL2/std.scad>
include <board.scad>

part = "exploded"; // assembly | exploded | tray | lid | board | none

// --- Shell -----------------------------------------------------------------
wall    = 2.4;   // wall thickness
gap     = 1.0;   // free space around the board envelope
round_r = 3;     // outer edge rounding
$slop   = 0.15;  // fit clearance per side
eps     = 0.01;

in_x0 = env_x0 - gap;
in_x1 = rj_x1 + 0.3;        // RJ45 mouth just inside the X+ wall
in_y0 = env_y0 - 0.5;       // envelope already includes the edge wires
in_y1 = env_y1 + 0.5;
in_z0 = env_z0 - gap;
in_z1 = env_z1 + gap;

out_x0 = in_x0 - wall;  out_x1 = in_x1 + wall;
out_y0 = in_y0 - wall;  out_y1 = in_y1 + wall;
out_z0 = in_z0 - wall;  out_z1 = in_z1 + wall;

split_z = cable_z;  // tray/lid parting plane, through the cable axis

// --- Lip + snaps -----------------------------------------------------------
lip_t = 1.0;   // tray lip thickness (inner part of the wall)
lip_h = 3;     // lip height above the parting plane
snap_r     = 0.6;   // snap ridge radius
snap_proud = 0.4;   // how far the ridge sticks out of the lip
snap_len   = 10;
snap_z     = split_z + lip_h / 2;
snap_x_on_y = 42;   // X of the ridges on both long walls
snap_y_on_x0 = 20;  // Y of the ridge on the antenna-end wall
snap_y_on_x1 = 15;  // Y of the ridge on the RJ45-end wall (below the jack)

// --- Board support ---------------------------------------------------------
post_d  = 4.4;                      // post under each corner hole
peg_d   = pb_hole_d - 2 * $slop;    // peg through the M2 hole
peg_top = -0.2;                     // peg tip Z, just below the board face (front parts may sit over the holes)
web_t   = 1.6;                      // web from post to the long wall
tab_x   = [[0.2, 4], [56.5, 60.3]]; // lid hold-down tabs, X ranges
tab_over = 1.0;                     // tab reach onto the board edge

// --- Openings --------------------------------------------------------------
// Front window over lens, LED and serial header. The meter mount closes it,
// so it must stay inside the mount's bearing rim on the lid top.
top_win   = [-2, 34, 1.1, 37];  // x0, x1, y0, y1
top_win_r = 2;     // corner radius
top_rim   = 5;     // min lid top left round the window (mount bears on it)
cam_ap_r = 1.5;    // lens aperture radius (est)
fov_half = 35;     // half view angle incl. margin (OV3660 ~66 deg diag)
chim_t   = 1.2;    // reset guide tube wall
rj_clr   = 0.4;    // RJ45 opening clearance per side
sw_win   = 6;      // switch window width along X
sw_win_top = sw_lever_h + 1.5;
rst_hole_d = 2.5;  // reset access hole (poke with a pin)
rst_guide_gap = 2.5;  // guide tube stops this far below the button
vent_l = 10;   vent_h = 3.0;  // slot length, slot height
vent_x = [-1, 13];  // slot centres along X, both long walls
vent_z = [16, 21];  // rows 2 mm apart

// --- Cable clamp -----------------------------------------------------------
cable_ch_d = cable_d - 0.3;  // channel: light squeeze on the sheath
cable_rib_d = cable_d - 0.9; // two ribs bite into the sheath
boss_l = 7;  boss_w = 8;  boss_h = 8;
cable_lift = 0.5;  // lid channel: this much higher and 0.1 wider than the cable

// Derived
view_r = cam_ap_r + (out_z1 - lens_top) * tan(fov_half);  // view cone at the lid face
rst_cx = (rst_x0 + rst_x1) / 2;
rst_cy = (rst_y0 + rst_y1) / 2;
rst_guide_top = -pb_t - rst_h - rst_guide_gap;
holes = [for (x = [pb_hole_off, pb_x - pb_hole_off],
              y = [pb_hole_off, pb_y - pb_hole_off]) [x, y]];

assert(top_win[0] >= out_x0 + top_rim && top_win[1] <= out_x1 - top_rim &&
       top_win[2] >= out_y0 + top_rim && top_win[3] <= out_y1 - top_rim,
       "front window cuts into the rim the meter mount sits on");
assert(top_win[0] < lens_x - view_r && top_win[1] > lens_x + view_r &&
       top_win[2] < lens_y - view_r && top_win[3] > lens_y + view_r,
       "front window clips the lens view");
assert(top_win[0] < min(led_x0, ser_x0) && top_win[2] < min(led_y0, ser_y0),
       "front window misses the LED or the serial header");
assert(rst_guide_top < -pb_t - wires_h, "reset guide hits the back wiring");
assert(split_z + lip_h + 2 < esp_pcb_top - esp_pcb_t, "tabs hit the ESP32-CAM");
echo(outer_size = [out_x1 - out_x0, out_y1 - out_y0, out_z1 - out_z0],
     front_window = [top_win[1] - top_win[0], top_win[3] - top_win[2]]);

$fn = 48;

module slab(z0, z1) {
    blk(out_x0 - 20, out_x1 + 20, out_y0 - 20, out_y1 + 20, z0, z1);
}

// Region between the cavity grown by off_in and by off_out.
module ring(off_in, off_out, z0, z1) {
    difference() {
        blk(in_x0 - off_out, in_x1 + off_out, in_y0 - off_out, in_y1 + off_out, z0, z1);
        blk(in_x0 - off_in, in_x1 + off_in, in_y0 - off_in, in_y1 + off_in, z0 - 1, z1 + 1);
    }
}

module shell() {
    difference() {
        union() {
            translate([out_x0, out_y0, out_z0])
                cuboid([out_x1 - out_x0, out_y1 - out_y0, out_z1 - out_z0],
                       rounding = round_r, anchor = LEFT + FRONT + BOTTOM);
            translate([out_x1 - 1, cable_y - boss_w / 2, split_z - boss_h / 2])
                cuboid([boss_l + 1, boss_w, boss_h], rounding = 1.5, except = LEFT,
                       anchor = LEFT + FRONT + BOTTOM);
        }
        blk(in_x0, in_x1, in_y0, in_y1, in_z0, in_z1);
    }
}

// Cable channel with two ribs. The lid uses a wider stadium-shaped channel,
// lifted by cable_lift, so only the ribs bite and the lid closes freely.
module cable_channel(d = cable_ch_d, lift = 0, stadium = false) {
    l = out_x1 + boss_l - in_x1 + 2;
    difference() {
        hull() {
            translate([in_x1 - 1, cable_y, split_z + lift]) rotate([0, 90, 0])
                cylinder(d = d, h = l);
            if (stadium)
                translate([in_x1 - 1, cable_y, split_z - 1]) rotate([0, 90, 0])
                    cylinder(d = d, h = l);
        }
        for (x = [out_x1 + 1.5, out_x1 + boss_l - 2])
            translate([x, cable_y, split_z]) rotate([0, 90, 0])
                difference() {
                    cylinder(d = cable_d + 4, h = 0.8);
                    translate([0, 0, -1]) cylinder(d = cable_rib_d, h = 3);
                }
    }
}

// Snap ridge positions: [centre, axis] on the lip's outer face.
module snap_ridges(r, len) {
    c = r - snap_proud;  // ridge centre sits this far inside the lip face
    for (y = [in_y0 - lip_t + c, in_y1 + lip_t - c])
        translate([snap_x_on_y - len / 2, y, snap_z]) rotate([0, 90, 0])
            cylinder(r = r, h = len);
    translate([in_x0 - lip_t + c, snap_y_on_x0 - len / 2, snap_z]) rotate([-90, 0, 0])
        cylinder(r = r, h = len);
    translate([in_x1 + lip_t - c, snap_y_on_x1 - len / 2, snap_z]) rotate([-90, 0, 0])
        cylinder(r = r, h = len);
}

module snap_windows() {
    w = snap_len + 2 * 0.3;
    zh = snap_r + 0.2;
    for (y = [[out_y0 - 1, in_y0 - lip_t + eps], [in_y1 + lip_t - eps, out_y1 + 1]])
        blk(snap_x_on_y - w / 2, snap_x_on_y + w / 2, y[0], y[1], snap_z - zh, snap_z + zh);
    blk(out_x0 - 1, in_x0 - lip_t + eps, snap_y_on_x0 - w / 2, snap_y_on_x0 + w / 2,
        snap_z - zh, snap_z + zh);
    blk(in_x1 + lip_t - eps, out_x1 + 1, snap_y_on_x1 - w / 2, snap_y_on_x1 + w / 2,
        snap_z - zh, snap_z + zh);
}

module tray() {
    difference() {
        union() {
            intersection() {
                shell();
                slab(out_z0 - 1, split_z);
            }
            // lip, with gaps for the switch windows and the cable
            difference() {
                ring(0, lip_t, split_z - eps, split_z + lip_h);
                blk(sw_x[0] - sw_win / 2 - 1, sw_x[1] + sw_win / 2 + 1,
                    in_y0 - lip_t - 1, in_y0 + 1, split_z - 1, split_z + lip_h + 1);
                blk(in_x1 - 1, in_x1 + lip_t + 1,
                    cable_y - cable_d / 2 - 1, cable_y + cable_d / 2 + 1,
                    split_z - 1, split_z + lip_h + 1);
            }
            snap_ridges(snap_r, snap_len);
            // board posts, pegs and webs to the long walls
            for (h = holes) {
                translate([h[0], h[1], in_z0 - eps]) cylinder(d = post_d, h = -pb_t - in_z0 + eps);
                translate([h[0], h[1], -pb_t - eps])
                    cylinder(d1 = peg_d, d2 = peg_d - 0.6, h = peg_top + pb_t + eps);
                low = h[1] < pb_y / 2;
                blk(h[0] - web_t / 2, h[0] + web_t / 2,
                    low ? in_y0 - eps : h[1], low ? h[1] : in_y1 + eps,
                    in_z0 - eps, -pb_t);
            }
            // reset guide tube
            translate([rst_cx, rst_cy, in_z0 - eps])
                cylinder(d = rst_hole_d + 2 * chim_t, h = rst_guide_top - in_z0 + eps);
        }
        cable_channel();
        translate([rst_cx, rst_cy, out_z0 - 1])
            cylinder(d = rst_hole_d, h = rst_guide_top - out_z0 + 2);
    }
}

module lid() {
    difference() {
        union() {
            difference() {
                intersection() {
                    shell();
                    slab(split_z, out_z1 + 1);
                }
                ring(0 - eps, lip_t + $slop, split_z - 1, split_z + lip_h + $slop);
            }
            // hold-down tabs on both long walls
            tz = split_z + lip_h + 2;
            for (t = tab_x) {
                blk(t[0], t[1], in_y0 + $slop, tab_over, 0, tz);
                blk(t[0], t[1], in_y0 - 0.5, in_y0 + $slop + eps, split_z + lip_h + $slop + eps, tz);
                blk(t[0], t[1], pb_y - tab_over, in_y1 - $slop, 0, tz);
                blk(t[0], t[1], in_y1 - $slop - eps, in_y1 + 0.5, split_z + lip_h + $slop + eps, tz);
            }
        }
        // front window: lens, LED and serial header, closed by the meter mount
        translate([top_win[0], top_win[2], in_z1 - 1])
            cuboid([top_win[1] - top_win[0], top_win[3] - top_win[2], out_z1 - in_z1 + 2],
                   rounding = top_win_r, edges = "Z", anchor = LEFT + FRONT + BOTTOM);
        // RJ45
        blk(in_x1 - 1, out_x1 + 1, rj_y0 - rj_clr, rj_y1 + rj_clr, rj_z0 - rj_clr, rj_z1 + rj_clr);
        // switch windows (tweezers), open at the parting plane
        for (cx = sw_x)
            blk(cx - sw_win / 2, cx + sw_win / 2, out_y0 - 1, in_y0 + 1, split_z - 1, sw_win_top);
        // vents
        for (x = vent_x, z = vent_z, y = [[out_y0 - 1, in_y0 + 1], [in_y1 - 1, out_y1 + 1]])
            blk(x - vent_l / 2, x + vent_l / 2, y[0], y[1], z - vent_h / 2, z + vent_h / 2);
        snap_windows();
        cable_channel(d = cable_d + 0.1, lift = cable_lift, stadium = true);
    }
}

if (part == "tray") tray();
else if (part == "lid") lid();
else if (part == "board") board();
else if (part == "exploded") {
    color("lightsteelblue") tray();
    translate([0, 0, 30]) color("lightsteelblue", 0.6) lid();
    translate([0, 0, 12]) board();
} else if (part == "assembly") {
    color("lightsteelblue") tray();
    color("lightsteelblue", 0.35) lid();
    board();
}
