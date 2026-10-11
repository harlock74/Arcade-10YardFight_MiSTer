`timescale 1ns/1ps
module m58_background (
    input  logic        clk,
    input  logic        reset,
    input  logic        ce_pixel,
    input  logic [8:0]  hcount,
    input  logic [8:0]  v_chain,
    input  logic [7:0]  scroll_x_low,
    input  logic [7:0]  scroll_x_high,
    input  logic [7:0]  scroll_y,
    input  logic        flip_screen,
    input  logic        hblank,
    input  logic        vblank,
    input  logic        hsync,
    input  logic        vsync,
    output logic [11:0] vram_addr,
    input  logic [7:0]  vram_data,
    output logic [12:0] gfx_addr,
    input  logic [7:0]  plane_0,
    input  logic [7:0]  plane_1,
    input  logic [7:0]  plane_2,
    output logic [7:0]  palette_addr,
    input  logic [7:0]  palette_raw,
    output logic [7:0]  video_r,
    output logic [7:0]  video_g,
    output logic [7:0]  video_b,
    output logic        video_hblank,
    output logic        video_vblank,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic [10:0] debug_tile_index,
    output logic [9:0]  debug_tile_code,
    output logic [7:0]  debug_tile_attr,
    output logic [12:0] debug_gfx_addr,
    output logic [2:0]  debug_pixel_pen
);
    logic [10:0] map_tile_index;
    logic [11:0] map_code_addr;
    logic [11:0] map_attr_addr;
    logic [8:0]  scroll_x;
    logic [8:0]  map_x;
    logic [7:0]  map_y;
    logic [2:0]  fetch_phase;
    logic [8:0]  pixel_x_latched;
    logic [7:0]  pixel_y_latched;
    logic        hblank_latched;
    logic        vblank_latched;
    logic        hsync_latched;
    logic        vsync_latched;
    logic [7:0]  code_latched;
    logic [7:0]  attr_latched;
    logic [11:0] attr_addr_latched;
    logic [2:0]  bit_select;
    logic [2:0]  pixel_pen;

    // MAME applies the 9-bit X value and 8-bit Y value directly to its
    // 512x256 tilemap. Only bit 0 of the separately mapped X-high byte can
    // affect a 512-pixel-wide map. v_chain[7:0] is normalized vcount - 26,
    // matching set_scrolldy(26,26).
    assign scroll_x = {scroll_x_high[0], scroll_x_low};
    assign map_x = flip_screen ? (9'd255 - hcount + scroll_x)
                               : (hcount + scroll_x);
    assign map_y = flip_screen ? (8'd255 - v_chain[7:0] + scroll_y)
                               : (v_chain[7:0] + scroll_y);

    m58_tilemap_addr mapper (
        .pixel_x(map_x),
        .pixel_y(map_y),
        .tile_index(map_tile_index),
        .code_addr(map_code_addr),
        .attr_addr(map_attr_addr)
    );

    assign bit_select = attr_latched[5] ? pixel_x_latched[2:0]
                                         : (3'd7 - pixel_x_latched[2:0]);
    assign pixel_pen = {plane_2[bit_select], plane_1[bit_select],
                        plane_0[bit_select]};
    assign palette_addr = {attr_latched[4:0], pixel_pen};

    function automatic logic [7:0] expand_2bit(input logic [1:0] value);
        case (value)
            2'b00: expand_2bit = 8'd0;
            2'b01: expand_2bit = 8'd81;
            2'b10: expand_2bit = 8'd174;
            default: expand_2bit = 8'd255;
        endcase
    endfunction

    function automatic logic [7:0] expand_3bit(input logic [2:0] value);
        case (value)
            3'b000: expand_3bit = 8'd0;
            3'b001: expand_3bit = 8'd33;
            3'b010: expand_3bit = 8'd71;
            3'b011: expand_3bit = 8'd104;
            3'b100: expand_3bit = 8'd151;
            3'b101: expand_3bit = 8'd184;
            3'b110: expand_3bit = 8'd222;
            default: expand_3bit = 8'd255;
        endcase
    endfunction

    // Six 36.864 MHz clocks are available per pixel. vram_addr[0] is the
    // functional H4E-equivalent byte phase: code/even at the pixel boundary,
    // then attribute/odd on phase 1. The exact LS157 SELECT source/polarity
    // remains unresolved; this schedule can later drive a phase-shared RAM.
    always_ff @(posedge clk) begin
        if (reset) begin
            fetch_phase       <= 3'd0;
            vram_addr         <= 12'h000;
            gfx_addr          <= 13'h0000;
            video_r           <= 8'h00;
            video_g           <= 8'h00;
            video_b           <= 8'h00;
            video_hblank      <= 1'b1;
            video_vblank      <= 1'b1;
            video_hsync       <= 1'b1;
            video_vsync       <= 1'b1;
            debug_tile_index  <= 11'h000;
            debug_tile_code   <= 10'h000;
            debug_tile_attr   <= 8'h00;
            debug_gfx_addr    <= 13'h0000;
            debug_pixel_pen   <= 3'b000;
            pixel_x_latched   <= 9'h000;
            pixel_y_latched   <= 8'h00;
            hblank_latched    <= 1'b1;
            vblank_latched    <= 1'b1;
            hsync_latched     <= 1'b1;
            vsync_latched     <= 1'b1;
            code_latched      <= 8'h00;
            attr_latched      <= 8'h00;
            attr_addr_latched <= 12'h000;
        end else if (ce_pixel) begin
            fetch_phase      <= 3'd1;
            pixel_x_latched  <= map_x;
            pixel_y_latched  <= map_y;
            hblank_latched   <= hblank;
            vblank_latched   <= vblank;
            hsync_latched    <= hsync;
            vsync_latched    <= vsync;
            vram_addr        <= map_code_addr;
            attr_addr_latched <= map_attr_addr;
            debug_tile_index <= map_tile_index;
        end else begin
            case (fetch_phase)
                3'd1: begin
                    vram_addr   <= attr_addr_latched;
                    fetch_phase <= 3'd2;
                end
                3'd2: begin
                    code_latched <= vram_data;
                    fetch_phase  <= 3'd3;
                end
                3'd3: begin
                    attr_latched     <= vram_data;
                    gfx_addr         <= {vram_data[7:6], code_latched,
                                         pixel_y_latched[2:0]};
                    debug_tile_code  <= {vram_data[7:6], code_latched};
                    debug_tile_attr  <= vram_data;
                    debug_gfx_addr   <= {vram_data[7:6], code_latched,
                                         pixel_y_latched[2:0]};
                    fetch_phase      <= 3'd4;
                end
                3'd4: fetch_phase <= 3'd5;
                3'd5: begin
                    video_hblank    <= hblank_latched;
                    video_vblank    <= vblank_latched;
                    video_hsync     <= hsync_latched;
                    video_vsync     <= vsync_latched;
                    debug_pixel_pen <= pixel_pen;
                    if (hblank_latched || vblank_latched) begin
                        video_r <= 8'h00;
                        video_g <= 8'h00;
                        video_b <= 8'h00;
                    end else begin
                        video_r <= expand_2bit(palette_raw[7:6]);
                        video_g <= expand_3bit(palette_raw[5:3]);
                        video_b <= expand_3bit(palette_raw[2:0]);
                    end
                    fetch_phase <= 3'd0;
                end
                default: fetch_phase <= 3'd0;
            endcase
        end
    end
endmodule
