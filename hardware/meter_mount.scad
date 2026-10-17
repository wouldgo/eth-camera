// Meter mount for eth-camera: a cone that joins the chassis lid to the dial
// capsule of a B Meters GSD8 water meter. It keeps lens and flash in the
// dark, at a fixed distance from the number rolls.
// Units: mm. Datum: same as board.scad / chassis.scad. Z points from the
// board towards the meter; the capsule's top (glass) faces -Z.
//
// The lid slides into a sleeve, and its rounded top edge sits on a 45 deg
// chamfer. The capsule's top edge sits on a 45 deg seat, and flexible fingers
// grip the cylindrical band below it; a cable tie or velcro strap in the outer
// groove tightens them.
// Capsule sizes come from the GSD8 datasheet drawing, whose scale checks
// out against H, L and B (about +-1 mm). The fingers absorb that.
//
// Print: either way up, no supports needed. Checked with the sleeve (lid side)
// on the bed.

include <chassis.scad>
part = "none";  // chassis.scad draws nothing

mount_part = "assembly"; // mount | assembly | meter

// --- Meter capsule (GSD8 datasheet, est +-1) -------------------------------
cap_top_d   = 64;    // transparent top cover
cap_top_h   = 5;     // height of the cover section
band_d      = 70;    // cylindrical band below it: the fingers grip here
band_h      = 7;
flare_d     = 74;    // B, widest point
flare_h     = 23;
rolls_depth = 7;     // number rolls below the top surface
rolls_off   = 15;    // roll window centre from the capsule axis
rolls_w     = 40;    // roll window size (est from the product photo)
rolls_h     = 7;
knob_d   = 11;       // silver x0.0001 bezel, sticks out of the top
knob_h   = 7;
knob_off = 16;

// --- Optics (standard OV3660 lens, 4:3, ~66 deg diagonal) ------------------
cone_h    = 60;      // lid front face to capsule top (glass). Tune for focus.
fov_long  = 55;      // full view angle, long image side
fov_short = 42.5;    // full view angle, short image side

// The dial turns 360 deg, so the roll direction only matters for this model:
// put the rolls on the side away from the LED, so the flash glint (about
// halfway between lens and LED) misses them, with the row parallel to the
// long side of the photo.
rolls_dir = 90;               // +Y, away from the LED
knob_dir  = rolls_dir + 180;  // the knob is opposite the rolls

// --- Mount -----------------------------------------------------------------
mw        = 2.4;    // wall
m_slop    = 0.2;    // sleeve clearance per side on the lid
sleeve_h  = 6;      // sleeve depth over the lid (stops above the vents)
ledge     = 1.5;    // the 45 deg bearing chamfer ends this far past the lid's rounding
rib_x     = [5, 30, 55];  // crush ribs on the long sleeve walls
rib_w     = 1;
rib_int   = 0.25;   // rib interference
rj_notch  = 0.6;    // clearance round the RJ45 opening

seat_in_r  = cap_top_d / 2 - 3;  // seat cone starts here...
skirt_in_r = band_d / 2 + 0.4;   // ...and ends here (sliding clearance)
finger_n    = 12;
finger_slot = 2;
finger_root = 3;    // slots start this far past the capsule top
bead        = 0.9;  // bead reach inside the skirt: 0.5 mm grip on the band
strap_w     = 5;    // outer groove for a cable tie / velcro strap
strap_d     = 0.8;

// Derived
cap_axis  = [lens_x, lens_y];  // the lens sits on the capsule axis
cap_top_z = out_z1 + cone_h;
view_dist = cap_top_z + rolls_depth - lens_top;  // lens face to number rolls
seat_z0   = cap_top_z - (cap_top_d / 2 - seat_in_r);       // seat bottom
seat_z1   = cap_top_z + (skirt_in_r - cap_top_d / 2);      // seat top
skirt_z1  = cap_top_z + cap_top_h + band_h;                // skirt end
bead_z    = cap_top_z + cap_top_h + band_h / 2;
skirt_out_r = skirt_in_r + mw;
sleeve_z0 = out_z1 - sleeve_h;
// The mount rests on the lid's rounded top edge through a 45 deg chamfer,
// touching where that rounding is at 45 deg.
bear_d  = round_r * (1 - cos(45));   // contact inset from the lid edge
bear_z  = out_z1 - round_r * (1 - sin(45));
// The chamfer is tangent to the pocket (the lid grown by m_slop), so the
// mount settles m_slop lower and the pocket's rounding never overhangs it.
cham_z0 = bear_z - bear_d;                             // chamfer starts at the pocket wall
cham_z1 = bear_z + (round_r + ledge - bear_d + m_slop); // and ends inside the lid top
lid_w = out_x1 - out_x0;
lid_d = out_y1 - out_y0;

half_long  = view_dist * tan(fov_long / 2);
half_short = view_dist * tan(fov_short / 2);
assert(half_short >= rolls_off + rolls_h / 2 + 1, "rolls fall off the short side of the photo");
assert(half_long >= rolls_w / 2 + 1, "rolls fall off the long side of the photo");
assert(sleeve_z0 > max(vent_z) + vent_h / 2, "sleeve covers the vents");
assert(knob_off + knob_d / 2 < seat_in_r, "knob hits the seat");
echo(cap_top_z = cap_top_z, view_dist = view_dist, mount_z = [sleeve_z0, skirt_z1],
     mount_height = skirt_z1 - sleeve_z0,
     field_at_rolls = [2 * half_long, 2 * half_short]);

$fn = 96;

// Rounded rectangle slab over the lid footprint, grown by `grow`.
module lid_rect(grow, z0, z1, r = round_r) {
    translate([out_x0 - grow, out_y0 - grow, z0])
        cuboid([lid_w + 2 * grow, lid_d + 2 * grow, z1 - z0],
               rounding = max(r + grow, 0.5), edges = "Z",
               anchor = LEFT + FRONT + BOTTOM);
}

