//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_sys.v
// Description : MCS-4 System (i4001 + i4002 + i4003 + 141-PF)
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.25 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================
// This system includes followings.
// (1) MCS-4 Memory System: mcs4_mem.v 
//       MCS-4 ROM Chip: mcs4_rom.v  (i4001 x 16chips)
//       MCS-4 RAM Chip: mcs4_ram.v (i4002 x 8banks x 4chips)
// (2) Busicom Caluculator 141-PF Model
//       MCS-4 Shift Register Chip: mcs4_shifter (i4003 x 3chips) 
//
// Interface
// (1) CPU (i4004)
//    input  wire        CLK,      // clock
//    input  wire        RES_N,    // reset_n
//    //
//    input  wire        SYNC_N,   // Sync Signal
//    inout  wire [ 3:0] DATA,     // Data Input/Output
//    input  wire        CM_ROM_N, // Memory Control for ROM
//    input  wire [ 3:0] CM_RAM_N, // Memory Control for RAM
//    output wire        TEST      // Test Signal
// 
// (2) Calculator Command : Host MCU (UI) --> MCS4_SYS
//     input  wire [31:0] PORT_KEYPRT_CMD
//         bit31   : Enable KEYPRT
//         bit15   : Printer FIFO POP Request
//         bit14   : Paper Feed Request
//         bit13-12: Rounding Switch
//         bit11-08: Decimal Point Switch
//         bit07-00: Key Code
//
// (3) Calculator Response : MCS4_SYS --> Host MCU (UI)
//     output wire [31:0] PORT_KEYPRT_RES 
//         bit31   : Printer FIFO Data Ready
//         bit30-16: Printer Column_01_15
//         bit15-14: Printer Column_17_18
//         bit13-10: Printer Drum Count
//         bit09   : Printer Red Ribbon
//         bit08   : Printer Paper Feed
//         bit07   : Minus Sign Lamp
//         bit06   : Overflow Lamp
//         bit05   : Memory Lamp
//         bit04-01: unused
//         bit00   : Printer FIFO_POP Acknowledge

//---------------------------------------------
// MCS-4 System ROM + RAM + Key&Printer I/F
//---------------------------------------------
module MCS4_SYS
(
    // CPU Interface (i4004)
    input  wire        CLK,      // clock
    input  wire        RES_N,    // reset_n
    //
    input  wire        SYNC_N,   // Sync Signal
    //
    input  wire [ 3:0] DATA_I,   // Data Input
    output wire [ 3:0] DATA_O,   // Data Output
    output wire        DATA_OE,  // Data Output Enable
    //
    input  wire        CM_ROM_N, // Memory Control for ROM
    input  wire [ 3:0] CM_RAM_N, // Memory Control for RAM
    output wire        TEST,     // Test Input
    //
    // Calculator Command : Host MCU (UI) --> MCS4_SYS
    input  wire [31:0] PORT_KEYPRT_CMD,
    //
    // Calculator Response : MCS4_SYS --> Host MCU (UI)
    output wire [31:0] PORT_KEYPRT_RES,
    //
    // Initialization of ROM
    input  wire        ROM_INIT_ENB,   // Initialization Mode of MCS4 ROM
    input  wire [11:0] ROM_INIT_ADDR,  // ROM Address during ROM_INIT_ENB
    input  wire        ROM_INIT_RE,    // Read ROM during ROM_INIT_ENB
    input  wire        ROM_INIT_WE,    // Write ROM during ROM_INIT_ENB
    input  wire [ 7:0] ROM_INIT_WDATA, // Write Data to ROM during ROM_INIT_ENB
    output wire [ 7:0] ROM_INIT_RDATA  // Read Data from ROM during ROM_INIT_ENB
);

//---------------------
// Data Interface
//---------------------
wire [3:0] data_i_rom;
wire [3:0] data_o_rom;
wire       data_o_rom_oe;
wire [3:0] data_i_ram;
wire [3:0] data_o_ram;
wire       data_o_ram_oe;
//
assign data_i_rom = DATA_I;
assign data_i_ram = DATA_I;
assign DATA_O  = (data_o_rom_oe)? data_o_rom
               : (data_o_ram_oe)? data_o_ram
               : 4'b1111;
assign DATA_OE = data_o_rom_oe | data_o_ram_oe;

