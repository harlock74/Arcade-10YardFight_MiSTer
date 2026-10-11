`timescale 1ns/1ps
module m58_main_board #(parameter HISCORE_ENABLE = 0) (
    input  logic        clk,
    input  logic        reset,
    input  logic        ce_pixel,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_do,
    output logic [7:0]  cpu_di,
    input  logic        cpu_mreq_n,
    input  logic        cpu_iorq_n,
    input  logic        cpu_rd_n,
    input  logic        cpu_wr_n,
    input  logic        cpu_m1_n,
    input  logic        hs_owns,
    input  logic [15:0] hs_manager_a,
    input  logic [7:0]  hs_manager_do,
    input  logic        hs_manager_rd_n,
    input  logic        hs_manager_wr_n,
    output logic [7:0]  hs_work_data,
    output logic        cpu_irq_n,
    input  logic        start1,
    input  logic        start2,
    input  logic        service,
    input  logic        coin1,
    input  logic        coin2,
    input  logic        p1_right,
    input  logic        p1_left,
    input  logic        p1_down,
    input  logic        p1_up,
    input  logic        p1_button1,
    input  logic        p1_button2,
    input  logic        p2_right,
    input  logic        p2_left,
    input  logic        p2_down,
    input  logic        p2_up,
    input  logic        p2_button1,
    input  logic        p2_button2,
    input  logic [7:0]  dsw1,
    input  logic [7:0]  dsw2,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write,
    output logic [8:0]  hcount,
    output logic [8:0]  vcount,
    output logic        hblank,
    output logic        vblank,
    output logic        hsync,
    output logic        vsync,
    output logic        vblank_start,
    output logic        frame_start,
    output logic [7:0]  video_r,
    output logic [7:0]  video_g,
    output logic [7:0]  video_b,
    output logic        video_hblank,
    output logic        video_vblank,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic        irq_ack,
    output logic [4:0]  debug_select,
    output logic [7:0]  scroll_x_low,
    output logic [7:0]  scroll_x_high,
    output logic [7:0]  scroll_y,
    output logic [7:0]  panel_disable,
    output logic [7:0]  sound_command,
    output logic        flip_screen,
    output logic [7:0]  coin_control,
    output logic [10:0] debug_tile_index,
    output logic [9:0]  debug_tile_code,
    output logic [7:0]  debug_tile_attr,
    output logic [12:0] debug_gfx_addr,
    output logic [7:0]  debug_palette_addr,
    output logic [2:0]  debug_pixel_pen
);
    logic [7:0] in0;
    logic [7:0] in1;
    logic [7:0] in2;
    logic [7:0] rom_data;
    logic [7:0] work_data;
    logic [7:0] vram_cpu_data;
    logic [7:0] vram_video_data;
    logic [7:0] sprite_cpu_data;
    logic rom_read;
    logic work_read;
    logic work_write;
    logic vram_read;
    logic vram_write;
    logic panel_write;
    logic scroll_x_low_write;
    logic scroll_x_high_write;
    logic scroll_y_write;
    logic panel_disable_write;
    logic sprite_read;
    logic sprite_write;
    logic sound_write;
    logic flip_coin_write;
    logic [8:0] h_chain;
    logic [8:0] v_chain;
    logic [11:0] vram_video_addr;
    logic [12:0] tile_gfx_addr;
    logic [7:0] tile_plane_0;
    logic [7:0] tile_plane_1;
    logic [7:0] tile_plane_2;
    logic [7:0] tile_palette_raw;
    logic [6:0] sprite_cpu_addr;
    logic [4:0] sprite_eval_index;
    logic sprite_eval_valid;
    logic [7:0] sprite_eval_y;
    logic [7:0] sprite_eval_attr;
    logic [7:0] sprite_eval_code;
    logic [7:0] sprite_eval_x;
    logic [12:0] sprite_gfx_addr;
    logic [7:0] sprite_plane_2_left;
    logic [7:0] sprite_plane_2_right;
    logic [7:0] sprite_plane_1_left;
    logic [7:0] sprite_plane_1_right;
    logic [7:0] sprite_plane_0_left;
    logic [7:0] sprite_plane_0_right;
    logic [8:0] sprite_scan_y;
    logic sprite_scan_start;
    logic sprite_busy;
    logic sprite_scan_done;
    logic sprite_pixel_valid;
    logic [7:0] sprite_pixel_x;
    logic [2:0] sprite_pixel_pen;
    logic [4:0] sprite_pixel_color;
    logic [4:0] sprite_pixel_descriptor;
    logic [8:0] sprite_pixel_code;
    logic [3:0] sprite_pixel_row;
    logic [7:0] sprite_lookup_addr;
    logic [3:0] sprite_candidate_palette_index;
    logic [3:0] sprite_front_palette_index;
    logic sprite_front_opaque;
    logic sprite_front_select;
    logic [7:0] sprite_palette_raw;
    logic [7:0] sprite_r;
    logic [7:0] sprite_g;
    logic [7:0] sprite_b;
    logic [7:0] background_r;
    logic [7:0] background_g;
    logic [7:0] background_b;
    logic background_hblank;
    logic background_vblank;
    logic background_hsync;
    logic background_vsync;
    logic radar_cpu_write_accepted;
    logic radar_active;
    logic [1:0] radar_pixel;
    logic [7:0] radar_palette_addr;
    logic [7:0] radar_palette_raw;
    logic [7:0] radar_r;
    logic [7:0] radar_g;
    logic [7:0] radar_b;

    assign sprite_cpu_addr = cpu_addr[6:0] - 7'h20;
    assign sprite_scan_y = (vcount == 9'd281) ? 9'd0 : (vcount + 1'd1);
    assign sprite_scan_start = ce_pixel && (hcount == 9'd256) &&
                               (sprite_scan_y >= 9'd42) &&
                               (sprite_scan_y < 9'd266);
    assign sprite_lookup_addr = {sprite_pixel_color, sprite_pixel_pen};

    m58_timing timing (
        .clk,
        .reset,
        .ce_pixel,
        .hcount,
        .vcount,
        .hblank,
        .vblank,
        .hsync,
        .vsync,
        .h_chain,
        .v_chain,
        .vblank_start,
        .frame_start
    );

    m58_inputs inputs (
        .clk,
        .reset,
        .vblank_start,
        .start1,
        .start2,
        .service,
        .coin1,
        .coin2,
        .p1_right,
        .p1_left,
        .p1_down,
        .p1_up,
        .p1_button1,
        .p1_button2,
        .p2_right,
        .p2_left,
        .p2_down,
        .p2_up,
        .p2_button1,
        .p2_button2,
        .in0,
        .in1,
        .in2
    );

    m58_main_decode decode (
        .cpu_addr,
        .cpu_mreq_n,
        .cpu_rd_n,
        .cpu_wr_n,
        .rom_data,
        .work_data,
        .vram_data(vram_cpu_data),
        .sprite_data(sprite_cpu_data),
        .in0,
        .in1,
        .in2,
        .dsw1,
        .dsw2,
        .cpu_di,
        .rom_read,
        .work_read,
        .work_write,
        .vram_read,
        .vram_write,
        .panel_write,
        .scroll_x_low_write,
        .scroll_x_high_write,
        .scroll_y_write,
        .panel_disable_write,
        .sprite_read,
        .sprite_write,
        .sound_write,
        .flip_coin_write,
        .debug_select
    );

    m58_main_memory #(.HISCORE_ENABLE(HISCORE_ENABLE)) memory (
        .clk,
        .reset,
        .cpu_addr,
        .cpu_do,
        .rom_read,
        .work_read,
        .work_write,
        .rom_data,
        .work_data,
        .hs_owns,
        .hs_manager_a,
        .hs_manager_do,
        .hs_manager_rd_n,
        .hs_manager_wr_n,
        .hs_work_data,
        .download_clk,
        .download_addr,
        .download_data,
        .download_write
    );

    m58_video_ram video_ram (
        .clk,
        .reset,
        .cpu_addr(cpu_addr[11:0]),
        .cpu_data_in(cpu_do),
        .cpu_read(vram_read),
        .cpu_write(vram_write),
        .cpu_data_out(vram_cpu_data),
        .video_addr(vram_video_addr),
        .video_data(vram_video_data)
    );

    m58_sprite_ram sprite_ram (
        .clk,
        .reset,
        .cpu_addr(sprite_cpu_addr),
        .cpu_data_in(cpu_do),
        .cpu_read(sprite_read),
        .cpu_write(sprite_write),
        .cpu_data_out(sprite_cpu_data),
        .eval_index(sprite_eval_index),
        .eval_valid(sprite_eval_valid),
        .eval_y(sprite_eval_y),
        .eval_attr(sprite_eval_attr),
        .eval_code(sprite_eval_code),
        .eval_x(sprite_eval_x)
    );

    m58_sprite_assets sprite_assets (
        .clk,
        .reset,
        .gfx_addr(sprite_gfx_addr),
        .plane_2_left(sprite_plane_2_left),
        .plane_2_right(sprite_plane_2_right),
        .plane_1_left(sprite_plane_1_left),
        .plane_1_right(sprite_plane_1_right),
        .plane_0_left(sprite_plane_0_left),
        .plane_0_right(sprite_plane_0_right),
        .download_clk,
        .download_addr,
        .download_data,
        .download_write
    );

    m58_sprite_renderer sprite_renderer (
        .clk,
        .reset,
        .scan_start(sprite_scan_start),
        .scan_y(sprite_scan_y),
        .flip_screen,
        .eval_index(sprite_eval_index),
        .eval_valid(sprite_eval_valid),
        .eval_y(sprite_eval_y),
        .eval_attr(sprite_eval_attr),
        .eval_code(sprite_eval_code),
        .eval_x(sprite_eval_x),
        .gfx_addr(sprite_gfx_addr),
        .plane_2_left(sprite_plane_2_left),
        .plane_2_right(sprite_plane_2_right),
        .plane_1_left(sprite_plane_1_left),
        .plane_1_right(sprite_plane_1_right),
        .plane_0_left(sprite_plane_0_left),
        .plane_0_right(sprite_plane_0_right),
        .busy(sprite_busy),
        .scan_done(sprite_scan_done),
        .pixel_valid(sprite_pixel_valid),
        .pixel_x(sprite_pixel_x),
        .pixel_pen(sprite_pixel_pen),
        .pixel_color(sprite_pixel_color),
        .pixel_descriptor(sprite_pixel_descriptor),
        .pixel_code(sprite_pixel_code),
        .pixel_row(sprite_pixel_row)
    );

    m58_sprite_palette sprite_palette (
        .lookup_addr(sprite_lookup_addr),
        .lookup_index(sprite_candidate_palette_index),
        .palette_index(sprite_front_palette_index),
        .palette_raw(sprite_palette_raw),
        .palette_r(sprite_r),
        .palette_g(sprite_g),
        .palette_b(sprite_b),
        .download_clk,
        .download_addr,
        .download_data,
        .download_write
    );

    m58_sprite_linebuffer sprite_linebuffer (
        .clk,
        .reset,
        .ce_pixel,
        .hcount,
        .candidate_valid(sprite_pixel_valid),
        .candidate_x(sprite_pixel_x),
        .candidate_pen(sprite_pixel_pen),
        .candidate_palette_index(sprite_candidate_palette_index),
        .front_palette_index(sprite_front_palette_index),
        .front_opaque(sprite_front_opaque),
        .front_select(sprite_front_select)
    );

    m58_radar_panel radar_panel (
        .clk,
        .reset,
        .ce_pixel,
        .hcount,
        .vcount,
        .flip_screen,
        .panel_disable,
        .cpu_addr(cpu_addr[11:0]),
        .cpu_data(cpu_do),
        .cpu_write(panel_write),
        .cpu_write_accepted(radar_cpu_write_accepted),
        .panel_active(radar_active),
        .panel_pixel(radar_pixel),
        .palette_addr(radar_palette_addr),
        .palette_raw(radar_palette_raw),
        .panel_r(radar_r),
        .panel_g(radar_g),
        .panel_b(radar_b),
        .download_clk,
        .download_addr,
        .download_data,
        .download_write
    );

    m58_tile_assets tile_assets (
        .clk,
        .reset,
        .gfx_addr(tile_gfx_addr),
        .plane_0(tile_plane_0),
        .plane_1(tile_plane_1),
        .plane_2(tile_plane_2),
        .palette_addr(debug_palette_addr),
        .palette_raw(tile_palette_raw),
        .download_clk,
        .download_addr,
        .download_data,
        .download_write
    );

    m58_background background (
        .clk,
        .reset,
        .ce_pixel,
        .hcount,
        .v_chain,
        .scroll_x_low,
        .scroll_x_high,
        .scroll_y,
        .flip_screen,
        .hblank,
        .vblank,
        .hsync,
        .vsync,
        .vram_addr(vram_video_addr),
        .vram_data(vram_video_data),
        .gfx_addr(tile_gfx_addr),
        .plane_0(tile_plane_0),
        .plane_1(tile_plane_1),
        .plane_2(tile_plane_2),
        .palette_addr(debug_palette_addr),
        .palette_raw(tile_palette_raw),
        .video_r(background_r),
        .video_g(background_g),
        .video_b(background_b),
        .video_hblank(background_hblank),
        .video_vblank(background_vblank),
        .video_hsync(background_hsync),
        .video_vsync(background_vsync),
        .debug_tile_index,
        .debug_tile_code,
        .debug_tile_attr,
        .debug_gfx_addr,
        .debug_pixel_pen
    );

    m58_video_mixer video_mixer (
        .background_r,
        .background_g,
        .background_b,
        .background_hblank,
        .background_vblank,
        .background_hsync,
        .background_vsync,
        .sprite_opaque(sprite_front_opaque),
        .sprite_r,
        .sprite_g,
        .sprite_b,
        .panel_active(radar_active),
        .panel_r(radar_r),
        .panel_g(radar_g),
        .panel_b(radar_b),
        .video_r,
        .video_g,
        .video_b,
        .video_hblank,
        .video_vblank,
        .video_hsync,
        .video_vsync
    );

    assign irq_ack = !cpu_m1_n && !cpu_iorq_n;

    always_ff @(posedge clk) begin
        if (reset) begin
            cpu_irq_n     <= 1'b1;
            scroll_x_low  <= 8'h00;
            scroll_x_high <= 8'h00;
            scroll_y      <= 8'h00;
            panel_disable <= 8'h00;
            sound_command <= 8'h00;
            flip_screen   <= 1'b0;
            coin_control  <= 8'h00;
        end else begin
            // MAME's HOLD_LINE behavior: latch at VBLANK and release on Z80 ack.
            if (vblank_start) cpu_irq_n <= 1'b0;
            else if (irq_ack) cpu_irq_n <= 1'b1;

            if (scroll_x_low_write)  scroll_x_low  <= cpu_do;
            if (scroll_x_high_write) scroll_x_high <= cpu_do;
            if (scroll_y_write)      scroll_y      <= cpu_do;
            if (panel_disable_write) panel_disable <= cpu_do;
            if (sound_write)         sound_command <= cpu_do;
            if (flip_coin_write) begin
                // MAME combines the software bit with active-low DSW2:1.
                flip_screen  <= cpu_do[0] ^ ~dsw2[0];
                coin_control <= cpu_do;
            end
        end
    end
endmodule
