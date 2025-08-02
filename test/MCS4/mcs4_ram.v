//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_ram.v
// Description : MCS-4 RAM System (i4002 x 8banks x 4chips)
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.19 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

//-----------------------------------------------------------------
// In this module, full chips are included (8banks x 4chips),
// so there is no P0 input signal and Master-Slice P1 setting.
//-----------------------------------------------------------------

//---------------------------------
// MCS-4 RAM Chip i4002
//---------------------------------
module MCS4_RAM
(
    input  wire        CLK,     // Clock
    input  wire        RES_N,   // Reset
    //
    input  wire        SYNC_N,  // Sync Signal
    input  wire [ 3:0] DATA_I,  // Data Input
    output reg  [ 3:0] DATA_O,  // Data Output
    output reg         DATA_OE, // Data Output Enable
    input  wire [ 7:0] CM_N,    // Memory Control
    //
    output wire [31:0] PORT_OUT_RAM_BANK1_BANK0, // RAM Port Out, Bank1 - Bank0, Chip3 - Chip0, each 4bits
    output wire [31:0] PORT_OUT_RAM_BANK3_BANK2, // RAM Port Out, Bank3 - Bank2, Chip3 - Chip0, each 4bits
    output wire [31:0] PORT_OUT_RAM_BANK5_BANK4, // RAM Port Out, Bank5 - Bank4, Chip3 - Chip0, each 4bits
    output wire [31:0] PORT_OUT_RAM_BANK7_BANK6  // RAM Port Out, Bank7 - Bank6, Chip3 - Chip0, each 4bits
);

//-------------------------
// Signals for each Chip
//-------------------------
wire [3:0] data_o  [0:8][0:3]; // [bank][chip]
wire       data_oe [0:8][0:3]; // [bank][chip]
wire [3:0] port_out[0:8][0:3]; // [bank][chip]

//--------------------
// RAM Chips
//--------------------
generate 
    genvar b;
    for (b = 0; b < 8; b = b + 1)
    begin : RAM_BANK
        genvar c;
        for (c = 0; c < 4; c = c + 1)
        begin : RAM_CHIP
            MCS4_RAM_CHIP U_MCS4_RAM_CHIP
            (
                .CLK   (CLK),     // Clock
                .RES_N (RES_N),   // Reset
                //
                .SYNC_N  (SYNC_N),        // Sync Signal
                .DATA_I  (DATA_I),        // Data Input
                .DATA_O  (data_o [b][c]), // Data Output
                .DATA_OE (data_oe[b][c]), // Data Output Enable
                .CM_N    (CM_N[b]),       // Memory Control
                //
                .P0 ((c==0)?1'b0 : (c==1)?1'b1 : (c==2)?1'b0 : 1'b1), // Hard-wired Chip Select P0
                .P1 ((c==0)?1'b0 : (c==1)?1'b0 : (c==2)?1'b1 : 1'b1), // Metal Option Chip Select P1
                //
                .RAM_PORT_OUT (port_out[b][c]) // RAM Port Out
            );
        end
    end
endgenerate

//-------------------
// Data Output
//-------------------
integer bb ,cc;
always @*
begin
    DATA_O  = 4'b0000;
    DATA_OE = 1'b0;
    for (bb = 0; bb < 8; bb = bb + 1)
    begin
        for (cc = 0; cc < 4; cc = cc + 1)
        begin
            DATA_O  = DATA_O  | data_o [bb][cc];
            DATA_OE = DATA_OE | data_oe[bb][cc];
        end
    end
end

//-------------------
// Port Outputs
//-------------------
assign PORT_OUT_RAM_BANK7_BANK6 = {port_out[7][3], port_out[7][2], port_out[7][1], port_out[7][0],
                                   port_out[6][3], port_out[6][2], port_out[6][1], port_out[6][0]};
assign PORT_OUT_RAM_BANK5_BANK4 = {port_out[5][3], port_out[5][2], port_out[5][1], port_out[5][0],
                                   port_out[4][3], port_out[4][2], port_out[4][1], port_out[4][0]};
assign PORT_OUT_RAM_BANK3_BANK2 = {port_out[3][3], port_out[3][2], port_out[3][1], port_out[3][0],
                                   port_out[2][3], port_out[2][2], port_out[2][1], port_out[2][0]};
assign PORT_OUT_RAM_BANK1_BANK0 = {port_out[1][3], port_out[1][2], port_out[1][1], port_out[1][0],
                                   port_out[0][3], port_out[0][2], port_out[0][1], port_out[0][0]};


//===========================================================
endmodule
//===========================================================



//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_ram.v
// Description : MCS-4 RAM Chip (i4002)
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

//-----------------------------------------------------------------
// Notes on Chip Number of i4002
//-----------------------------------------------------------------
// As for real chip, the chip number is specified as follows.
//    Chip_#  4002_Option  P0_Input  {D3,D2}@X2   Master Slice P1
//         0    4002-1       GND       0  0       0
//         1    4002-1       VDD       0  1       0
//         2    4002-2       GND       1  0       1
//         3    4002-2       VDD       1  1       1
// In this module, full chips are included (8banks x 4chips),
// so there is no P0 input signal. 
//-----------------------------------------------------------------

//---------------------------------
// MCS-4 RAM Chip i4002 Chip
//---------------------------------
module MCS4_RAM_CHIP
(
    input  wire        CLK,     // Clock
    input  wire        RES_N,   // Reset
    //
    input  wire        SYNC_N,  // Sync Signal
    input  wire [ 3:0] DATA_I,  // Data Input
    output wire [ 3:0] DATA_O,  // Data Output
    output wire        DATA_OE, // Data Output Enable
    input  wire        CM_N,    // Memory Control
    //
    input  wire        P0,      // Hard-wired Chip Select P0
    input  wire        P1,      // Metal Option Chip Select P1
    //
    output wire [ 3:0] RAM_PORT_OUT // RAM Port Out
);

