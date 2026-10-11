`timescale 1ns/1ps
// MAME-confirmed logical 64x32 mapper. Column 5 selects the second 32x32
// half, matching the capacity split of the two physical 2Kx8 VRAM devices.
module m58_tilemap_addr (
    input  logic [8:0]  pixel_x,
    input  logic [7:0]  pixel_y,
    output logic [10:0] tile_index,
    output logic [11:0] code_addr,
    output logic [11:0] attr_addr
);
    logic [5:0] column;

    assign column     = pixel_x[8:3];
    assign tile_index = {column[5], pixel_y[7:3], column[4:0]};
    assign code_addr  = {tile_index, 1'b0};
    assign attr_addr  = {tile_index, 1'b1};
endmodule
