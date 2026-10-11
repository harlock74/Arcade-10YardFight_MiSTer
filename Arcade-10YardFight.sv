`timescale 1ns/1ps
//============================================================================
// Irem 10-Yard Fight (M58) for MiSTer
// Stage 9: MiSTer controls, DIP loader and video-output integration.
//============================================================================
module emu (
    `include "sys/emu_ports.vh"
);
    assign ADC_BUS  = 'z;
    assign USER_OUT = '1;
    assign {UART_RTS, UART_TXD, UART_DTR} = '0;
    assign {SD_SCK, SD_MOSI, SD_CS} = 'z;
    assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
            SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
            SDRAM_nRAS, SDRAM_nCS} = 'z;
    assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN,
            DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

    assign VGA_SL       = 2'b00;
    assign VGA_F1       = 1'b0;
    assign VGA_SCALER   = 1'b0;
    assign VGA_DISABLE  = 1'b0;
    assign HDMI_FREEZE  = 1'b0;
    assign HDMI_BLACKOUT = 1'b0;
    assign HDMI_BOB_DEINT = 1'b0;

    wire [15:0] sound_audio;
    assign AUDIO_S   = 1'b1;
    assign AUDIO_L   = sound_audio;
    assign AUDIO_R   = sound_audio;
    assign AUDIO_MIX = 2'b00;

    assign LED_DISK  = 2'b00;
    assign LED_POWER = 2'b00;
    assign BUTTONS   = 2'b00;

    wire [127:0] status;
    wire [1:0] buttons;
    wire forced_scandoubler;
    wire [31:0] joystick_0;
    wire [31:0] joystick_1;
    wire [21:0] gamma_bus;
    wire ioctl_download;
    wire ioctl_wr;
    wire ioctl_upload;
    wire ioctl_rd;
    wire ioctl_upload_req;
    wire [7:0] ioctl_din;
    wire [26:0] ioctl_addr;
    wire [7:0] ioctl_dout;
    wire [15:0] ioctl_index;
    wire hs_valid;
    wire hs_fault;

    wire [1:0] ar = status[122:121];
    assign VIDEO_ARX = (!ar) ? 13'd4 : {1'b0, ar - 1'd1};
    assign VIDEO_ARY = (!ar) ? 13'd3 : 13'd0;

    `include "build_id.v"
    localparam CONF_STR = {
        "A.10YARD;;",
        "-;",
        "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
        "O[3],Service credit,Off,On;",
        "O[12],Autosave High Scores,On,Off;",
        "DIP;",
        "-;",
        "d2T[11],Save High Scores Now;",
        "T[0],Reset;",
        "R[0],Reset and close OSD;",
        "J1,Button 1,Button 2,Start 1P,Start 2P,Coin;",
        "jn,A,B,Start,Select,R;",
        "V,v", `BUILD_DATE
    };

    wire clk_sys;
    wire pll_locked;
    pll pll (
        .refclk(CLK_50M),
        .rst(RESET),
        .outclk_0(clk_sys),
        .locked(pll_locked)
    );

    hps_io #(.CONF_STR(CONF_STR)) hps_io (
        .clk_sys(clk_sys),
        .HPS_BUS(HPS_BUS),
        .gamma_bus(gamma_bus),
        .buttons(buttons),
        .status(status),
        .status_menumask({4'd0,!hs_valid,11'd0}),
        .forced_scandoubler(forced_scandoubler),
        .joystick_0(joystick_0),
        .joystick_1(joystick_1),
        .ioctl_download(ioctl_download),
        .ioctl_upload(ioctl_upload),
        .ioctl_rd(ioctl_rd),
        .ioctl_upload_req(ioctl_upload_req),
        .ioctl_upload_index(8'd4),
        .ioctl_din(ioctl_din),
        .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout),
        .ioctl_index(ioctl_index)
    );

    // MAME defaults: DSW1 normal/1C_1C, DSW2 upright/mode 1/cheats off.
    logic [7:0] dsw1 = 8'hff;
    logic [7:0] dsw2 = 8'hfd;
    always_ff @(posedge clk_sys) begin
        if (ioctl_wr && (ioctl_index == 16'd254)) begin
            if (ioctl_addr == 0) dsw1 <= ioctl_dout;
            if (ioctl_addr == 1) dsw2 <= ioctl_dout;
        end
    end

    wire [31:0] joy_any = joystick_0 | joystick_1;
    wire core_reset;
    wire ce_pixel;
    wire ce_cpu;
    wire [8:0] hcount;
    wire [8:0] vcount;
    wire hblank;
    wire vblank;
    wire hsync;
    wire vsync;
    wire vblank_start;
    wire [7:0] video_r;
    wire [7:0] video_g;
    wire [7:0] video_b;
    wire video_hblank;
    wire video_vblank;
    wire video_hsync;
    wire video_vsync;
    wire [15:0] debug_cpu_addr;
    wire [7:0] debug_cpu_di;
    wire [7:0] debug_cpu_do;
    wire debug_mreq_n;
    wire debug_iorq_n;
    wire debug_rd_n;
    wire debug_wr_n;
    wire debug_m1_n;
    wire debug_irq_n;
    wire debug_irq_ack;
    wire [4:0] debug_select;
    wire [7:0] debug_scroll_x_low;
    wire [7:0] debug_scroll_x_high;
    wire [7:0] debug_scroll_y;
    wire [7:0] debug_panel_disable;
    wire [7:0] debug_sound_command;
    wire debug_flip_screen;
    wire sound_command_write;

    m58_core #(.HISCORE_ENABLE(1)) core (
        .clk_sys,
        .reset_async(RESET | status[0] | buttons[1] | ioctl_download | !pll_locked),
        .download_clk(clk_sys),
        .download_addr(ioctl_addr),
        .download_data(ioctl_dout),
        .download_write(ioctl_download && ioctl_wr && (ioctl_index == 0)),
        .hs_cold_reset(RESET | !pll_locked),
        .hs_download(ioctl_download),
        .hs_upload(ioctl_upload),
        .hs_wr(ioctl_wr),
        .hs_rd(ioctl_rd),
        .hs_index(ioctl_index),
        .hs_save_action(status[11]),
        .hs_autosave_on(!status[12]),
        .hs_upload_data(ioctl_din),
        .hs_upload_request(ioctl_upload_req),
        .hs_valid,
        .hs_fault,
        .start1(joy_any[6]),
        .start2(joy_any[7]),
        .service(status[3]),
        .coin1(joystick_0[8]),
        .coin2(joystick_1[8]),
        .p1_right(joystick_0[0]),
        .p1_left(joystick_0[1]),
        .p1_down(joystick_0[2]),
        .p1_up(joystick_0[3]),
        .p1_button1(joystick_0[4]),
        .p1_button2(joystick_0[5]),
        .p2_right(joystick_1[0]),
        .p2_left(joystick_1[1]),
        .p2_down(joystick_1[2]),
        .p2_up(joystick_1[3]),
        .p2_button1(joystick_1[4]),
        .p2_button2(joystick_1[5]),
        .dsw1,
        .dsw2,
        .reset(core_reset),
        .ce_pixel,
        .ce_cpu,
        .hcount,
        .vcount,
        .hblank,
        .vblank,
        .hsync,
        .vsync,
        .vblank_start,
        .video_r,
        .video_g,
        .video_b,
        .video_hblank,
        .video_vblank,
        .video_hsync,
        .video_vsync,
        .debug_cpu_addr,
        .debug_cpu_di,
        .debug_cpu_do,
        .debug_mreq_n,
        .debug_iorq_n,
        .debug_rd_n,
        .debug_wr_n,
        .debug_m1_n,
        .debug_irq_n,
        .debug_irq_ack,
        .debug_select,
        .debug_scroll_x_low,
        .debug_scroll_x_high,
        .debug_scroll_y,
        .debug_panel_disable,
        .debug_sound_command,
        .debug_flip_screen,
        .sound_command_write
    );

    m52_large_audio sound_board (
        .clk(clk_sys),
        .reset(core_reset),
        .command_write(sound_command_write),
        .command_data(debug_sound_command),
        .download_clk(clk_sys),
        .download_write(ioctl_download && ioctl_wr && (ioctl_index == 0)),
        .download_addr(ioctl_addr),
        .download_data(ioctl_dout),
        .audio(sound_audio)
    );

    assign CLK_VIDEO = clk_sys;
    // Framework mixer accepts positive sync pulses. The original board signals
    // are active low. Its output CE follows the selected scan-doubling mode.
    // Reserve a full power-of-two line including pipeline/blanking margin.
    // A 256-entry buffer produced unknown doubled pixels in regression.
    video_mixer #(.LINE_LENGTH(512), .HALF_DEPTH(0), .GAMMA(0)) video_output (
        .CLK_VIDEO(clk_sys), .CE_PIXEL(CE_PIXEL), .ce_pix(ce_pixel),
        .scandoubler(forced_scandoubler), .hq2x(1'b0), .gamma_bus(gamma_bus),
        .R(video_r), .G(video_g), .B(video_b),
        .HSync(~video_hsync), .VSync(~video_vsync),
        .HBlank(video_hblank), .VBlank(video_vblank),
        .HDMI_FREEZE(1'b0), .freeze_sync(),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_DE(VGA_DE)
    );
    assign LED_USER  = ioctl_download | !pll_locked;
endmodule
