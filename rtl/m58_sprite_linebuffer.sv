`timescale 1ns/1ps
// Two 256x4 ping-pong buffers model the pair of 2149 SRAMs on BOTTOM Sheet 4.
// The active line is read while the other buffer is cleared then constructed.
module m58_sprite_linebuffer (
    input  logic       clk,
    input  logic       reset,
    input  logic       ce_pixel,
    input  logic [8:0] hcount,
    input  logic       candidate_valid,
    input  logic [7:0] candidate_x,
    input  logic [2:0] candidate_pen,
    input  logic [3:0] candidate_palette_index,
    output logic [3:0] front_palette_index,
    output logic       front_opaque,
    output logic       front_select
);
    (* ramstyle = "M10K, no_rw_check" *) logic [3:0] line_buffer_0 [0:255];
    (* ramstyle = "M10K, no_rw_check" *) logic [3:0] line_buffer_1 [0:255];
    logic [3:0] read_data_0;
    logic [3:0] read_data_1;
    logic build_write;
    logic [7:0] build_addr;
    logic [3:0] build_data;

    // Candidate writes occur in horizontal blank and take precedence over
    // the visible-span clear schedule. Raw pen zero and lookup index zero are
    // both transparent. Every later nonzero candidate overwrites, making
    // descriptor zero the winner after Stage 4's reverse traversal.
    always @* begin
        build_write = 1'b0;
        build_addr  = 8'h00;
        build_data  = 4'h0;

        if (candidate_valid && (candidate_pen != 3'b000) &&
            (candidate_palette_index != 4'h0)) begin
            build_write = 1'b1;
            build_addr  = candidate_x;
            build_data  = candidate_palette_index;
        end else if (ce_pixel && (hcount < 9'd256)) begin
            build_write = 1'b1;
            build_addr  = hcount[7:0];
            build_data  = 4'h0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            front_select <= 1'b0;
            read_data_0  <= 4'h0;
            read_data_1  <= 4'h0;
        end else begin
            if (build_write) begin
                if (front_select)
                    line_buffer_0[build_addr] <= build_data;
                else
                    line_buffer_1[build_addr] <= build_data;
            end

            if (ce_pixel) begin
                read_data_0 <= line_buffer_0[hcount[7:0]];
                read_data_1 <= line_buffer_1[hcount[7:0]];

                if (hcount == 9'd383)
                    front_select <= ~front_select;
            end
        end
    end

    assign front_palette_index = front_select ? read_data_1 : read_data_0;
    assign front_opaque = (front_palette_index != 4'h0);
endmodule
