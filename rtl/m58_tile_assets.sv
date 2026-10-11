`timescale 1ns/1ps
// MAME's first layout plane supplies the most-significant pen bit.
// Thus ascending physical files 3e/3d/3c supply pen bits 0/1/2.
module m58_tile_assets (
    input  logic        clk,
    input  logic        reset,
    input  logic [12:0] gfx_addr,
    output logic [7:0]  plane_0,
    output logic [7:0]  plane_1,
    output logic [7:0]  plane_2,
    input  logic [7:0]  palette_addr,
    output logic [7:0]  palette_raw,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write
);
    // MAME gfx_8x8x3_planar assigns pen bit 0 to the final region third.
    // plane_0 = yf-a.3c, plane_1 = yf-a.3d, plane_2 = yf-a.3e.
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] tile_plane_0 [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] tile_plane_1 [0:8191];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] tile_plane_2 [0:8191];
    logic [3:0] char_palette_low  [0:255];
    logic [3:0] char_palette_high [0:255];

    always_ff @(posedge download_clk) begin
        if (download_write) begin
            if ((download_addr >= 27'h12000) && (download_addr < 27'h14000))
                tile_plane_2[download_addr[12:0]] <= download_data;
            if ((download_addr >= 27'h10000) && (download_addr < 27'h12000))
                tile_plane_1[download_addr[12:0]] <= download_data;
            if ((download_addr >= 27'h0e000) && (download_addr < 27'h10000))
                tile_plane_0[download_addr[12:0]] <= download_data;
            if ((download_addr >= 27'h20000) && (download_addr < 27'h20100))
                char_palette_low[download_addr[7:0]] <= download_data[3:0];
            if ((download_addr >= 27'h20100) && (download_addr < 27'h20200))
                char_palette_high[download_addr[7:0]] <= download_data[3:0];
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            plane_0 <= 8'h00;
            plane_1 <= 8'h00;
            plane_2 <= 8'h00;
        end else begin
            plane_0 <= tile_plane_0[gfx_addr];
            plane_1 <= tile_plane_1[gfx_addr];
            plane_2 <= tile_plane_2[gfx_addr];
        end
    end

    // The 256x8 effective character palette is formed from two 4-bit PROMs.
    always_comb begin
        palette_raw = {char_palette_high[palette_addr],
                       char_palette_low[palette_addr]};
    end
endmodule
