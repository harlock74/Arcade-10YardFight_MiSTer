`timescale 1ns/1ps
// MAME-observable final layer order: radar/panel over non-transparent sprite
// over playfield. The exact BOTTOM-4/5 TTL priority equation remains
// unresolved because the supplied schematic scan is not pin-trace legible.
module m58_video_mixer (
    input  logic [7:0] background_r,
    input  logic [7:0] background_g,
    input  logic [7:0] background_b,
    input  logic       background_hblank,
    input  logic       background_vblank,
    input  logic       background_hsync,
    input  logic       background_vsync,
    input  logic       sprite_opaque,
    input  logic [7:0] sprite_r,
    input  logic [7:0] sprite_g,
    input  logic [7:0] sprite_b,
    input  logic       panel_active,
    input  logic [7:0] panel_r,
    input  logic [7:0] panel_g,
    input  logic [7:0] panel_b,
    output logic [7:0] video_r,
    output logic [7:0] video_g,
    output logic [7:0] video_b,
    output logic       video_hblank,
    output logic       video_vblank,
    output logic       video_hsync,
    output logic       video_vsync
);
    always_comb begin
        video_hblank = background_hblank;
        video_vblank = background_vblank;
        video_hsync  = background_hsync;
        video_vsync  = background_vsync;

        if (background_hblank || background_vblank) begin
            video_r = 8'h00;
            video_g = 8'h00;
            video_b = 8'h00;
        end else if (panel_active) begin
            video_r = panel_r;
            video_g = panel_g;
            video_b = panel_b;
        end else if (sprite_opaque) begin
            video_r = sprite_r;
            video_g = sprite_g;
            video_b = sprite_b;
        end else begin
            video_r = background_r;
            video_g = background_g;
            video_b = background_b;
        end
    end
endmodule
