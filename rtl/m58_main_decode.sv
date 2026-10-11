`timescale 1ns/1ps
module m58_main_decode (
    input  logic [15:0] cpu_addr,
    input  logic        cpu_mreq_n,
    input  logic        cpu_rd_n,
    input  logic        cpu_wr_n,
    input  logic [7:0]  rom_data,
    input  logic [7:0]  work_data,
    input  logic [7:0]  vram_data,
    input  logic [7:0]  sprite_data,
    input  logic [7:0]  in0,
    input  logic [7:0]  in1,
    input  logic [7:0]  in2,
    input  logic [7:0]  dsw1,
    input  logic [7:0]  dsw2,
    output logic [7:0]  cpu_di,
    output logic        rom_read,
    output logic        work_read,
    output logic        work_write,
    output logic        vram_read,
    output logic        vram_write,
    output logic        panel_write,
    output logic        scroll_x_low_write,
    output logic        scroll_x_high_write,
    output logic        scroll_y_write,
    output logic        panel_disable_write,
    output logic        sprite_read,
    output logic        sprite_write,
    output logic        sound_write,
    output logic        flip_coin_write,
    output logic [4:0]  debug_select
);
    localparam logic [4:0] SEL_NONE     = 5'd0;
    localparam logic [4:0] SEL_ROM      = 5'd1;
    localparam logic [4:0] SEL_VRAM     = 5'd2;
    localparam logic [4:0] SEL_PANEL    = 5'd3;
    localparam logic [4:0] SEL_SCROLLXL = 5'd4;
    localparam logic [4:0] SEL_SCROLLXH = 5'd5;
    localparam logic [4:0] SEL_SCROLLY  = 5'd6;
    localparam logic [4:0] SEL_PANELDIS = 5'd7;
    localparam logic [4:0] SEL_SPRITE   = 5'd8;
    localparam logic [4:0] SEL_IN0SOUND = 5'd9;
    localparam logic [4:0] SEL_IN1FLIP  = 5'd10;
    localparam logic [4:0] SEL_IN2      = 5'd11;
    localparam logic [4:0] SEL_DSW1     = 5'd12;
    localparam logic [4:0] SEL_DSW2     = 5'd13;
    localparam logic [4:0] SEL_WORK     = 5'd14;

    logic mem_read;
    logic mem_write;

    always_comb begin
        mem_read  = !cpu_mreq_n && !cpu_rd_n;
        mem_write = !cpu_mreq_n && !cpu_wr_n;

        cpu_di              = 8'hff;
        rom_read            = 1'b0;
        work_read           = 1'b0;
        work_write          = 1'b0;
        vram_read           = 1'b0;
        vram_write          = 1'b0;
        panel_write         = 1'b0;
        scroll_x_low_write  = 1'b0;
        scroll_x_high_write = 1'b0;
        scroll_y_write      = 1'b0;
        panel_disable_write = 1'b0;
        sprite_read         = 1'b0;
        sprite_write        = 1'b0;
        sound_write         = 1'b0;
        flip_coin_write     = 1'b0;
        debug_select        = SEL_NONE;

        if (mem_read) begin
            if (cpu_addr <= 16'h5fff) begin
                cpu_di       = rom_data;
                rom_read     = 1'b1;
                debug_select = SEL_ROM;
            end else if ((cpu_addr >= 16'h8000) && (cpu_addr <= 16'h8fff)) begin
                cpu_di       = vram_data;
                vram_read    = 1'b1;
                debug_select = SEL_VRAM;
            end else if ((cpu_addr >= 16'hc820) && (cpu_addr <= 16'hc87f)) begin
                cpu_di       = sprite_data;
                sprite_read  = 1'b1;
                debug_select = SEL_SPRITE;
            end else if (cpu_addr == 16'hd000) begin
                cpu_di       = in0;
                debug_select = SEL_IN0SOUND;
            end else if (cpu_addr == 16'hd001) begin
                cpu_di       = in1;
                debug_select = SEL_IN1FLIP;
            end else if (cpu_addr == 16'hd002) begin
                cpu_di       = in2;
                debug_select = SEL_IN2;
            end else if (cpu_addr == 16'hd003) begin
                cpu_di       = dsw1;
                debug_select = SEL_DSW1;
            end else if (cpu_addr == 16'hd004) begin
                cpu_di       = dsw2;
                debug_select = SEL_DSW2;
            end else if ((cpu_addr >= 16'he000) && (cpu_addr <= 16'hefff)) begin
                cpu_di       = work_data;
                work_read    = 1'b1;
                debug_select = SEL_WORK;
            end
        end else if (mem_write) begin
            if ((cpu_addr >= 16'h8000) && (cpu_addr <= 16'h8fff)) begin
                vram_write   = 1'b1;
                debug_select = SEL_VRAM;
            end else if ((cpu_addr >= 16'h9000) && (cpu_addr <= 16'h9fff)) begin
                panel_write  = 1'b1;
                debug_select = SEL_PANEL;
            end else if (cpu_addr == 16'ha000) begin
                scroll_x_low_write = 1'b1;
                debug_select       = SEL_SCROLLXL;
            end else if (cpu_addr == 16'ha200) begin
                scroll_x_high_write = 1'b1;
                debug_select        = SEL_SCROLLXH;
            end else if (cpu_addr == 16'ha400) begin
                scroll_y_write = 1'b1;
                debug_select   = SEL_SCROLLY;
            end else if (cpu_addr == 16'ha800) begin
                panel_disable_write = 1'b1;
                debug_select        = SEL_PANELDIS;
            end else if ((cpu_addr >= 16'hc820) && (cpu_addr <= 16'hc87f)) begin
                sprite_write = 1'b1;
                debug_select = SEL_SPRITE;
            end else if (cpu_addr == 16'hd000) begin
                sound_write  = 1'b1;
                debug_select = SEL_IN0SOUND;
            end else if (cpu_addr == 16'hd001) begin
                flip_coin_write = 1'b1;
                debug_select    = SEL_IN1FLIP;
            end else if ((cpu_addr >= 16'he000) && (cpu_addr <= 16'hefff)) begin
                work_write  = 1'b1;
                debug_select = SEL_WORK;
            end
        end
    end
endmodule
