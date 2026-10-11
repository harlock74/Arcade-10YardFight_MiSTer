`timescale 1ns/1ps
module m58_inputs (
    input  logic       clk,
    input  logic       reset,
    input  logic       vblank_start,
    input  logic       start1,
    input  logic       start2,
    input  logic       service,
    input  logic       coin1,
    input  logic       coin2,
    input  logic       p1_right,
    input  logic       p1_left,
    input  logic       p1_down,
    input  logic       p1_up,
    input  logic       p1_button1,
    input  logic       p1_button2,
    input  logic       p2_right,
    input  logic       p2_left,
    input  logic       p2_down,
    input  logic       p2_up,
    input  logic       p2_button1,
    input  logic       p2_button2,
    output logic [7:0] in0,
    output logic [7:0] in1,
    output logic [7:0] in2
);
    logic       service_d;
    logic [4:0] service_frames;

    // MAME models SERVICE1 as a 19-frame impulse so it is recognized reliably.
    always_ff @(posedge clk) begin
        if (reset) begin
            service_d      <= 1'b0;
            service_frames <= 5'd0;
        end else begin
            service_d <= service;
            if (service && !service_d) begin
                service_frames <= 5'd19;
            end else if (vblank_start && (service_frames != 0)) begin
                service_frames <= service_frames - 1'd1;
            end
        end
    end

    always_comb begin
        in0 = {4'hf, ~coin1, ~(service_frames != 0), ~start2, ~start1};
        in1 = {~p1_button1, 1'b1, ~p1_button2, 1'b1,
               ~p1_up, ~p1_down, ~p1_left, ~p1_right};
        in2 = {~p2_button1, 1'b1, ~p2_button2, ~coin2,
               ~p2_up, ~p2_down, ~p2_left, ~p2_right};
    end
endmodule