module at_axis() {
    translate([cap_axis[0], cap_axis[1], 0]) children();
}

module polar(dir, r) {
    rotate([0, 0, dir]) translate([r, 0, 0]) children();
}

module meter() {
    at_axis() {
        color("lightcyan", 0.6) translate([0, 0, cap_top_z]) cylinder(d = cap_top_d, h = cap_top_h);
        color("navy") {
            translate([0, 0, cap_top_z + cap_top_h]) cylinder(d = band_d, h = band_h);
            translate([0, 0, cap_top_z + cap_top_h + band_h])
                cylinder(d1 = band_d, d2 = flare_d, h = flare_h);
        }
        color("silver")
            polar(knob_dir, knob_off) translate([0, 0, cap_top_z - knob_h])
                cylinder(d = knob_d, h = knob_h + eps);
        color("black")
            polar(rolls_dir, rolls_off) rotate([0, 0, rolls_dir])
                translate([-rolls_h / 2, -rolls_w / 2, cap_top_z + rolls_depth])
                    cube([rolls_h, rolls_w, 0.5]);
    }
}

module mount() {
    difference() {
        union() {
            // funnel from the sleeve straight out to the skirt: no step between
            // them, so the outside prints without supports either way up
            hull() {
                lid_rect(m_slop + mw, sleeve_z0, out_z1);
                at_axis() translate([0, 0, seat_z0 - mw]) cylinder(r = skirt_out_r, h = mw);
            }
            // seat and skirt
            at_axis() translate([0, 0, seat_z0 - mw])
                cylinder(r = skirt_out_r, h = skirt_z1 - seat_z0 + mw);
        }
        // lid pocket, then the 45 deg bearing chamfer (no flat overhang)
        lid_rect(m_slop, sleeve_z0 - 1, cham_z0 + eps);
        // the lid's own shape, grown sideways: clears its spherical corners,
        // where a straight chamfer would cut in
        translate([out_x0 - m_slop, out_y0 - m_slop, out_z0])
            cuboid([lid_w + 2 * m_slop, lid_d + 2 * m_slop, out_z1 - out_z0],
                   rounding = round_r, anchor = LEFT + FRONT + BOTTOM);
        hull() {
            lid_rect(m_slop, cham_z0, cham_z0 + eps);
            lid_rect(-(round_r + ledge), cham_z1, cham_z1 + eps);
        }
        // funnel inside: from the chamfer to the seat
        hull() {
            lid_rect(-(round_r + ledge), cham_z1 - eps, cham_z1 + eps);
            at_axis() translate([0, 0, seat_z0]) cylinder(r = seat_in_r, h = eps);
        }
        at_axis() {
            // 45 deg seat: the capsule's top edge centres itself on it
            translate([0, 0, seat_z0 - eps])
                cylinder(r1 = seat_in_r, r2 = skirt_in_r, h = seat_z1 - seat_z0 + 2 * eps);
            translate([0, 0, seat_z1]) cylinder(r = skirt_in_r, h = skirt_z1 - seat_z1 + 1);
            // finger slots
            for (i = [0 : finger_n - 1])
                rotate([0, 0, (i + 0.5) * 360 / finger_n])
                    translate([skirt_in_r - 1, -finger_slot / 2, cap_top_z + finger_root])
                        cube([mw + 2, finger_slot, skirt_z1 - cap_top_z]);
            // strap groove, 45 deg on the lid-side edge (no overhang)
            gz0 = bead_z - strap_w / 2;
            gz1 = bead_z + strap_w / 2;
            rotate_extrude()
                polygon([[skirt_out_r + 1, gz0], [skirt_out_r - strap_d, gz0],
                         [skirt_out_r - strap_d, gz1 - strap_d],
                         [skirt_out_r + eps, gz1], [skirt_out_r + 1, gz1]]);
        }
        // RJ45 opening on the X+ wall, open at the sleeve end
        blk(out_x1 - 1, out_x1 + m_slop + mw + 1,
            rj_y0 - rj_clr - rj_notch, rj_y1 + rj_clr + rj_notch,
            sleeve_z0 - 1, rj_z1 + rj_clr + rj_notch);
    }
    // inward bead on each finger: 45 deg on both sides
    at_axis() intersection() {
        translate([0, 0, bead_z])
            rotate_extrude()
                polygon([[skirt_in_r + eps, -bead], [skirt_in_r - bead, 0],
                         [skirt_in_r - bead, 0.3], [skirt_in_r + eps, 0.3 + bead]]);
        // keep it on the fingers, not across the slots
        for (i = [0 : finger_n - 1])
            rotate([0, 0, i * 360 / finger_n])
                translate([0, -(skirt_in_r * tan(180 / finger_n) - finger_slot / 2), bead_z - 5])
                    cube([skirt_in_r + 1, 2 * (skirt_in_r * tan(180 / finger_n) - finger_slot / 2), 10]);
    }
    // crush ribs on the long sleeve walls
    for (x = rib_x) {
        blk(x - rib_w / 2, x + rib_w / 2, out_y0 - m_slop - eps, out_y0 + rib_int,
            sleeve_z0, out_z1 - round_r);
        blk(x - rib_w / 2, x + rib_w / 2, out_y1 - rib_int, out_y1 + m_slop + eps,
            sleeve_z0, out_z1 - round_r);
    }
}

if (mount_part == "mount") mount();
else if (mount_part == "meter") meter();
else if (mount_part == "assembly") {
    color("lightsteelblue") tray();
    color("lightsteelblue") lid();
    board();
    color("dimgray", 0.5) mount();
    meter();
}
