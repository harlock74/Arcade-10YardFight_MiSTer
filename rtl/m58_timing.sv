`timescale 1ns/1ps
// Normalized MAME raster counters plus the equivalent original TTL counter
// phases. The physical counters run H=0x100..0x1ff,0x080..0x0ff and
// V=0x0e6..0x1ff; normalized zero is the start of MAME's raw frame.
module m58_timing (
    input  logic       clk,
    input  logic       reset,
    input  logic       ce_pixel,
    output logic [8:0] hcount,
    output logic [8:0] vcount,
    output logic       hblank,
    output logic       vblank,
    output logic       hsync,
    output logic       vsync,
    output logic [8:0] h_chain,
    output logic [8:0] v_chain,
    output logic       vblank_start,
    output logic       frame_start
);
    localparam int H_TOTAL       = 384;
    localparam int H_VISIBLE_END = 256;
    localparam int V_TOTAL       = 282;
    localparam int V_VISIBLE_BEG = 42;
    localparam int V_VISIBLE_END = 266;
    // BOTTOM 1: LS139 2Y1 decodes physical H160..191 and the following
    // LS74 samples it on H16, yielding physical H176..207 = normalized
    // H304..335. The vertical LS139 1Y1 decodes physical V232..239.
    localparam int H_SYNC_BEG    = 304;
    localparam int H_SYNC_END    = 336;
    localparam int V_SYNC_BEG    = 2;
    localparam int V_SYNC_END    = 10;

    assign hblank = (hcount >= H_VISIBLE_END);
    assign vblank = (vcount < V_VISIBLE_BEG) || (vcount >= V_VISIBLE_END);
    assign hsync  = !((hcount >= H_SYNC_BEG) && (hcount < H_SYNC_END));
    assign vsync  = !((vcount >= V_SYNC_BEG) && (vcount < V_SYNC_END));

    // Clear correspondences to the named 1H..H256 and 1V..V256 schematic
    // signals: bit N of these buses is the same counter phase named 2**N.
    assign h_chain = (hcount < 9'd256) ? (hcount + 9'd256)
                                         : (hcount - 9'd128);
    assign v_chain = vcount + 9'd230;

    always_ff @(posedge clk) begin
        if (reset) begin
            hcount       <= 9'd0;
            vcount       <= 9'd0;
            vblank_start <= 1'b0;
            frame_start  <= 1'b0;
        end else begin
            vblank_start <= 1'b0;
            frame_start  <= 1'b0;

            if (ce_pixel) begin
                if (hcount == H_TOTAL - 1) begin
                    hcount <= 9'd0;
                    if (vcount == V_TOTAL - 1) begin
                        vcount      <= 9'd0;
                        frame_start <= 1'b1;
                    end else begin
                        vcount <= vcount + 1'd1;
                    end

                    if (vcount == V_VISIBLE_END - 1) vblank_start <= 1'b1;
                end else begin
                    hcount <= hcount + 1'd1;
                end
            end
        end
    end
endmodule
