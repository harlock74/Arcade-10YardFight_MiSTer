`timescale 1ns/1ps
// M58 main-domain clock enables and reset synchronizer.
// clk_sys is 36.864 MHz: pixel = /6, Z80 = /12.
module m58_clock_reset (
    input  logic clk_sys,
    input  logic reset_async,
    output logic reset,
    output logic ce_pixel,
    output logic ce_cpu
);
    logic [3:0] reset_pipe = 4'hf;
    logic [3:0] divider;

    always_ff @(posedge clk_sys or posedge reset_async) begin
        if (reset_async) reset_pipe <= 4'hf;
        else             reset_pipe <= {reset_pipe[2:0], 1'b0};
    end

    assign reset = reset_pipe[3];

    always_ff @(posedge clk_sys) begin
        if (reset) begin
            divider <= 4'd0;
        end else begin
            divider <= (divider == 4'd11) ? 4'd0 : divider + 1'd1;
        end
    end

    assign ce_pixel = !reset && ((divider == 4'd5) || (divider == 4'd11));
    assign ce_cpu   = !reset &&  (divider == 4'd11);
endmodule
