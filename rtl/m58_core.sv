`timescale 1ns/1ps
module m58_core #(parameter HISCORE_ENABLE = 0) (
    input  logic        clk_sys,
    input  logic        reset_async,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write,
    input  logic        hs_cold_reset,
    input  logic        hs_download,
    input  logic        hs_upload,
    input  logic        hs_wr,
    input  logic        hs_rd,
    input  logic [15:0] hs_index,
    input  logic        hs_save_action,
    input  logic        hs_autosave_on,
    output logic [7:0]  hs_upload_data,
    output logic        hs_upload_request,
    output logic        hs_valid,
    output logic        hs_fault,
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
    output logic        reset,
    output logic        ce_pixel,
    output logic        ce_cpu,
    output logic [8:0]  hcount,
    output logic [8:0]  vcount,
    output logic        hblank,
    output logic        vblank,
    output logic        hsync,
    output logic        vsync,
    output logic        vblank_start,
    output logic [7:0]  video_r,
    output logic [7:0]  video_g,
    output logic [7:0]  video_b,
    output logic        video_hblank,
    output logic        video_vblank,
    output logic        video_hsync,
    output logic        video_vsync,
    output logic [15:0] debug_cpu_addr,
    output logic [7:0]  debug_cpu_di,
    output logic [7:0]  debug_cpu_do,
    output logic        debug_mreq_n,
    output logic        debug_iorq_n,
    output logic        debug_rd_n,
    output logic        debug_wr_n,
    output logic        debug_m1_n,
    output logic        debug_irq_n,
    output logic        debug_irq_ack,
    output logic [4:0]  debug_select,
    output logic [7:0]  debug_scroll_x_low,
    output logic [7:0]  debug_scroll_x_high,
    output logic [7:0]  debug_scroll_y,
    output logic [7:0]  debug_panel_disable,
    output logic [7:0]  debug_sound_command,
    output logic        debug_flip_screen,
    output logic        sound_command_write
);
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_di;
    logic [7:0]  cpu_do;
    logic cpu_mreq_n;
    logic cpu_iorq_n;
    logic cpu_rd_n;
    logic cpu_wr_n;
    logic cpu_m1_n;
    logic cpu_irq_n;
    logic cpu_rfsh_n;
    logic cpu_halt_n;
    logic cpu_busak_n;
    wire hs_busrq_n, hs_owns, hs_manager_rd_n, hs_manager_wr_n;
    wire [15:0] hs_manager_a;
    wire [7:0] hs_manager_do;
    wire [7:0] hs_work_data;
    logic frame_start;
    logic [7:0] coin_control;
    logic sound_write_seen;
    wire sound_write_cycle = !cpu_mreq_n && !cpu_wr_n && (cpu_addr == 16'hd000);

    // One event per bus write, including repeated writes of the same byte.
    // Board command data and this event are registered on the same clock.
    always_ff @(posedge clk_sys) begin
        if (reset) begin
            sound_write_seen <= 1'b0;
            sound_command_write <= 1'b0;
        end else begin
            sound_write_seen <= sound_write_cycle;
            sound_command_write <= sound_write_cycle && !sound_write_seen;
        end
    end

    m58_clock_reset clock_reset (
        .clk_sys,
        .reset_async,
        .reset,
        .ce_pixel,
        .ce_cpu
    );

    T80s #(
        .Mode(0),
        .T2Write(1),
        .IOWait(1)
    ) cpu (
        .RESET_n(~reset),
        .CLK(clk_sys),
        .CEN(ce_cpu),
        .WAIT_n(1'b1),
        .INT_n(cpu_irq_n),
        .NMI_n(1'b1),
        .BUSRQ_n(hs_busrq_n),
        .M1_n(cpu_m1_n),
        .MREQ_n(cpu_mreq_n),
        .IORQ_n(cpu_iorq_n),
        .RD_n(cpu_rd_n),
        .WR_n(cpu_wr_n),
        .RFSH_n(cpu_rfsh_n),
        .HALT_n(cpu_halt_n),
        .BUSAK_n(cpu_busak_n),
        .OUT0(1'b0),
        .A(cpu_addr),
        .DI(cpu_di),
        .DO(cpu_do)
    );

    generate if (HISCORE_ENABLE) begin : hiscore_enabled
        m58_hiscore hiscore (
            .clk(clk_sys), .cold_reset(hs_cold_reset), .game_reset(reset),
            .download(hs_download), .upload(hs_upload),
            .wr(hs_wr), .rd(hs_rd), .index(hs_index),
            .address(download_addr), .data(download_data),
            .save_action(hs_save_action), .autosave_on(hs_autosave_on),
            .cpu_a(cpu_addr), .cpu_di(hs_owns ? hs_work_data : cpu_di),
            .m1_n(cpu_m1_n), .mreq_n(cpu_mreq_n),
            .rd_n(cpu_rd_n), .wr_n(cpu_wr_n), .busak_n(cpu_busak_n),
            .busrq_n(hs_busrq_n), .owns(hs_owns),
            .manager_a(hs_manager_a), .manager_do(hs_manager_do),
            .manager_rd_n(hs_manager_rd_n), .manager_wr_n(hs_manager_wr_n),
            .upload_data(hs_upload_data), .upload_request(hs_upload_request),
            .valid(hs_valid), .fault(hs_fault)
        );
    end else begin : hiscore_disabled
        assign hs_busrq_n = 1'b1;
        assign hs_owns = 1'b0;
        assign hs_manager_a = 16'd0;
        assign hs_manager_do = 8'd0;
        assign hs_manager_rd_n = 1'b1;
        assign hs_manager_wr_n = 1'b1;
        assign hs_upload_data = 8'd0;
        assign hs_upload_request = 1'b0;
        assign hs_valid = 1'b0;
        assign hs_fault = 1'b0;
    end endgenerate

    m58_main_board #(.HISCORE_ENABLE(HISCORE_ENABLE)) board (
        .clk(clk_sys),
        .reset,
        .ce_pixel,
        .cpu_addr,
        .cpu_do,
        .cpu_di,
        .cpu_mreq_n,
        .cpu_iorq_n,
        .cpu_rd_n,
        .cpu_wr_n,
        .cpu_m1_n,
        .hs_owns,
        .hs_manager_a,
        .hs_manager_do,
        .hs_manager_rd_n,
        .hs_manager_wr_n,
        .hs_work_data,
        .cpu_irq_n,
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
        .dsw1,
        .dsw2,
        .download_clk,
        .download_addr,
        .download_data,
        .download_write,
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
        .frame_start,
        .irq_ack(debug_irq_ack),
        .debug_select,
        .scroll_x_low(debug_scroll_x_low),
        .scroll_x_high(debug_scroll_x_high),
        .scroll_y(debug_scroll_y),
        .panel_disable(debug_panel_disable),
        .sound_command(debug_sound_command),
        .flip_screen(debug_flip_screen),
        .coin_control
    );

    assign debug_cpu_addr = cpu_addr;
    assign debug_cpu_di   = cpu_di;
    assign debug_cpu_do   = cpu_do;
    assign debug_mreq_n   = cpu_mreq_n;
    assign debug_iorq_n   = cpu_iorq_n;
    assign debug_rd_n     = cpu_rd_n;
    assign debug_wr_n     = cpu_wr_n;
    assign debug_m1_n     = cpu_m1_n;
    assign debug_irq_n    = cpu_irq_n;
endmodule
