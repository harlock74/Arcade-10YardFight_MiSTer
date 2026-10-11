`timescale 1ns/1ps
// Stage 2 documented approximation: FPGA dual-port RAM replaces the original
// LS157 time-multiplexed CPU/video path. The two 2K banks preserve the physical
// capacity split while presenting the MAME-confirmed linear 4K byte window.
module m58_video_ram (
    input  logic        clk,
    input  logic        reset,
    input  logic [11:0] cpu_addr,
    input  logic [7:0]  cpu_data_in,
    input  logic        cpu_read,
    input  logic        cpu_write,
    output logic [7:0]  cpu_data_out,
    input  logic [11:0] video_addr,
    output logic [7:0]  video_data
);
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] bank_0 [0:2047];
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] bank_1 [0:2047];

    always_ff @(posedge clk) begin
        if (reset) begin
            cpu_data_out <= 8'hff;
            video_data   <= 8'h00;
        end else begin
            if (cpu_read) begin
                cpu_data_out <= cpu_addr[11] ? bank_1[cpu_addr[10:0]]
                                             : bank_0[cpu_addr[10:0]];
            end

            if (cpu_write) begin
                if (cpu_addr[11]) bank_1[cpu_addr[10:0]] <= cpu_data_in;
                else              bank_0[cpu_addr[10:0]] <= cpu_data_in;
            end

            video_data <= video_addr[11] ? bank_1[video_addr[10:0]]
                                         : bank_0[video_addr[10:0]];
        end
    end
endmodule
