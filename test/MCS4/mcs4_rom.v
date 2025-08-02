//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_rom.v
// Description : MCS-4 ROM Chip (i4001 x 16chips)
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.19 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

//---------------
// State Number
//---------------
`define A1 0
`define A2 1
`define A3 2
`define M1 3
`define M2 4
`define X1 5
`define X2 6
`define X3 7

//----------------------------------------------------------------------------------
// Assumed Configuration of Metal Option of i4001
//----------------------------------------------------------------------------------
// [1=Y] Port Output is Enabled 
// [2=N] Port Input is not inverted, and not pulled up/down.
// [3=Y] Port Output is connected to Positive Q of Output F/F.
// [4=N] Port Output is not connected to Negative Q of Output F/F.
// [5=Y] Port Input is connected to Mux directly.
// [6=N] Port Input is not inverted.
// [7=N] Port Input is not pulled up/down.
// [8=N] Port Input is not connted to Mux directry with pulled up/down.
// [9=N] Port Input is nort pulled down.
// [10=N] Port Input is not pulled up.
//----------------------------------------------------------------------------------
// Note : Both Port Input and Output are enabled, that is different from real chip.
//----------------------------------------------------------------------------------

//---------------------------------
// MCS-4 ROM Chip i4001
//---------------------------------
module MCS4_ROM
(
    input  wire        CLK,     // Clock
    input  wire        RES_N,   // Reset
    //
    input  wire        SYNC_N,  // Sync Signal
    input  wire [ 3:0] DATA_I,  // Data Input
    output wire [ 3:0] DATA_O,  // Data Output
    output wire        DATA_OE, // Data Output Enable
    input  wire        CM_N,    // Memory Control
    input  wire [15:0] CL_N,    // Clear Port Output
    //
    input  wire [31:0] PORT_IN_ROM_CHIP7_CHIP0,  // ROM Port In,  Chip7 - Chip0, each 4bits
    input  wire [31:0] PORT_IN_ROM_CHIPF_CHIP8,  // ROM Port In,  ChipF - Chip8, each 4bits
    output wire [31:0] PORT_OUT_ROM_CHIP7_CHIP0, // ROM Port Out, Chip7 - Chip0, each 4bits
    output wire [31:0] PORT_OUT_ROM_CHIPF_CHIP8, // ROM Port Out, ChipF - Chip8, each 4bits
    //
    input  wire        ROM_INIT_ENB,   // Initialization Mode of MCS4 ROM
    input  wire [11:0] ROM_INIT_ADDR,  // ROM Address during ROM_INIT_ENB
    input  wire        ROM_INIT_RE,    // Read ROM during ROM_INIT_ENB
    input  wire        ROM_INIT_WE,    // Write ROM during ROM_INIT_ENB
    input  wire [ 7:0] ROM_INIT_WDATA, // Write Data to ROM during ROM_INIT_ENB
    output wire [ 7:0] ROM_INIT_RDATA  // Read Data from ROM during ROM_INIT_ENB
);

//-----------------------------
// ROM MAT : 16chips x 256bytes
//-----------------------------
reg [7:0] rom[0:4095];
//
initial
begin
    $readmemh("./MCS4/4001.code", rom);
end

