`timescale 1ns/1ps
// 10yard (World, set 1) high-score controller. No second work-RAM port.
// The 49 ranked, six-byte records occupy E600-E725. E726-E72B is the
// insertion scratch record and is deliberately not persisted. E008-E00A is
// the separate displayed best-score buffer. See docs/hiscore_persistence.md.
module m58_hiscore (
    input  wire        clk,
    input  wire        cold_reset,
    input  wire        game_reset,
    input  wire        download,
    input  wire        upload,
    input  wire        wr,
    input  wire        rd,
    input  wire [15:0] index,
    input  wire [26:0] address,
    input  wire [7:0]  data,
    input  wire        save_action,
    input  wire        autosave_on,
    input  wire [15:0] cpu_a,
    input  wire [7:0]  cpu_di,
    input  wire        m1_n,
    input  wire        mreq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    input  wire        busak_n,
    output wire        busrq_n,
    output wire        owns,
    output wire [15:0] manager_a,
    output wire [7:0]  manager_do,
    output wire        manager_rd_n,
    output wire        manager_wr_n,
    output wire [7:0]  upload_data,
    output wire        upload_request,
    output wire        valid,
    output wire        fault
);
    // CRC32 of the complete, independently verified 0x20520-byte parent
    // MRA stream, not just its first three program ROMs.
    reg rom_previous = 0, qualified = 0, rom_bad = 0;
    reg [26:0] rom_count = 0;
    reg [31:0] rom_crc = 32'hffffffff;
    wire rom_selected = download && index == 16'd0;
    function automatic [31:0] crc_byte(input [31:0] c, input [7:0] b);
        reg [31:0] v;
        integer j;
        begin
            v = c ^ {24'd0,b};
            for (j=0;j<8;j=j+1) v = v[0] ? (v >> 1) ^ 32'hedb88320 : v >> 1;
            crc_byte = v;
        end
    endfunction
    always @(posedge clk) begin
        rom_previous <= rom_selected;
        if (cold_reset) begin
            qualified <= 0;
            rom_bad <= 0;
            rom_count <= 0;
            rom_crc <= 32'hffffffff;
            rom_previous <= 0;
        end else begin
            if (rom_selected && !rom_previous) begin
                qualified <= 0;
                rom_bad <= 0;
                rom_count <= 0;
                rom_crc <= 32'hffffffff;
            end
            if (rom_selected && wr) begin
                if (address == (rom_previous ? rom_count : 27'd0) && address < 27'h20520) begin
                    rom_count <= (rom_previous ? rom_count : 27'd0) + 1'b1;
                    rom_crc <= crc_byte(rom_previous ? rom_crc : 32'hffffffff, data);
                end else rom_bad <= 1;
            end
            if (rom_previous && !rom_selected)
                qualified <= !rom_bad && rom_count == 27'h20520 && ~rom_crc == 32'h38a78782;
        end
    end

    wire capture_begin, capture_write, capture_end, restore_lock, staging_busy;
    wire packet_valid;
    assign valid = packet_valid && qualified;
    wire [8:0] capture_address, restore_address;
    wire [7:0] capture_data, restore_data;
    m58_hiscore_packet packet (
        .clk, .cold_reset, .download, .upload, .wr, .rd, .index,
        .address, .data, .save_action(save_action && qualified),
        .autosave_on(autosave_on && qualified), .restore_lock,
        .cancel_capture(game_reset || !qualified),
        .capture_begin, .capture_write, .capture_end,
        .capture_address, .capture_data, .staging_busy,
        .restore_address, .restore_data, .upload_data,
        .upload_request, .valid(packet_valid)
    );
    m58_hiscore_manager manager (
        .clk, .reset(game_reset), .qualified(qualified && !rom_selected),
        .cpu_a, .cpu_di, .m1_n, .mreq_n, .rd_n, .wr_n,
        .busak_n, .published_valid(packet_valid), .staging_busy,
        .restore_data, .restore_address,
        .capture_begin, .capture_write, .capture_end,
        .capture_address, .capture_data,
        .busrq_n, .owns, .restore_lock,
        .manager_a, .manager_do, .manager_rd_n, .manager_wr_n, .fault
    );
endmodule

module m58_hiscore_manager (
    input  wire        clk, reset, qualified,
    input  wire [15:0] cpu_a,
    input  wire [7:0]  cpu_di,
    input  wire        m1_n, mreq_n, rd_n, wr_n, busak_n,
    input  wire        published_valid, staging_busy,
    input  wire [7:0]  restore_data,
    output wire [8:0]  restore_address,
    output reg         capture_begin = 0, capture_write = 0, capture_end = 0,
    output reg [8:0]   capture_address = 0,
    output reg [7:0]   capture_data = 0,
    output wire        busrq_n, owns, restore_lock,
    output wire [15:0] manager_a,
    output wire [7:0]  manager_do,
    output wire        manager_rd_n, manager_wr_n,
    output reg         fault = 0
);
    localparam [4:0] IDLE=0, GRANT=1, DRAIN1=2, DRAIN2=3,
        START=4, READ1=5, READ2=6, READ3=7, READ4=8, NEXT=9,
        WRITE1=10, WRITE2=11, WRITE_NEXT=12,
        CHECK1=13, CHECK2=14, CHECK3=15, CHECK4=16, CHECK_NEXT=17,
        FINISH=18, RELEASE1=19, RELEASE2=20;
    reg [4:0] state = IDLE;
    reg [8:0] pos = 0;
    reg [13:0] budget = 0;
    reg restoring = 0;
    reg initialized = 0, restored_this_boot = 0, score_touched = 0;
    reg pending_capture = 0, fetch_seen = 0, write_seen = 0;
    wire fetching = !m1_n && !mreq_n && !rd_n && wr_n;
    wire writing = !mreq_n && !wr_n && rd_n;
    assign busrq_n = state == IDLE || fault;
    assign owns = state >= START && state <= FINISH && !fault;
    assign restore_lock = restoring && state != IDLE;
    assign restore_address = pos;
    assign manager_a = pos < 9'd3 ? (16'he008 + {7'd0,pos}) :
                       (16'he600 + {7'd0,(pos - 9'd3)});
    assign manager_do = restore_data;
    assign manager_rd_n = !(state == READ1 || state == READ2 ||
                             state == READ3 || state == READ4 ||
                             state == CHECK1 || state == CHECK2 ||
                             state == CHECK3 || state == CHECK4);
    assign manager_wr_n = state != WRITE1;

    always @(posedge clk) begin
        capture_begin <= 0;
        capture_write <= 0;
        capture_end <= 0;
        fetch_seen <= fetching;
        write_seen <= writing;
        if (reset || !qualified) begin
            state <= IDLE;
            pos <= 0;
            budget <= 0;
            restoring <= 0;
            initialized <= 0;
            restored_this_boot <= 0;
            score_touched <= 0;
            pending_capture <= 0;
            fetch_seen <= 0;
            write_seen <= 0;
            fault <= 0;
        end else begin
            if (state == IDLE) budget <= 0;
            else if (budget == 14'd16383) begin
                fault <= 1;
                state <= IDLE;
            end else budget <= budget + 1'b1;
            if (state == IDLE && busak_n) begin
                // 0086 is the opcode immediately following CALL 04AC, whose
                // clear/default routine returns only after 3C00 completes.
                if (fetching && !fetch_seen && cpu_a == 16'h0086) begin
                    initialized <= 1;
                    restored_this_boot <= 0;
                    score_touched <= 0;
                    pending_capture <= 0;
                end
                // 3D55 is reached after initials editing is committed. The
                // game has finished insertion before this instruction.
                if (fetching && !fetch_seen && cpu_a == 16'h3d55 && initialized)
                    pending_capture <= 1;
                if (writing && !write_seen && initialized &&
                    ((cpu_a >= 16'he600 && cpu_a <= 16'he725) ||
                     (cpu_a >= 16'he008 && cpu_a <= 16'he00a)))
                    score_touched <= 1;
            end
            if (!fault) case (state)
                IDLE: begin
                    if (initialized && published_valid && !restored_this_boot &&
                        !score_touched && !staging_busy) begin
                        restoring <= 1;
                        pos <= 0;
                        state <= GRANT;
                    end else if (pending_capture && !staging_busy) begin
                        restoring <= 0;
                        pos <= 0;
                        state <= GRANT;
                        pending_capture <= 0;
                    end
                end
                GRANT: if (!busak_n && mreq_n && rd_n && wr_n) state <= DRAIN1;
                DRAIN1: state <= DRAIN2;
                DRAIN2: state <= START;
                START: begin
                    if (!restoring) capture_begin <= 1;
                    state <= restoring ? WRITE1 : READ1;
                end
                READ1: state <= READ2;
                READ2: state <= READ3;
                READ3: state <= READ4;
                READ4: begin
                    capture_address <= pos;
                    capture_data <= cpu_di;
                    capture_write <= 1;
                    state <= NEXT;
                end
                NEXT: if (pos == 9'd296) state <= FINISH;
                      else begin pos <= pos + 1'b1; state <= READ1; end
                WRITE1: state <= WRITE2;
                WRITE2: state <= WRITE_NEXT;
                WRITE_NEXT: if (pos == 9'd296) begin pos <= 0; state <= CHECK1; end
                            else begin pos <= pos + 1'b1; state <= WRITE1; end
                CHECK1: state <= CHECK2;
                CHECK2: state <= CHECK3;
                CHECK3: state <= CHECK4;
                CHECK4: begin
                    if (cpu_di != restore_data) fault <= 1;
                    state <= CHECK_NEXT;
                end
                CHECK_NEXT: if (pos == 9'd296) state <= FINISH;
                            else begin pos <= pos + 1'b1; state <= CHECK1; end
                FINISH: begin
                    if (restoring) restored_this_boot <= 1;
                    else capture_end <= 1;
                    state <= RELEASE1;
                end
                RELEASE1: state <= RELEASE2;
                RELEASE2: state <= IDLE;
                default: begin fault <= 1; state <= IDLE; end
            endcase
        end
    end
endmodule