//-------------------------------------
// To Clear RAM Cell during Reset
//-------------------------------------
reg  reset_sync1;
reg  reset_sync2;
wire reset;
//
always @(posedge CLK)
begin
    reset_sync1 <= ~RES_N;
    reset_sync2 <= reset_sync1;
end
//
// A reset signal which negation edge is synchronized.
assign reset = ~RES_N | reset_sync2;
//
// Address Counter to Clear RAM Cell
reg [5:0] reset_addr_count;
always @(posedge CLK, negedge reset)
begin
    if (~reset)
        reset_addr_count <= 6'b000000;
    else
        reset_addr_count <= reset_addr_count + 6'b000001;
end

//-----------------------------
// RAM MAT
//-----------------------------
reg  [3:0] ram_ch[0:63]; // 64nibbles
reg  [3:0] ram_st[0:15]; // 16nibbles

//---------------------------------
// Synchronization and State Count
//---------------------------------
reg [7:0] state;
//
always @(posedge CLK, posedge reset)
begin
    if (reset)
        state <= 8'b00000000;
    else if (~SYNC_N)
        state <= 8'b00000001;    
    else if (SYNC_N & state[`X3]) // if no sync at X3,
        state <= 8'b00000000;     // it must be stop state
    else
        state <= {state[6:0], state[7]}; // rotate left
end

//------------------------
// SRC Address Latch
//------------------------
reg  [ 7:0] src;
reg         src_get;
//
always @(posedge CLK,posedge reset)
begin
    if (reset)
    begin
        src     <= 8'h00;
        src_get <= 1'b0;
    end
    else if (state[`X2] & (~&CM_N)) // if at least one cm asserted
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
always @(posedge CLK, posedge reset)
begin
    if (reset)
        opa <= 5'b00000;
    else if (state[`M2] & (~&CM_N))
        opa <= {1'b1, DATA_I};
    else if (state[`X3])
        opa <= 5'b00000;
end

//---------------------------
// Access RAM_CH
//---------------------------
wire [ 5:0] ram_ch_addr;
wire        ram_ch_re, ram_ch_we;
reg  [ 3:0] ram_ch_rdata;
wire [ 3:0] ram_ch_wdata;
wire [ 3:0] data_o_ram_ch;
wire        data_o_ram_ch_oe;
//
assign ram_ch_addr = (reset)? reset_addr_count : {src[5:0]};
assign ram_ch_re   = (reset)? 1'b0 :
                 (src[7:6] == {P1, P0}) &
                 ( state[`X1] & (opa == 5'b11001)    // RDM
                 | state[`X1] & (opa == 5'b11000)    // SBM
                 | state[`X1] & (opa == 5'b11011) ); // ADM
assign ram_ch_we   = (reset)? 1'b1: 
                 (src[7:6] == {P1, P0}) &
                 ( state[`X2] & (opa == 5'b10000) ); // WRM
assign ram_ch_wdata = (reset)? 4'b0000 : DATA_I;
//
always @(posedge CLK)
begin
    ram_ch_rdata <= ram_ch[ram_ch_addr];
    if (ram_ch_we) ram_ch[ram_ch_addr] <=ram_ch_wdata;
end
//
assign data_o_ram_ch_oe = (src[7:6] == {P1, P0}) &
                        ( state[`X2] & (opa == 5'b11001)    // RDM
                        | state[`X2] & (opa == 5'b11000)    // SBM
                        | state[`X2] & (opa == 5'b11011) ); // ADM
assign data_o_ram_ch = (data_o_ram_ch_oe)? ram_ch_rdata : 4'b0000;

//---------------------------
// Access RAM_ST
//---------------------------
wire [ 3:0] ram_st_addr;
wire        ram_st_re, ram_st_we;
reg  [ 3:0] ram_st_rdata;
wire [ 3:0] ram_st_wdata;
wire [ 3:0] data_o_ram_st;
wire        data_o_ram_st_oe;
//
assign ram_st_addr  = (reset)? reset_addr_count[3:0] : {src[5:4], opa[1:0]};
assign ram_st_re    = (reset)? 1'b0 : (src[7:6] == {P1, P0}) & state[`X1] & (opa[4:2] == 3'b111); // RD0-RD3
assign ram_st_we    = (reset)? 1'b1 : (src[7:6] == {P1, P0}) & state[`X2] & (opa[4:2] == 3'b101); // WR0-WR3
assign ram_st_wdata = (reset)? 4'b0000 : DATA_I;
//
always @(posedge CLK)
begin
    ram_st_rdata <= ram_st[ram_st_addr];
    if (ram_st_we) ram_st[ram_st_addr] <= ram_st_wdata;
end
//
assign data_o_ram_st_oe = (src[7:6] == {P1, P0}) & state[`X2] & (opa[4:2] == 3'b111); // RD0-RD3
assign data_o_ram_st = (data_o_ram_st_oe)? ram_st_rdata : 4'b0000;

//--------------------
// Data Bus Output
//--------------------
assign DATA_O  = data_o_ram_ch    | data_o_ram_st;
assign DATA_OE = data_o_ram_ch_oe | data_o_ram_st_oe;

//-----------------
// Output Port
//-----------------
reg [3:0] port_out;
//
always @(posedge CLK, posedge reset)
begin
	if (reset)
		port_out <= 4'b0000;
	else if (state[`X2] & (src[7:6] == {P1, P0}) & (opa == 5'b10001)) // WMP
		port_out <= DATA_I;
end
//
assign RAM_PORT_OUT = port_out;

//===========================================================
endmodule
//===========================================================
