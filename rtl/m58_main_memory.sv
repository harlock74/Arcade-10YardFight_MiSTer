`timescale 1ns/1ps
module m58_main_memory #(parameter HISCORE_ENABLE = 0) (
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_do,
    input  logic        rom_read,
    input  logic        work_read,
    input  logic        work_write,
    output logic [7:0]  rom_data,
    output logic [7:0]  work_data,
    input  logic        hs_owns,
    input  logic [15:0] hs_manager_a,
    input  logic [7:0]  hs_manager_do,
    input  logic        hs_manager_rd_n,
    input  logic        hs_manager_wr_n,
    output logic [7:0]  hs_work_data,
    input  logic        download_clk,
    input  logic [26:0] download_addr,
    input  logic [7:0]  download_data,
    input  logic        download_write
);
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] program_rom [0:24575];
    wire hs_access = HISCORE_ENABLE && hs_owns;
    wire [11:0] work_addr = hs_access ? hs_manager_a[11:0] : cpu_addr[11:0];
    wire [7:0] work_write_data = hs_access ? hs_manager_do : cpu_do;
    wire work_read_selected = hs_access ? !hs_manager_rd_n : work_read;
    wire work_write_selected = hs_access ? !hs_manager_wr_n : work_write;
    wire [7:0] ram_read_data;
    logic reset_read_value;

    // Keep the reset/CPU/manager policy outside the RAM read register. The
    // memory itself has only one clocked read port and one clocked write port.
    // No reset or bus-owner policy is encoded inside the RAM template.
    m58_work_ram_4k work_ram_port (
        .clk,
        .read_enable(work_read_selected && !reset),
        .write_enable(work_write_selected && !reset),
        .address(work_addr),
        .write_data(work_write_data),
        .read_data(ram_read_data)
    );

    // Preserve the original registered FF-on-reset and hold-until-next-read
    // behavior without putting reset into the inferred-memory template.
    always_ff @(posedge clk) begin
        if (reset) reset_read_value <= 1'b1;
        else if (work_read_selected) reset_read_value <= 1'b0;
    end
    assign work_data = reset_read_value ? 8'hff : ram_read_data;
    assign hs_work_data = work_data;

    always_ff @(posedge download_clk) begin
        if (download_write && (download_addr < 27'h06000)) begin
            program_rom[download_addr[14:0]] <= download_data;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            rom_data  <= 8'hff;
        end else begin
            if (rom_read)  rom_data  <= program_rom[cpu_addr[14:0]];
        end
    end
endmodule

module m58_work_ram_4k (
    input  logic        clk,
    input  logic        read_enable,
    input  logic        write_enable,
    input  logic [11:0] address,
    input  logic [7:0]  write_data,
    output logic [7:0] read_data
);
    (* ramstyle = "M10K, no_rw_check" *) logic [7:0] work_ram [0:4095];

    always_ff @(posedge clk) begin
        if (read_enable) read_data <= work_ram[address];
        if (write_enable) work_ram[address] <= write_data;
    end
endmodule
