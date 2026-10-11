`timescale 1ns/1ps
// Each physical ROM contains 256 codes, with left/right rows at +0/+16.
// Repack download bytes into logical half-plane memories for parallel reads.
// BOTTOM Sheet 3 contains the corresponding six 2764 ROMs and six LS194
// parallel-load/shift devices.
module m58_sprite_assets (
    input  logic        clk,
    input  logic        reset,
    input  logic [12:0] gfx_addr,
    output logic [7:0]  plane_2_left,
    output logic [7:0]  plane_2_right,
    output logic [7:0]  plane_1_left,
    output logic [7:0]  plane_1_right,
    output logic [7:0]  plane_0_left,
    output logic [7:0]  plane_0_right,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write
);
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5b [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5c [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5f [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5e [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5j [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] rom_5k [0:8191];

    // Historical array names retained; these now hold logical halves, NOT
    // individual physical ROM files: 5b/5c = plane2 L/R, etc.
    // Drop physical half bit A4; keep bank A13 and code A12..5 above row.
    wire [12:0] download_row = {download_addr[13:5], download_addr[3:0]};

    always_ff @(posedge download_clk) begin
        if (download_write) begin
            if ((download_addr >= 27'h14000) && (download_addr < 27'h18000)) begin
                if (!download_addr[4]) rom_5b[download_row] <= download_data;
                else                   rom_5c[download_row] <= download_data;
            end
            if ((download_addr >= 27'h18000) && (download_addr < 27'h1c000)) begin
                if (!download_addr[4]) rom_5f[download_row] <= download_data;
                else                   rom_5e[download_row] <= download_data;
            end
            if ((download_addr >= 27'h1c000) && (download_addr < 27'h20000)) begin
                if (!download_addr[4]) rom_5j[download_row] <= download_data;
                else                   rom_5k[download_row] <= download_data;
            end
        end
    end

    // Preserve the historical fetch-lane names. The renderer assigns their
    // numerical significance: first physical ROM group is pen bit 0.
    always_ff @(posedge clk) begin
        if (reset) begin
            plane_2_left  <= 8'h00;
            plane_2_right <= 8'h00;
            plane_1_left  <= 8'h00;
            plane_1_right <= 8'h00;
            plane_0_left  <= 8'h00;
            plane_0_right <= 8'h00;
        end else begin
            plane_2_left  <= rom_5b[gfx_addr];
            plane_2_right <= rom_5c[gfx_addr];
            plane_1_left  <= rom_5f[gfx_addr];
            plane_1_right <= rom_5e[gfx_addr];
            plane_0_left  <= rom_5j[gfx_addr];
            plane_0_right <= rom_5k[gfx_addr];
        end
    end
endmodule
