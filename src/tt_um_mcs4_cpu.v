//===========================================================
// Tiny Tapeout MCS-4 Project
//-----------------------------------------------------------
// File Name   : tt_um_mcs4_cpu.v
// Description : MCS-4 4004 CPU Chip
//-----------------------------------------------------------
// History :
// Rev.01 2025.08.01 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

`default_nettype none

//======================================
// Module : MCS-4 4004 CPU Chip
//======================================
module tt_um_mcs4_cpu
(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

integer i;

//---------------------
// Interface Signals
//---------------------
wire        sync_n;   // Sync Signal
wire [ 3:0] data_o;   // Data Output
wire        data_oe;  // Data Output Enable
wire [ 3:0] data_i;   // Data Input
wire        cm_rom_n; // Memory Control for ROM
wire [ 3:0] cm_ram_n; // Memory Control for RAM
wire        test;     // Test Input

//---------------------
// I/O Connection
//---------------------
assign test       = ui_in[0];
assign uo_out[0]  = sync_n;
assign uo_out[1]  = cm_rom_n;
assign uo_out[2]  = 1'b0;
assign uo_out[3]  = 1'b0;
assign uo_out[4]  = cm_ram_n[0];
assign uo_out[5]  = cm_ram_n[1];
assign uo_out[6]  = cm_ram_n[2];
assign uo_out[7]  = cm_ram_n[3];
assign data_i[0]  = uio_in[0];
assign data_i[1]  = uio_in[1];
assign data_i[2]  = uio_in[2];
assign data_i[3]  = uio_in[3];
assign uio_out[0] = 1'b0; // open drain
assign uio_out[1] = 1'b0; // open drain
assign uio_out[2] = 1'b0; // open drain
assign uio_out[3] = 1'b0; // open drain
assign uio_out[4] = 1'b0;
assign uio_out[5] = 1'b0;
assign uio_out[6] = 1'b0;
assign uio_out[7] = 1'b0;
assign uio_oe[0]  = data_oe & ~data_o[0]; // open drain
assign uio_oe[1]  = data_oe & ~data_o[1]; // open drain
assign uio_oe[2]  = data_oe & ~data_o[2]; // open drain
assign uio_oe[3]  = data_oe & ~data_o[3]; // open drain
assign uio_oe[4] = 1'b0;
assign uio_oe[5] = 1'b0;
assign uio_oe[6] = 1'b0;
assign uio_oe[7] = 1'b0;

// List all unused inputs to prevent warnings
wire _unused = &{ena, uio_in[7:4], 1'b0};

//--------------------
// MCS-4 4004 CPU Core
//--------------------
MCS4_CPU U_MCS4_CPU
(
    .CLK   (clk),      // clock
    .RES_N (rst_n),    // reset_n
    //
    .SYNC_N   (sync_n),   // Sync Signal
    .DATA_I   (data_i),   // Data Input
    .DATA_O   (data_o),   // Data Output
    .DATA_OE  (data_oe),  // Data Output Enable
    .CM_ROM_N (cm_rom_n), // Memory Control for ROM
    .CM_RAM_N (cm_ram_n), // Memory Control for RAM
    .TEST     (test)      // Test Input
);

endmodule
//===========================================================
// End of File
//===========================================================
