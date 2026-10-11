`timescale 1ns/1ps
// M58 radar/score-panel write device and pixel generator. The 4 KiB logical
// store reproduces MAME's $9000-$9fff behavior; it is not a claim that the
// physical BOTTOM-5 2128 has this literal capacity or address wiring.
module m58_radar_panel (
    input  logic        clk,
    input  logic        reset,
    input  logic        ce_pixel,
    input  logic [8:0]  hcount,
    input  logic [8:0]  vcount,
    input  logic        flip_screen,
    input  logic [7:0]  panel_disable,
    input  logic [11:0] cpu_addr,
    input  logic [7:0]  cpu_data,
    input  logic        cpu_write,
    output logic        cpu_write_accepted,
    output logic        panel_active,
    output logic [1:0]  panel_pixel,
    output logic [7:0]  palette_addr,
    output logic [7:0]  palette_raw,
    output logic [7:0]  panel_r,
    output logic [7:0]  panel_g,
    output logic [7:0]  panel_b,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write
);
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] panel_ram [0:4095];
    logic [3:0] radar_lopal [0:255];
    logic [3:0] radar_hipal [0:255];

    logic render_active;
    logic [7:0] render_row;
    logic [5:0] render_source_x;
    logic [3:0] render_column;
    logic [1:0] render_pixel_select;
    logic [11:0] render_addr;
    logic [7:0] panel_byte;
    logic active_latched;
    logic [7:0] row_latched;
    logic [1:0] pixel_select_latched;
    logic [1:0] selected_pixel;
    logic [7:0] selected_palette_addr;
    logic [7:0] selected_palette_raw;
    logic [2:0] fetch_phase;
    logic [8:0] normal_row_calc;
    logic [8:0] normal_source_x_calc;
    logic [8:0] flipped_row_calc;
    logic [8:0] flipped_source_x_calc;
    logic [7:0] normal_row;
    logic [5:0] normal_source_x;
    logic [7:0] flipped_row;
    logic [5:0] flipped_source_x;

    assign normal_row_calc       = vcount - 9'd26;
    assign normal_source_x_calc  = hcount - 9'd200;
    assign flipped_row_calc      = 9'd282 - vcount;
    assign flipped_source_x_calc = 9'd47 - hcount;
    assign normal_row            = normal_row_calc[7:0];
    assign normal_source_x       = normal_source_x_calc[5:0];
    assign flipped_row           = flipped_row_calc[7:0];
    assign flipped_source_x      = flipped_source_x_calc[5:0];

    // MAME accepts writes only for logical byte columns 1..14. Reads from
    // the CPU window remain unmapped in the board decoder and return $ff.
    assign cpu_write_accepted = cpu_write && (cpu_addr[3:0] >= 4'd1) &&
                                (cpu_addr[3:0] <= 4'd14);

    // Normal MAME clipping exposes bitmap X 8..55 at screen X 208..255.
    // Its flip copy reads the deliberately duplicated storage in reverse,
    // exposing bitmap X 47..0 at screen X 0..47. The duplicate is displaced
    // by one 384-pixel row, producing flipped logical rows 240 down to 17.
    always_comb begin
        render_active      = 1'b0;
        render_row         = 8'h00;
        render_source_x    = 6'd0;

        if (panel_disable == 8'h00) begin
            if (!flip_screen && (hcount >= 9'd208) && (hcount < 9'd256) &&
                (vcount >= 9'd42) && (vcount < 9'd266)) begin
                render_active   = 1'b1;
                render_row      = normal_row;
                render_source_x = normal_source_x;
            end else if (flip_screen && (hcount < 9'd48) &&
                         (vcount >= 9'd42) && (vcount < 9'd266)) begin
                render_active   = 1'b1;
                render_row      = flipped_row;
                render_source_x = flipped_source_x;
            end
        end
    end

    assign render_column = render_active ?
                           (render_source_x[5:2] + 1'd1) : 4'd0;
    assign render_pixel_select = render_active ? render_source_x[1:0] : 2'd0;
    assign render_addr = {render_row, render_column};
    assign selected_pixel =
        (pixel_select_latched == 2'd0) ? {panel_byte[4], panel_byte[0]} :
        (pixel_select_latched == 2'd1) ? {panel_byte[5], panel_byte[1]} :
        (pixel_select_latched == 2'd2) ? {panel_byte[6], panel_byte[2]} :
                                         {panel_byte[7], panel_byte[3]};
    assign selected_palette_addr = {row_latched[7:2], selected_pixel};
    assign selected_palette_raw = {radar_hipal[selected_palette_addr],
                                   radar_lopal[selected_palette_addr]};

    function automatic logic [7:0] expand_2bit(input logic [1:0] value);
        case (value)
            2'b00: expand_2bit = 8'd0;
            2'b01: expand_2bit = 8'd81;
            2'b10: expand_2bit = 8'd174;
            default: expand_2bit = 8'd255;
        endcase
    endfunction

    function automatic logic [7:0] expand_3bit(input logic [2:0] value);
        case (value)
            3'b000: expand_3bit = 8'd0;
            3'b001: expand_3bit = 8'd33;
            3'b010: expand_3bit = 8'd71;
            3'b011: expand_3bit = 8'd104;
            3'b100: expand_3bit = 8'd151;
            3'b101: expand_3bit = 8'd184;
            3'b110: expand_3bit = 8'd222;
            default: expand_3bit = 8'd255;
        endcase
    endfunction

    // Keep the memory access in the canonical single-clock synchronous-read
    // form accepted by Quartus 17. The array has no reset, preserving M10K
    // inference; panel_byte is not observable until the output pipeline has
    // latched a valid panel position.
    always_ff @(posedge clk) begin
        if (cpu_write_accepted)
            panel_ram[cpu_addr] <= cpu_data;

        if (ce_pixel)
            panel_byte <= panel_ram[render_addr];
    end

    // The same six-system-clock pixel schedule used by the playfield keeps
    // this independent Stage 6 stream ready for Stage 7.
    always_ff @(posedge clk) begin
        if (reset) begin
            active_latched      <= 1'b0;
            row_latched         <= 8'h00;
            pixel_select_latched <= 2'd0;
            fetch_phase         <= 3'd0;
            panel_active        <= 1'b0;
            panel_pixel         <= 2'd0;
            palette_addr        <= 8'h00;
            palette_raw         <= 8'h00;
            panel_r             <= 8'h00;
            panel_g             <= 8'h00;
            panel_b             <= 8'h00;
        end else if (ce_pixel) begin
            active_latched       <= render_active;
            row_latched          <= render_row;
            pixel_select_latched <= render_pixel_select;
            fetch_phase          <= 3'd1;
        end else begin
            case (fetch_phase)
                3'd1: fetch_phase <= 3'd2;
                3'd2: fetch_phase <= 3'd3;
                3'd3: fetch_phase <= 3'd4;
                3'd4: fetch_phase <= 3'd5;
                3'd5: begin
                    panel_active <= active_latched;
                    panel_pixel  <= selected_pixel;
                    palette_addr <= selected_palette_addr;
                    palette_raw  <= selected_palette_raw;
                    if (active_latched) begin
                        panel_r <= expand_2bit(selected_palette_raw[7:6]);
                        panel_g <= expand_3bit(selected_palette_raw[5:3]);
                        panel_b <= expand_3bit(selected_palette_raw[2:0]);
                    end else begin
                        panel_r <= 8'h00;
                        panel_g <= 8'h00;
                        panel_b <= 8'h00;
                    end
                    fetch_phase <= 3'd0;
                end
                default: fetch_phase <= 3'd0;
            endcase
        end
    end

    always_ff @(posedge download_clk) begin
        if (download_write) begin
            if ((download_addr >= 27'h20320) && (download_addr < 27'h20420))
                radar_lopal[download_addr[10:0] - 11'h320] <=
                    download_data[3:0];
            if ((download_addr >= 27'h20420) && (download_addr < 27'h20520))
                radar_hipal[download_addr[10:0] - 11'h420] <=
                    download_data[3:0];
        end
    end
endmodule
