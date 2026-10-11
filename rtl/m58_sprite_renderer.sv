`timescale 1ns/1ps
// Stage 4 emits an ordered stream of the 16 candidate pixels for every
// intersecting descriptor. Stage 5 will consume this stream into the two
// physical-style line buffers and decide transparency/overlap behavior.
module m58_sprite_renderer (
    input  logic        clk,
    input  logic        reset,
    input  logic        scan_start,
    input  logic [8:0]  scan_y,
    input  logic        flip_screen,
    output logic [4:0]  eval_index,
    input  logic        eval_valid,
    input  logic [7:0]  eval_y,
    input  logic [7:0]  eval_attr,
    input  logic [7:0]  eval_code,
    input  logic [7:0]  eval_x,
    output logic [12:0] gfx_addr,
    input  logic [7:0]  plane_2_left,
    input  logic [7:0]  plane_2_right,
    input  logic [7:0]  plane_1_left,
    input  logic [7:0]  plane_1_right,
    input  logic [7:0]  plane_0_left,
    input  logic [7:0]  plane_0_right,
    output logic        busy,
    output logic        scan_done,
    output logic        pixel_valid,
    output logic [7:0]  pixel_x,
    output logic [2:0]  pixel_pen,
    output logic [4:0]  pixel_color,
    output logic [4:0]  pixel_descriptor,
    output logic [8:0]  pixel_code,
    output logic [3:0]  pixel_row
);
    typedef enum logic [2:0] {
        IDLE,
        CHECK_DESCRIPTOR,
        FETCH_ROM,
        LOAD_SHIFTERS,
        SHIFT_PIXELS
    } state_t;

    state_t state;
    logic [4:0] descriptor_index;
    logic [8:0] scan_y_latched;
    logic flip_latched;
    logic [3:0] pixel_count;
    logic [4:0] color_latched;
    logic [4:0] descriptor_latched;
    logic [8:0] code_latched;
    logic [3:0] row_latched;
    logic signed [10:0] left_x_latched;
    logic flip_x_latched;
    logic [15:0] shift_plane_2;
    logic [15:0] shift_plane_1;
    logic [15:0] shift_plane_0;

    logic signed [10:0] top_y_calc;
    logic signed [10:0] line_calc;
    logic signed [10:0] left_x_calc;
    logic signed [10:0] dest_x_calc;
    logic descriptor_intersects;
    logic [4:0] source_line_calc;
    logic [7:0] base_code_calc;
    logic [8:0] gfx_code_calc;

    assign eval_index = descriptor_index;

    always @* begin
        top_y_calc = flip_latched
            ? (11'sd24 + $signed({3'b000, eval_y}))
            : (11'sd252 - $signed({3'b000, eval_y}));
        line_calc = $signed({2'b00, scan_y_latched}) - top_y_calc;
        descriptor_intersects = eval_valid &&
                                (line_calc >= 11'sd0) &&
                                (line_calc < 11'sd32);

        if (eval_attr[7] ^ flip_latched)
            source_line_calc = 5'd31 - line_calc[4:0];
        else
            source_line_calc = line_calc[4:0];

        base_code_calc = eval_code & 8'hbf;
        gfx_code_calc = {eval_attr[5], base_code_calc} +
                        (source_line_calc[4] ? 9'h040 : 9'h000);
        left_x_calc = flip_latched
            ? (11'sd240 - $signed({3'b000, eval_x}))
            : $signed({3'b000, eval_x});
        dest_x_calc = left_x_latched + $signed({7'b0000000, pixel_count});
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state               <= IDLE;
            descriptor_index    <= 5'd23;
            scan_y_latched      <= 9'd0;
            flip_latched        <= 1'b0;
            gfx_addr            <= 13'd0;
            busy                <= 1'b0;
            scan_done           <= 1'b0;
            pixel_valid         <= 1'b0;
            pixel_x             <= 8'd0;
            pixel_pen           <= 3'd0;
            pixel_color         <= 5'd0;
            pixel_descriptor    <= 5'd0;
            pixel_code          <= 9'd0;
            pixel_row           <= 4'd0;
            pixel_count         <= 4'd0;
            color_latched       <= 5'd0;
            descriptor_latched  <= 5'd0;
            code_latched        <= 9'd0;
            row_latched         <= 4'd0;
            left_x_latched      <= 11'sd0;
            flip_x_latched      <= 1'b0;
            shift_plane_2       <= 16'd0;
            shift_plane_1       <= 16'd0;
            shift_plane_0       <= 16'd0;
        end else begin
            scan_done   <= 1'b0;
            pixel_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (scan_start) begin
                        descriptor_index <= 5'd23;
                        scan_y_latched   <= scan_y;
                        flip_latched     <= flip_screen;
                        busy             <= 1'b1;
                        state            <= CHECK_DESCRIPTOR;
                    end
                end

                CHECK_DESCRIPTOR: begin
                    if (descriptor_intersects) begin
                        gfx_addr           <= {gfx_code_calc, source_line_calc[3:0]};
                        color_latched      <= eval_attr[4:0];
                        descriptor_latched <= descriptor_index;
                        code_latched       <= gfx_code_calc;
                        row_latched        <= source_line_calc[3:0];
                        left_x_latched     <= left_x_calc;
                        flip_x_latched     <= eval_attr[6] ^ flip_latched;
                        state              <= FETCH_ROM;
                    end else if (descriptor_index == 5'd0) begin
                        busy      <= 1'b0;
                        scan_done <= 1'b1;
                        state     <= IDLE;
                    end else begin
                        descriptor_index <= descriptor_index - 1'd1;
                    end
                end

                // One address clock plus one capture clock model the ROMs'
                // parallel fetch before loading the six logical shifters.
                FETCH_ROM: state <= LOAD_SHIFTERS;

                LOAD_SHIFTERS: begin
                    shift_plane_2 <= {plane_2_left, plane_2_right};
                    shift_plane_1 <= {plane_1_left, plane_1_right};
                    shift_plane_0 <= {plane_0_left, plane_0_right};
                    pixel_count   <= 4'd0;
                    state         <= SHIFT_PIXELS;
                end

                SHIFT_PIXELS: begin
                    if ((dest_x_calc >= 11'sd0) && (dest_x_calc < 11'sd256)) begin
                        pixel_valid      <= 1'b1;
                        pixel_x          <= dest_x_calc[7:0];
                        // Historical plane names identify fetch lanes, not
                        // numerical significance: ascending ROM groups carry
                        // pen bits 0,1,2 (MAME's first layout plane is MSB).
                        pixel_pen        <= flip_x_latched
                            ? {shift_plane_0[0], shift_plane_1[0], shift_plane_2[0]}
                            : {shift_plane_0[15], shift_plane_1[15], shift_plane_2[15]};
                        pixel_color      <= color_latched;
                        pixel_descriptor <= descriptor_latched;
                        pixel_code       <= code_latched;
                        pixel_row        <= row_latched;
                    end

                    if (flip_x_latched) begin
                        shift_plane_2 <= {1'b0, shift_plane_2[15:1]};
                        shift_plane_1 <= {1'b0, shift_plane_1[15:1]};
                        shift_plane_0 <= {1'b0, shift_plane_0[15:1]};
                    end else begin
                        shift_plane_2 <= {shift_plane_2[14:0], 1'b0};
                        shift_plane_1 <= {shift_plane_1[14:0], 1'b0};
                        shift_plane_0 <= {shift_plane_0[14:0], 1'b0};
                    end

                    if (pixel_count == 4'd15) begin
                        if (descriptor_index == 5'd0) begin
                            busy      <= 1'b0;
                            scan_done <= 1'b1;
                            state     <= IDLE;
                        end else begin
                            descriptor_index <= descriptor_index - 1'd1;
                            state            <= CHECK_DESCRIPTOR;
                        end
                    end else begin
                        pixel_count <= pixel_count + 1'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
