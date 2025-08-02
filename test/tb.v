//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_tb.v
// Description : Testbench of MCS-4 System
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.19 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

// This testbench just instantiates the module and makes some convenient wires
// that can be driven / tested by the cocotb test.py.

`default_nettype none
`timescale 1ns / 100ps

module tb ();

//-----------------------------
// Generate Wave File to Check
//-----------------------------
initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
end

//-----------------------
// Signals in TestBench
//-----------------------
wire        tb_res;
wire        tb_clk;
//
wire        sync_n;
//
wire [ 3:0] data;
//
wire        cm_rom_n;
wire [ 3:0] cm_ram_n;
wire        test;
//
wire [31:0] port_keyprt_cmd;
wire [31:0] port_keyprt_res;

//---------------------------------
// DUT : MCS-4 4004 CPU Chip
//---------------------------------
wire [7:0] ui_in;    // Dedicated inputs
wire [7:0] uo_out;   // Dedicated outputs
wire [7:0] uio_in;   // IOs: Input path
wire [7:0] uio_out;  // IOs: Output path
wire [7:0] uio_oe;   // IOs: Enable path (active high: 0=input, 1=output)
wire       ena;      // always 1 when the design is powered, so you can ignore it
wire       clk;      // clock
wire       rst_n;    // reset_n - low to reset
//
assign ui_in[0]    = test;
assign sync_n      = uo_out[0];
assign cm_rom_n    = uo_out[1];
assign cm_ram_n[0] = uo_out[4];
assign cm_ram_n[1] = uo_out[5];
assign cm_ram_n[2] = uo_out[6];
assign cm_ram_n[3] = uo_out[7];
assign uio_in[0]   = data[0];
assign uio_in[1]   = data[1];
assign uio_in[2]   = data[2];
assign uio_in[3]   = data[3];
assign data[0]     = (uio_oe[0])? uio_out[0] : 1'bz; // open drain
assign data[1]     = (uio_oe[1])? uio_out[1] : 1'bz; // open drain
assign data[2]     = (uio_oe[2])? uio_out[2] : 1'bz; // open drain
assign data[3]     = (uio_oe[3])? uio_out[3] : 1'bz; // open drain
assign ena         = 1'b1;
//
pullup(data[0]);
pullup(data[1]);
pullup(data[2]);
pullup(data[3]);
//
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif
//
// Instanciation of DUT
tt_um_mcs4_cpu U_MCS4_CPU(
    // Include power ports for the Gate Level test:
`ifdef GL_TEST
    .VPWR(VPWR),
    .VGND(VGND),
`endif
    .ui_in  (ui_in),    // Dedicated inputs
    .uo_out (uo_out),   // Dedicated outputs
    .uio_in (uio_in),   // IOs: Input path
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
    .ena    (ena),      // enable - goes high when design is selected
    .clk    (tb_clk),   // clock
    .rst_n  (~tb_res)   // not reset
);

//---------------------------------------------
// MCS-4 System ROM + RAM + Key&Printer I/F
//---------------------------------------------
wire [ 3:0] s_data_i;
wire [ 3:0] s_data_o;
wire        s_data_oe;
//
assign s_data_i[0] = data[0];
assign s_data_i[1] = data[1];
assign s_data_i[2] = data[2];
assign s_data_i[3] = data[3];
assign data[0]     = (s_data_oe & ~s_data_o[0])? 1'b0 : 1'bz;
assign data[1]     = (s_data_oe & ~s_data_o[1])? 1'b0 : 1'bz;
assign data[2]     = (s_data_oe & ~s_data_o[2])? 1'b0 : 1'bz;
assign data[3]     = (s_data_oe & ~s_data_o[3])? 1'b0 : 1'bz;
//
MCS4_SYS U_MCS4_SYS
(
    // CPU Interfface (i4004)
    .CLK   (tb_clk),  // clock
    .RES_N (~tb_res), // reset_n
    //
    .SYNC_N   (sync_n),    // Sync Signal
    //
    .DATA_I   (s_data_i),  // Data Input
    .DATA_O   (s_data_o),  // Data Output
    .DATA_OE  (s_data_oe), // Data Output Enable
    //
    .CM_ROM_N (cm_rom_n),  // Memory Control for ROM
    .CM_RAM_N (cm_ram_n),  // Memory Control for RAM
    .TEST     (test),      // Test Input
    //
    // Calculator Command : Host MCU (UI) --> MCS4_SYS
    .PORT_KEYPRT_CMD (port_keyprt_cmd),
    //
    // Calculator Response : MCS4_SYS --> Host MCU (UI)
    .PORT_KEYPRT_RES (port_keyprt_res),
    //
    // Initialization of ROM
    .ROM_INIT_ENB   (1'b0),    // Initialization Mode of MCS4 ROM
    .ROM_INIT_ADDR  (12'h000), // ROM Address during ROM_INIT_ENB
    .ROM_INIT_RE    (1'b0),    // Read ROM during ROM_INIT_ENB
    .ROM_INIT_WE    (1'b0),    // Write ROM during ROM_INIT_ENB
    .ROM_INIT_WDATA (8'h00),   // Write Data to ROM during ROM_INIT_ENB
    .ROM_INIT_RDATA ()         // Read Data from ROM during ROM_INIT_ENB
);

endmodule
//===========================================================
// End of File
//===========================================================
