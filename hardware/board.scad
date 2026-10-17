// eth-camera board assembly: perfboard + ESP32-CAM + W5500 + parts.
// Reference model used to size the chassis. Not printed.
//
// Units: mm. Datum: corner of the perfboard front face where the short
// (antenna) edge meets the long (switch) edge.
//   X along the 60.5 mm edge, towards the RJ45.
//   Y along the 40.3 mm edge, towards the screw terminal.
//   Z = 0 on the perfboard front face, + towards the lens.
// Back-side heights were measured from the perfboard back face.
//
// Values marked "est" come from photos, not calipers.

// --- Perfboard -------------------------------------------------------------
pb_x     = 60.5;  // perfboard length
pb_y     = 40.3;  // perfboard width
pb_t     = 1.6;   // perfboard thickness (est, standard FR4)
pb_hole_d   = 2.0;   // corner mounting hole diameter, M2
pb_hole_off = 2.0;   // hole centre to both edges (1 mm rim + radius)
wire_wrap   = 1.0;   // wires wrapped round the long edges stick out by this (est)

// --- ESP32-CAM (AI-Thinker, 27 x 40.5) ------------------------------------
esp_x0   = -7.5;  // antenna end overhangs the short edge
esp_len  = 40.5;
esp_wid  = 27;
esp_y0   = 11.5;  // est
esp_pcb_t   = 1.0;   // est
esp_pcb_top = 11.5;  // top face of the ESP32-CAM PCB
esp_hdr_w   = 2.5;   // female header strip width
esp_hdr_len = 8 * 2.54;  // 8-pin rows at the end away from the antenna
esp_hdr_end = 1;         // row end to the ESP32-CAM short edge (est)

lens_x   = 23.5;  // lens centre (est from "end of lens" 27.5 minus half barrel)
lens_y   = 26.5;  // lens centre (est from 30.5 minus half barrel)
lens_d   = 8;     // lens barrel outer diameter (est)
lens_top = 19;    // lens front face
cam_blk  = 9;     // camera holder square side (est)

led_x0 = 1.5; led_x1 = 4.5;  // flash LED footprint
led_y0 = 12;  led_y1 = 16;   // est
led_h  = 0.8;                // LED height above ESP PCB (est)

// --- W5500 module + RJ45 ---------------------------------------------------
w55_x0 = 36;   w55_x1 = 61;    // module PCB (est)
w55_y0 = 2;    w55_y1 = 27.5;  // est
w55_pcb_t = 1.6;               // est
rj_x0  = 38;   rj_x1  = 65.5;  // RJ45 body; mouth faces +X, 5 mm past the edge
rj_y0  = 7.5;  rj_y1  = 23.5;
rj_z0  = 12;   rj_z1  = 25.5;

// --- Screw terminal + power cable -----------------------------------------
term_x0 = 48;  term_x1 = 56;   // est
term_y0 = 30;  term_y1 = 40;
term_h  = 11;
cable_d = 3.5;
cable_y = 36;   // cable leaves the terminal towards +X (est)
cable_z = 4;    // wire entry height (est)

// --- Slide switches (SS-12D00), lever slides along X -----------------------
sw_x   = [18, 29];  // centres (est)
sw_y0  = 2;   sw_y1 = 5.6;
sw_len = 8.6;
sw_body_h  = 4;   // est
sw_lever_h = 8;   // lever top
sw_lever   = [2, 1.5];  // lever footprint X,Y (est)

// --- Serial header (3-pin female, plug from +Z) ----------------------------
ser_x0 = 4;   ser_x1 = 6.5;   // est
ser_y0 = 2;   ser_y1 = 9.6;   // est
ser_h  = 8.5;

// --- Back side (Z < -pb_t) -------------------------------------------------
rst_x0 = 4;   rst_x1 = 7;     // reset button (est)
rst_y0 = 13;  rst_y1 = 19;    // est
rst_h  = 5.5;                 // from back face
wires_h = 7;                  // max wire/solder height from back face
cap_x0 = 46;  cap_x1 = 58;    // 470 uF, tilted: envelope (est)
cap_y0 = 21;  cap_y1 = 36;    // est
cap_h  = 22;                  // from back face