//----------------
// Decode CM_RAM 
//----------------
wire [7:0] cm_ram_n_decoded;
//
assign cm_ram_n_decoded
    = (CM_RAM_N == 4'b1110)? 8'b11111110 // bank0
    : (CM_RAM_N == 4'b1101)? 8'b11111101 // bank1
    : (CM_RAM_N == 4'b1011)? 8'b11111011 // bank2
    : (CM_RAM_N == 4'b1001)? 8'b11110111 // bank3
    : (CM_RAM_N == 4'b0111)? 8'b11101111 // bank4
    : (CM_RAM_N == 4'b0101)? 8'b11011111 // bank5
    : (CM_RAM_N == 4'b0011)? 8'b10111111 // bank6
    : (CM_RAM_N == 4'b0001)? 8'b01111111 // bank7
    : 8'b11111111;

//-----------------------
// I/O Signals
//-----------------------
wire [31:0] port_in_rom_chip7_chip0;
wire [31:0] port_in_rom_chipF_chip8;
wire [31:0] port_out_rom_chip7_chip0;
wire [31:0] port_out_rom_chipF_chip8;
wire [31:0] port_out_ram_bank1_bank0;
wire [31:0] port_out_ram_bank3_bank2;
wire [31:0] port_out_ram_bank5_bank4;
wire [31:0] port_out_ram_bank7_bank6;
//
wire enable_keyprt;
wire test_keyprt;
wire [31:0] port_in_rom_chip7_chip0_keyprt;
wire [31:0] port_in_rom_chipF_chip8_keyprt;
//
assign enable_keyprt = PORT_KEYPRT_CMD[31];
assign TEST = (enable_keyprt)? test_keyprt : 1'b0;
assign port_in_rom_chip7_chip0 = (enable_keyprt)? port_in_rom_chip7_chip0_keyprt : 32'h00000000;
assign port_in_rom_chipF_chip8 = (enable_keyprt)? port_in_rom_chipF_chip8_keyprt : 32'h00000000;

//-----------------------------
// ROM Chips (i4001 x 16chips)
//-----------------------------
MCS4_ROM U_MCS4_ROM
(
    .CLK     (CLK),
    .RES_N   (RES_N),
    .SYNC_N  (SYNC_N),
    .DATA_I  (data_i_rom),
    .DATA_O  (data_o_rom),
    .DATA_OE (data_o_rom_oe),
    .CM_N    (CM_ROM_N),
    .CL_N    ({16{RES_N}}),
    //
    .PORT_IN_ROM_CHIP7_CHIP0  (port_in_rom_chip7_chip0),
    .PORT_IN_ROM_CHIPF_CHIP8  (port_in_rom_chipF_chip8),
    .PORT_OUT_ROM_CHIP7_CHIP0 (port_out_rom_chip7_chip0),
    .PORT_OUT_ROM_CHIPF_CHIP8 (port_out_rom_chipF_chip8),
    //
    .ROM_INIT_ENB   (ROM_INIT_ENB),
    .ROM_INIT_ADDR  (ROM_INIT_ADDR),
    .ROM_INIT_RE    (ROM_INIT_RE),
    .ROM_INIT_WE    (ROM_INIT_WE),
    .ROM_INIT_WDATA (ROM_INIT_WDATA),
    .ROM_INIT_RDATA (ROM_INIT_RDATA)
);

//---------------------------------------
// RAM Chips (i4002 x 8banks x 4chips)
//---------------------------------------
MCS4_RAM U_MCS4_RAM
(
    .CLK     (CLK),
    .RES_N   (RES_N),
    .SYNC_N  (SYNC_N),
    .DATA_I  (data_i_ram),
    .DATA_O  (data_o_ram),
    .DATA_OE (data_o_ram_oe),
    .CM_N    (cm_ram_n_decoded),
    //
    .PORT_OUT_RAM_BANK1_BANK0 (port_out_ram_bank1_bank0),
    .PORT_OUT_RAM_BANK3_BANK2 (port_out_ram_bank3_bank2),
    .PORT_OUT_RAM_BANK5_BANK4 (port_out_ram_bank5_bank4),
    .PORT_OUT_RAM_BANK7_BANK6 (port_out_ram_bank7_bank6)
);

//----------------------------
// Key and Printer Interface
//----------------------------
KEY_PRINTER KEY_PRINTER
(
    .CLK     (CLK),
    .RES_N   (RES_N),
    .ENABLE  (enable_keyprt),
    .TEST    (test_keyprt),
    //
    .PORT_IN_ROM_CHIP7_CHIP0  (port_in_rom_chip7_chip0_keyprt),
    .PORT_IN_ROM_CHIPF_CHIP8  (port_in_rom_chipF_chip8_keyprt),
    .PORT_OUT_ROM_CHIP7_CHIP0 (port_out_rom_chip7_chip0),
    .PORT_OUT_ROM_CHIPF_CHIP8 (port_out_rom_chipF_chip8),
    .PORT_OUT_RAM_BANK1_BANK0 (port_out_ram_bank1_bank0),
    .PORT_OUT_RAM_BANK3_BANK2 (port_out_ram_bank3_bank2),
    .PORT_OUT_RAM_BANK5_BANK4 (port_out_ram_bank5_bank4),
    .PORT_OUT_RAM_BANK7_BANK6 (port_out_ram_bank7_bank6),
    //
    .PORT_KEYPRT_CMD (PORT_KEYPRT_CMD),
    .PORT_KEYPRT_RES (PORT_KEYPRT_RES)
);

//----------------------
// End of Module
//----------------------
endmodule

//===========================================================
// End of File
//===========================================================
