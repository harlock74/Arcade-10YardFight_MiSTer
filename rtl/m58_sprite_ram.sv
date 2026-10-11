`timescale 1ns/1ps
// CPU-visible MAME sprite window. BOTTOM Sheet 2 contains a separate 2128
// with LS367/LS273 support, but its unused physical addresses and exact
// arbitration are not yet traced. Stage 4 therefore models only the proven
// 96 bytes and provides an independent evaluator view.
module m58_sprite_ram (
    input  logic       clk,
    input  logic       reset,
    input  logic [6:0] cpu_addr,
    input  logic [7:0] cpu_data_in,
    input  logic       cpu_read,
    input  logic       cpu_write,
    output logic [7:0] cpu_data_out,
    input  logic [4:0] eval_index,
    output logic       eval_valid,
    output logic [7:0] eval_y,
    output logic [7:0] eval_attr,
    output logic [7:0] eval_code,
    output logic [7:0] eval_x
);
    logic [7:0] memory [0:95];
    logic [95:0] valid_bytes;
    logic [6:0] eval_base;

    assign eval_base = {eval_index, 2'b00};

    always_comb begin
        eval_valid = &valid_bytes[eval_base +: 4];
        if (eval_valid) begin
            eval_y    = memory[eval_base];
            eval_attr = memory[eval_base + 1'd1];
            eval_code = memory[eval_base + 2'd2];
            eval_x    = memory[eval_base + 2'd3];
        end else begin
            eval_y    = 8'h00;
            eval_attr = 8'h00;
            eval_code = 8'h00;
            eval_x    = 8'h00;
        end
    end

    // Reset only the validity mask, not the memory array. This gives
    // deterministic reads without creating a reset loop over inferred RAM.
    always_ff @(posedge clk) begin
        if (reset) begin
            valid_bytes <= '0;
            cpu_data_out <= 8'hff;
        end else begin
            if (cpu_write && (cpu_addr < 7'd96)) begin
                memory[cpu_addr] <= cpu_data_in;
                valid_bytes[cpu_addr] <= 1'b1;
            end

            if (cpu_read) begin
                if ((cpu_addr < 7'd96) && valid_bytes[cpu_addr])
                    cpu_data_out <= memory[cpu_addr];
                else
                    cpu_data_out <= 8'hff;
            end
        end
    end
endmodule