// --- Derived envelope ------------------------------------------------------
env_x0 = esp_x0;
env_x1 = rj_x1;
env_y0 = -wire_wrap;
env_y1 = pb_y + wire_wrap;
env_z0 = -pb_t - cap_h;
env_z1 = rj_z1;

assert(esp_x0 + esp_len < w55_x0 + 0.5, "ESP32-CAM overlaps the W5500 module");
assert(lens_top > esp_pcb_top, "lens must sit above the ESP32-CAM PCB");
echo(envelope_x = [env_x0, env_x1], envelope_y = [env_y0, env_y1],
     envelope_z = [env_z0, env_z1]);

module blk(x0, x1, y0, y1, z0, z1) {
    translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);
}

module perfboard() {
    color("green")
        difference() {
            blk(0, pb_x, 0, pb_y, -pb_t, 0);
            for (x = [pb_hole_off, pb_x - pb_hole_off],
                 y = [pb_hole_off, pb_y - pb_hole_off])
                translate([x, y, -pb_t - 1]) cylinder(d = pb_hole_d, h = pb_t + 2);
        }
}

module esp32cam() {
    x1 = esp_x0 + esp_len;
    y1 = esp_y0 + esp_wid;
    z0 = esp_pcb_top - esp_pcb_t;
    color("dimgray") {
        // female headers
        hx1 = x1 - esp_hdr_end;
        hx0 = hx1 - esp_hdr_len;
        blk(hx0, hx1, esp_y0, esp_y0 + esp_hdr_w, 0, z0);
        blk(hx0, hx1, y1 - esp_hdr_w, y1, 0, z0);
    }
    color("black") blk(esp_x0, x1, esp_y0, y1, z0, esp_pcb_top);
    color("silver")
        translate([lens_x - cam_blk / 2, lens_y - cam_blk / 2, esp_pcb_top])
            cube([cam_blk, cam_blk, lens_top - esp_pcb_top - 3]);
    color("black")
        translate([lens_x, lens_y, esp_pcb_top]) cylinder(d = lens_d, h = lens_top - esp_pcb_top);
    color("white") blk(led_x0, led_x1, led_y0, led_y1, esp_pcb_top, esp_pcb_top + led_h);
}

module w5500() {
    color("yellow") blk(w55_x0, w55_x1 - 2, w55_y0, w55_y0 + 2.5, 0, rj_z0 - w55_pcb_t);
    color("green") blk(w55_x0, w55_x1, w55_y0, w55_y1, rj_z0 - w55_pcb_t, rj_z0);
    color("silver") blk(rj_x0, rj_x1, rj_y0, rj_y1, rj_z0, rj_z1);
}

module terminal() {
    color("royalblue") blk(term_x0, term_x1, term_y0, term_y1, 0, term_h);
    color("gray")
        translate([term_x1, cable_y, cable_z]) rotate([0, 90, 0])
            cylinder(d = cable_d, h = 20);
}

module switches() {
    for (cx = sw_x) {
        color("ivory") blk(cx - sw_len / 2, cx + sw_len / 2, sw_y0, sw_y1, 0, sw_body_h);
        color("black")
            translate([cx - sw_lever[0] / 2, (sw_y0 + sw_y1 - sw_lever[1]) / 2, sw_body_h])
                cube([sw_lever[0], sw_lever[1], sw_lever_h - sw_body_h]);
    }
}

module serial_header() {
    color("black") blk(ser_x0, ser_x1, ser_y0, ser_y1, 0, ser_h);
}

module back_side() {
    zb = -pb_t;
    // wires and solder: ghost slab, the real stuff is somewhere inside it
    %blk(0, pb_x, 0, pb_y, zb - wires_h, zb);
    color("white") blk(rst_x0, rst_x1, rst_y0, rst_y1, zb - rst_h, zb);
    color("black") blk(cap_x0, cap_x1, cap_y0, cap_y1, zb - cap_h, zb);
}

module board() {
    perfboard();
    esp32cam();
    w5500();
    terminal();
    switches();
    serial_header();
    back_side();
}

// Files that include this one set board_included = true.

$fn = 32;
if (is_undef(board_included)) board();