//---------------------------------
// Synchronization and State Count
//---------------------------------
reg [7:0] state;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        state <= 8'b00000000;
    else if (~SYNC_N)
        state <= 8'b00000001;
    else if (SYNC_N & state[`X3]) // if no sync at X3,
        state <= 8'b00000000;     // it must be stop state
    else
        state <= {state[6:0], state[7]}; // rotate left
end

//---------------------
// ROM Access from CPU
//---------------------
reg  [ 7:0] rom_addr_lsb;
wire [11:0] rom_addr;
wire        rom_re;
wire        rom_we;
reg  [ 7:0] rom_rdata;
wire [ 3:0] data_o_rom;
wire        data_o_rom_oe;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        rom_addr_lsb <= 8'h00;
    else if (state[`A1])
        rom_addr_lsb[ 3:0] <= DATA_I;
    else if (state[`A2])
        rom_addr_lsb[ 7:4] <= DATA_I;
end
//
assign rom_addr = (ROM_INIT_ENB)? ROM_INIT_ADDR
                                : ((state[`A3] & (CM_N == 1'b0))? {DATA_I, rom_addr_lsb} : 12'h000);
assign rom_re   = (ROM_INIT_ENB)? ROM_INIT_RE
                                : state[`A3] & (CM_N == 1'b0);
assign rom_we   = (ROM_INIT_ENB)? ROM_INIT_WE : 1'b0;
//
always @(posedge CLK)
begin
    if (rom_re) rom_rdata <= rom[rom_addr];
    if (rom_we) rom[rom_addr] <= ROM_INIT_WDATA;
end
//
assign data_o_rom = (state[`M1])? rom_rdata[7:4]
                  : (state[`M2])? rom_rdata[3:0]
                  : 4'b0000;
assign data_o_rom_oe = state[`M1] | state[`M2];
//
assign ROM_INIT_RDATA = rom_rdata;

//------------------------
// SRC Address Latch
//------------------------
reg  [ 7:0] src;
reg         src_get;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
    begin
        src     <= 8'h00;
        src_get <= 1'b0;
    end
    else if (state[`X2] & (CM_N == 1'b0))
    begin
        src[7:4] <= DATA_I;
        src_get <= 1'b1;
    end
    else if (state[`X3] & src_get)
    begin
        src[3:0] <= DATA_I;
        src_get <= 1'b0;
    end
end

//----------------------------------------------
// Snatch OPA during CPU's Instruction Fetch
//----------------------------------------------
reg [4:0] opa; // MSB means I/O instruction is executing.
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        opa <= 5'b00000;
    else if (state[`M2] & ~CM_N)
        opa <= {1'b1, DATA_I};
    else if (state[`X3])
        opa <= 5'b00000;
end

//-----------------
// Output Port
//-----------------
reg [3:0] port_out[0:15];
//
generate 
    genvar c; // chip
    for (c = 0; c < 16; c = c + 1)
    begin : PO_CHIP
        always @(posedge CLK, negedge RES_N)
        begin
            if (~RES_N)
                port_out[c] <= 4'b0000;
            else if (~CL_N[c])
                port_out[c] <= 4'b0000;
            else if (state[`X2] & (c == src[7:4]) & (opa == 5'b10010)) // WRR
                port_out[c] <= DATA_I;
        end
    end
endgenerate
//
assign PORT_OUT_ROM_CHIP7_CHIP0 = {port_out[ 7], port_out[ 6], port_out[ 5], port_out[ 4],
                                   port_out[ 3], port_out[ 2], port_out[ 1], port_out[ 0]};
assign PORT_OUT_ROM_CHIPF_CHIP8 = {port_out[15], port_out[14], port_out[13], port_out[12],
                                   port_out[11], port_out[10], port_out[ 9], port_out[ 8]};
                                   
//------------------
// Input Port
//------------------
wire [3:0] port_in[0:15];
reg  [3:0] port_in_sync[0:15];
wire       port_in_ena;
wire [3:0] data_o_port;
wire       data_o_port_oe;
//
assign port_in[ 0] = PORT_IN_ROM_CHIP7_CHIP0[ 3: 0];
assign port_in[ 1] = PORT_IN_ROM_CHIP7_CHIP0[ 7: 4];
assign port_in[ 2] = PORT_IN_ROM_CHIP7_CHIP0[11: 8];
assign port_in[ 3] = PORT_IN_ROM_CHIP7_CHIP0[15:12];
assign port_in[ 4] = PORT_IN_ROM_CHIP7_CHIP0[ 3: 0];
assign port_in[ 5] = PORT_IN_ROM_CHIP7_CHIP0[ 7: 4];
assign port_in[ 6] = PORT_IN_ROM_CHIP7_CHIP0[11: 8];
assign port_in[ 7] = PORT_IN_ROM_CHIP7_CHIP0[15:12];
assign port_in[ 8] = PORT_IN_ROM_CHIPF_CHIP8[ 3: 0];
assign port_in[ 9] = PORT_IN_ROM_CHIPF_CHIP8[ 7: 4];
assign port_in[10] = PORT_IN_ROM_CHIPF_CHIP8[11: 8];
assign port_in[11] = PORT_IN_ROM_CHIPF_CHIP8[15:12];
assign port_in[12] = PORT_IN_ROM_CHIPF_CHIP8[ 3: 0];
assign port_in[13] = PORT_IN_ROM_CHIPF_CHIP8[ 7: 4];
assign port_in[14] = PORT_IN_ROM_CHIPF_CHIP8[11: 8];
assign port_in[15] = PORT_IN_ROM_CHIPF_CHIP8[15:12];
//
generate 
    genvar i;
    for (i = 0; i < 16; i = i + 1)
    begin : PI_SYNC
        always @(posedge CLK, negedge RES_N)
        begin
            if (~RES_N)
                port_in_sync[i] <= 4'b0000;
            else
                port_in_sync[i] <= port_in[i];
        end
    end
endgenerate
//
assign port_in_ena = state[`X2] & (opa == 5'b11010);
assign data_o_port = // RDR
    (port_in_ena & (src[7:4] == 4'b0000))? port_in_sync[ 0]
  : (port_in_ena & (src[7:4] == 4'b0001))? port_in_sync[ 1]
  : (port_in_ena & (src[7:4] == 4'b0010))? port_in_sync[ 2]
  : (port_in_ena & (src[7:4] == 4'b0011))? port_in_sync[ 3]
  : (port_in_ena & (src[7:4] == 4'b0100))? port_in_sync[ 4]
  : (port_in_ena & (src[7:4] == 4'b0101))? port_in_sync[ 5]
  : (port_in_ena & (src[7:4] == 4'b0110))? port_in_sync[ 6]
  : (port_in_ena & (src[7:4] == 4'b0111))? port_in_sync[ 7]
  : (port_in_ena & (src[7:4] == 4'b1000))? port_in_sync[ 8]
  : (port_in_ena & (src[7:4] == 4'b1001))? port_in_sync[ 9]
  : (port_in_ena & (src[7:4] == 4'b1010))? port_in_sync[10]
  : (port_in_ena & (src[7:4] == 4'b1011))? port_in_sync[11]
  : (port_in_ena & (src[7:4] == 4'b1100))? port_in_sync[12]
  : (port_in_ena & (src[7:4] == 4'b1101))? port_in_sync[13]
  : (port_in_ena & (src[7:4] == 4'b1110))? port_in_sync[14]
  : (port_in_ena & (src[7:4] == 4'b1111))? port_in_sync[15]
  : 4'b0000;
assign data_o_port_oe = port_in_ena;

//----------------------
// Data Bus Output
//----------------------
assign DATA_O  = data_o_rom    | data_o_port;
assign DATA_OE = data_o_rom_oe | data_o_port_oe;

//===========================================================
endmodule
//===========================================================
