// Generated-clock wrapper. Stage 1 requests 36.864 MHz from the 50 MHz
// MiSTer reference so all main-board logic remains in one clock domain.
module pll (
    input  wire refclk,
    input  wire rst,
    output wire outclk_0,
    output wire locked
);
    pll_0002 pll_inst (
        .refclk(refclk),
        .rst(rst),
        .outclk_0(outclk_0),
        .locked(locked)
    );
endmodule
