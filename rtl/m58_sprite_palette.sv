`timescale 1ns/1ps
// MAME's sprite pen indirection is exactly the hardware-friendly value to
// keep in each four-bit 2149 line-buffer entry. Index zero is transparent.
module m58_sprite_palette (
    input  logic [7:0]  lookup_addr,
    output logic [3:0]  lookup_index,
    input  logic [3:0]  palette_index,
    output logic [7:0]  palette_raw,
    output logic [7:0]  palette_r,
    output logic [7:0]  palette_g,
    output logic [7:0]  palette_b,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write
);
    logic [3:0] sprite_lookup [0:255];
    logic [7:0] sprite_palette [0:31];

    always_ff @(posedge download_clk) begin
        if (download_write) begin
            if ((download_addr >= 27'h20200) && (download_addr < 27'h20220))
                sprite_palette[download_addr[4:0]] <= download_data;
            if ((download_addr >= 27'h20220) && (download_addr < 27'h20320))
                sprite_lookup[download_addr[8:0] - 9'h020] <= download_data[3:0];
        end
    end

    assign lookup_index = sprite_lookup[lookup_addr];
    assign palette_raw = sprite_palette[{1'b0, palette_index}];

    // These values reproduce MAME's legacy resistor calculation. The sprite
    // RGB network uses the character-network scale plus a 470-ohm pulldown,
    // so it is intentionally dimmer than the background conversion.
    function automatic logic [7:0] expand_sprite_2bit(input logic [1:0] value);
        case (value)
            2'b00: expand_sprite_2bit = 8'd0;
            2'b01: expand_sprite_2bit = 8'd62;
            2'b10: expand_sprite_2bit = 8'd132;
            default: expand_sprite_2bit = 8'd193;
        endcase
    endfunction

    function automatic logic [7:0] expand_sprite_3bit(input logic [2:0] value);
        case (value)
            3'b000: expand_sprite_3bit = 8'd0;
            3'b001: expand_sprite_3bit = 8'd26;
            3'b010: expand_sprite_3bit = 8'd55;
            3'b011: expand_sprite_3bit = 8'd81;
            3'b100: expand_sprite_3bit = 8'd118;
            3'b101: expand_sprite_3bit = 8'd144;
            3'b110: expand_sprite_3bit = 8'd174;
            default: expand_sprite_3bit = 8'd200;
        endcase
    endfunction

    always @* begin
        palette_r = expand_sprite_2bit(palette_raw[7:6]);
        palette_g = expand_sprite_3bit(palette_raw[5:3]);
        palette_b = expand_sprite_3bit(palette_raw[2:0]);
    end
endmodule
