`timescale 1ns/1ps
// MiSTer NVRAM index 4, 320 bytes. Versioned, parent-set-specific CRC32
// envelope. A completed FPGA upload is not a disk-write acknowledgement.
module m58_hiscore_packet (
    input  wire        clk, cold_reset,
    input  wire        download, upload, wr, rd,
    input  wire [15:0] index,
    input  wire [26:0] address,
    input  wire [7:0]  data,
    input  wire        save_action, autosave_on, restore_lock, cancel_capture,
    input  wire        capture_begin, capture_write, capture_end,
    input  wire [8:0]  capture_address,
    input  wire [7:0]  capture_data,
    output wire        staging_busy,
    input  wire [8:0]  restore_address,
    output wire [7:0]  restore_data,
    output wire [7:0]  upload_data,
    output reg         upload_request = 0,
    output reg         valid = 0
);
    localparam [1:0] QUIET=0, VERIFY=1, BUILD=2, PUBLISH=3;
    reg [1:0] phase = QUIET;
    reg [7:0] staged [0:319];
    reg [7:0] published [0:319];
    reg [7:0] upload_snapshot [0:319];
    reg [7:0] captured [0:296];
    reg prev_download = 0, prev_upload = 0, prev_save = 0;
    reg receive = 0, capturing = 0, capture_bad = 0;
    reg [8:0] receive_count = 0, capture_count = 0, check_pos = 0;
    reg [2:0] entry_field = 0;
    reg [31:0] crc = 32'hffffffff;
    reg check_ok = 0, local_packet = 0, local_diff = 0;
    reg local_changed = 0, dirty = 0, request_sent = 0, manual_pending = 0;
    reg [31:0] generation = 0, uploaded_generation = 0;
    reg [8:0] delivered = 0;
    reg upload_bad = 0, upload_valid = 0;
    integer k;

    assign staging_busy = receive || capturing || phase != QUIET;
    assign restore_data = valid && restore_address < 9'd297 ?
                          published[16 + restore_address] : 8'd0;
    assign upload_data = index == 16'd4 && address < 27'd320 ?
                         (upload ? (upload_valid ? upload_snapshot[address[8:0]] : 8'd0) :
                          (valid ? published[address[8:0]] : 8'd0)) : 8'd0;

    function automatic [31:0] crc_byte(input [31:0] c, input [7:0] b);
        reg [31:0] v;
        integer j;
        begin
            v = c ^ {24'd0,b};
            for (j=0;j<8;j=j+1) v = v[0] ? (v >> 1) ^ 32'hedb88320 : v >> 1;
            crc_byte = v;
        end
    endfunction
    function automatic [7:0] crc_octet(input [31:0] c, input [1:0] n);
        begin
            case (n)
                0:crc_octet=c[7:0];
                1:crc_octet=c[15:8];
                2:crc_octet=c[23:16];
                default:crc_octet=c[31:24];
            endcase
        end
    endfunction
    function automatic [7:0] fixed_byte(input [8:0] n);
        begin
            case (n)
                0:fixed_byte="Y"; 1:fixed_byte="F";
                2:fixed_byte="H"; 3:fixed_byte="S";
                4:fixed_byte=8'd1;
                5:fixed_byte="1"; 6:fixed_byte="0";
                7:fixed_byte="Y"; 8:fixed_byte="A";
                9:fixed_byte="R"; 10:fixed_byte="D";
                11:fixed_byte=8'h29; 12:fixed_byte=8'h01; // 297 bytes
                13,14,15,317,318,319:fixed_byte=0;
                default:fixed_byte=0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        prev_download <= download;
        prev_upload <= upload;
        prev_save <= save_action;
        upload_request <= 0;
        if (cold_reset) begin
            valid <= 0;
            receive <= 0;
            capturing <= 0;
            phase <= QUIET;
            receive_count <= 0;
            capture_count <= 0;
            entry_field <= 0;
            local_changed <= 0;
            dirty <= 0;
            request_sent <= 0;
            manual_pending <= 0;
            generation <= 0;
            delivered <= 0;
            upload_valid <= 0;
            prev_download <= download;
            prev_upload <= upload;
        end else begin
            if (save_action && !prev_save && valid) begin
                manual_pending <= 1;
                request_sent <= 0;
            end
            if (valid && ((dirty && autosave_on) || manual_pending) &&
                !request_sent && !upload) begin
                upload_request <= 1;
                request_sent <= 1;
                manual_pending <= 0;
            end
            if (upload && !prev_upload) begin
                for (k=0;k<320;k=k+1) upload_snapshot[k] <= published[k];
                uploaded_generation <= generation;
                upload_valid <= valid;
                upload_bad <= index != 16'd4;
                delivered <= 0;
            end
            if (upload && index != 16'd4) upload_bad <= 1;
            // Address zero is the host's prefetch. Each rd advances to 1..320.
            if (upload && rd && address != 0) begin
                if (index == 16'd4 && address == {18'd0,delivered} + 1 &&
                    delivered < 9'd320) delivered <= delivered + 1'b1;
                else upload_bad <= 1;
            end
            if (!upload && prev_upload) begin
                request_sent <= 0;
                if (upload_valid && !upload_bad && delivered == 9'd320 &&
                    uploaded_generation == generation) dirty <= 0;
            end

            if (download && !prev_download) begin
                receive <= index == 16'd4 && phase == QUIET && !capturing && !local_changed;
                receive_count <= 0;
            end
            if (download && wr && index == 16'd4 &&
                (receive || (!prev_download && phase == QUIET && !capturing && !local_changed))) begin
                if (address == (prev_download ? {18'd0,receive_count} : 27'd0) &&
                    address < 27'd320) begin
                    staged[address[8:0]] <= data;
                    receive_count <= (prev_download ? receive_count : 9'd0) + 1'b1;
                end else receive <= 0;
            end
            if (receive && download && index != 16'd4) receive <= 0;
            if (!download && prev_download && receive) begin
                receive <= 0;
                if (receive_count == 9'd320) begin
                    phase <= VERIFY;
                    check_pos <= 0;
                    entry_field <= 0;
                    crc <= 32'hffffffff;
                    check_ok <= 1;
                    local_packet <= 0;
                end
            end

            if (capture_begin) begin
                capturing <= 1;
                capture_bad <= 0;
                capture_count <= 0;
                receive <= 0;
                phase <= QUIET;
            end
            if (capturing && capture_write) begin
                if (capture_address == capture_count && capture_count < 9'd297) begin
                    captured[capture_address] <= capture_data;
                    capture_count <= capture_count + 1'b1;
                end else capture_bad <= 1;
            end
            if (cancel_capture) begin
                capturing <= 0;
                capture_bad <= 1;
            end
            if (capturing && capture_end && !cancel_capture) begin
                capturing <= 0;
                if (!capture_bad && capture_count == 9'd297) begin
                    for (k=0;k<16;k=k+1) staged[k] <= fixed_byte(k[8:0]);
                    for (k=0;k<297;k=k+1) staged[16+k] <= captured[k];
                    for (k=317;k<320;k=k+1) staged[k] <= 0;
                    local_diff <= !valid;
                    for (k=0;k<297;k=k+1)
                        if (valid && captured[k] != published[16+k]) local_diff <= 1;
                    phase <= BUILD;
                    check_pos <= 0;
                    entry_field <= 0;
                    crc <= 32'hffffffff;
                    check_ok <= 1;
                    local_packet <= 1;
                end
            end
            if ((phase == VERIFY || phase == BUILD) && !capture_begin &&
                !(capturing && capture_end)) begin
                if (check_pos < 9'd313) crc <= crc_byte(crc, staged[check_pos]);
                if (check_pos >= 9'd19 && check_pos <= 9'd312)
                    entry_field <= entry_field == 3'd5 ? 3'd0 : entry_field + 1'b1;
                if (check_pos >= 9'd16 && check_pos <= 9'd312) begin
                    if (check_pos < 9'd19 || entry_field < 3) begin
                        if (staged[check_pos][3:0] > 9 || staged[check_pos][7:4] > 9)
                            check_ok <= 0;
                    end else if (staged[check_pos] != 0 &&
                                 (staged[check_pos] < 8'h41 || staged[check_pos] > 8'h5c))
                        check_ok <= 0;
                end
                if (check_pos == 9'd319 &&
                    (staged[16] != staged[19] || staged[17] != staged[20] ||
                     staged[18] != staged[21])) check_ok <= 0;
                if (phase == VERIFY) begin
                    if ((check_pos < 9'd16 || check_pos >= 9'd317) &&
                        staged[check_pos] != fixed_byte(check_pos)) check_ok <= 0;
                    if (check_pos >= 9'd313 && check_pos <= 9'd316 &&
                        staged[check_pos] != crc_octet(~crc,check_pos[1:0]-2'd1))
                        check_ok <= 0;
                end else if (check_pos >= 9'd313 && check_pos <= 9'd316)
                    staged[check_pos] <= crc_octet(~crc,check_pos[1:0]-2'd1);
                if (check_pos == 9'd319) phase <= PUBLISH;
                else check_pos <= check_pos + 1'b1;
            end
            if (phase == PUBLISH && !restore_lock && !capture_begin) begin
                phase <= QUIET;
                if (local_packet) begin
                    if (local_diff && check_ok) begin
                        for (k=0;k<320;k=k+1) published[k] <= staged[k];
                        valid <= 1;
                        local_changed <= 1;
                        dirty <= 1;
                        request_sent <= 0;
                        generation <= generation + 1'b1;
                    end
                end else if (check_ok && !local_changed) begin
                    for (k=0;k<320;k=k+1) published[k] <= staged[k];
                    valid <= 1;
                    generation <= generation + 1'b1;
                end
            end
        end
    end
endmodule
