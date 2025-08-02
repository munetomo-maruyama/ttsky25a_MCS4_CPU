//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : key_printer.v
// Description : Calculator Peripherals for MCS-4 System
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.19 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

//---------------------------------------------
// KEY Matrix and Printer
//---------------------------------------------
// TEST_IN       : Printer Drum Sector Signal (28ms/35.7Hz)
// ROM0_OUT bit0 : Keyboard Column Shift Clock (i4003-0)
//          bit1 : Keyboard and Printer Shift In Data (i4003-0/i4003-1)
//          bit2 : Printer Column Shift Clock (i4003-1/i4003-2)
//          bit3 : not used
// ROM1_IN  bit0 : Keyboard Row Input0
//          bit1 : Keyboard Row Input1
//          bit2 : Keyboard Row Input2
//          bit3 : Keyboard Row Input3
// ROM2_IN  bit0 : Printer Drum Index Signal (13*28=364ms/2.74Hz) shows 1st row
//          bit1 : not used
//          bit2 : not used
//          bit3 : Printer Paper Feed Button Input (Positive Level)
// RAM0_OUT bit0 : Printing Color (0=black, 1=red)
//          bit1 : Fire Print Hammers
//          bit2 : not used
//          bit3 : Advance the Printer Paper
// RAM1_OUT bit0 : Memory Lamp
//          bit1 : Overflow Lamp
//          bit2 : Minu Sign Lamp
//          bit3 : not used
//---------------------------------------------
// Shift Register
// i4003-0 Keyboard Column
//     E       : VDD
//     CP      : ROM0_OUT bit0
//     DATAIN  : ROM0_OUT bit1 (common)
//     DATAOUT : open
//     Q       : KBC9-KBC0 (bit9-bit0)
// i4003-1 Printer Column LSB
//     E(fire) : RAM0_OUT bit1
//     CP      : ROM0_OUT bit2
//     DATAIN  : ROM0_OUT bit1 (common)
//     DATAOUT : i4003-2 DATAIN
//     Q       : PRS09-PRS00 (bit9-bit0)
// i4003-2 Printer Column MSB
//     E(fire) : RAM0_OUT bit1
//     CP      : ROM0_OUT bit2
//     DATAIN  : i4003-1 DATAOUT
//     DATAOUT : open
//     Q       : PRS19-PRS10 (bit9-bit0)
//---------------------------------------------
// Key Matrix
//              KBC9 KBC8 KBC7 KBC6 KBC5 KBC4 KBC3 KBC2 KBC1 KBC0
// ROM1_IN bit0 RSW1 DP0  SIGN  7    8    9    -    #   SQRT CM   KBR0
// ROM1_IN bit1 (  ) DP1  EX    4    5    6    +    /    %   RM   KBR1
// ROM1_IN bit2 (  ) DP2  CE    1    2    3   (  )  *   M=-  M=   KBR2
// ROM1_IN bit3 RSW2 DP3  C     0    00   .   (  )  =   M=+  M+   KBR3
//---------------------------------------------
// Printer
//     TEST_IN      : Printer Drum Sector Signal         (Original Period=28ms)
//     ROM2_IN bit0 : Printer Drum Index(1st Row) Signal (Original Period=28x13=364ms)
//
// Drum     COL01 ... COL15 COL16 COL17 COL18
//          PRS03 ... PRS17       PRS00 PRS01
// sector00   0   000   0   none    d     #  ---- index
// sector01   1   111   1   none    +     *
// sector02   2   222   2   none    -     I
// sector03   3   333   3   none    X     II
// sector04   4   444   4   none    /     III
// sector05   5   555   5   none    M+    M+
// sector06   6   666   6   none    M-    M-
// sector07   7   777   7   none    ^     T
// sector08   8   888   8   none    =     K
// sector09   9   999   9   none    SQ    E
// sector10   .   ...   .   none    %     Ex
// sector11   .   ...   .   none    C     C
// sector12   -   ...   -   none    R     M
//---------------------------------------------

module KEY_PRINTER
(
    input  wire CLK,    // Clock
    input  wire RES_N,  // Reset
    input  wire ENABLE, // Enable Key and Printer
    output wire TEST,   // TEST pin of CPU
    //
    output wire [31:0] PORT_IN_ROM_CHIP7_CHIP0,  // ROM Port In,  Chip7 - Chip0, each 4bits
    output wire [31:0] PORT_IN_ROM_CHIPF_CHIP8,  // ROM Port In,  ChipF - Chip8, each 4bits
    input  wire [31:0] PORT_OUT_ROM_CHIP7_CHIP0, // ROM Port Out, Chip7 - Chip0, each 4bits
    input  wire [31:0] PORT_OUT_ROM_CHIPF_CHIP8, // ROM Port Out, ChipF - Chip8, each 4bits
    input  wire [31:0] PORT_OUT_RAM_BANK1_BANK0, // RAM Port Out, Bank1 - Bank0, Chip3 - Chip0, each 4bits
    input  wire [31:0] PORT_OUT_RAM_BANK3_BANK2, // RAM Port Out, Bank3 - Bank2, Chip3 - Chip0, each 4bits
    input  wire [31:0] PORT_OUT_RAM_BANK5_BANK4, // RAM Port Out, Bank5 - Bank4, Chip3 - Chip0, each 4bits
    input  wire [31:0] PORT_OUT_RAM_BANK7_BANK6, // RAM Port Out, Bank7 - Bank6, Chip3 - Chip0, each 4bits
    //
    // port_keyprt_cmd...
    //     bit15   : Printer FIFO POP Request
    //     bit14   : Paper Feed Request
    //     bit13-12: Rounding Switch
    //     bit11-08: Decimal Point Switch
    //     bit07-00: Key Code
    input  wire [31:0] PORT_KEYPRT_CMD,
    //
    // port_keyprt_res...
    //     bit31   : Printer FIFO Data Ready
    //     bit30-16: Printer Column_01_15
    //     bit15-14: Printer Column_17_18
    //     bit13-10: Printer Drum Count
    //     bit09   : Printer Red Ribbon
    //     bit08   : Printer Paper Feed
    //     bit07   : Minus Sign Lamp
    //     bit06   : Overflow Lamp
    //     bit05   : Memory Lamp
    //     bit04-01: unused
    //     bit00   : Printer FIFO_POP Acknowledge
    output wire [31:0] PORT_KEYPRT_RES 
);

integer i;

//-------------------------
// Shift Registers : i4003
//-------------------------
wire sck_key;
wire sck_prt;
wire sdi_common;
wire sft_cascade;
wire [ 9:0] key_column;
wire [16:0] prt_column;
wire [ 9:0] prt_q0, prt_q1;
wire prt_hammer;
//
MCS4_SHIFTER SHIFTER_KEY
(
    .CLK   (CLK),
    .RES_N (RES_N),
    .SCK   (sck_key),
    .SDI   (sdi_common),
    .SDO   (),
    .OE    (1'b1),
    .Q     (key_column)
);
//
MCS4_SHIFTER SHIFTER_PRT0
(
    .CLK   (CLK),
    .RES_N (RES_N),
    .SCK   (sck_prt),
    .SDI   (sdi_common),
    .SDO   (sft_cascade),
    .OE    (prt_hammer),
    .Q     (prt_q0)
);
//
MCS4_SHIFTER SHIFTER_PRT1
(
    .CLK   (CLK),
    .RES_N (RES_N),
    .SCK   (sck_prt),
    .SDI   (sft_cascade),
    .SDO   (),
    .OE    (prt_hammer),
    .Q     (prt_q1)
);
//
assign sck_key    = PORT_OUT_ROM_CHIP7_CHIP0[0] & ENABLE;
assign sck_prt    = PORT_OUT_ROM_CHIP7_CHIP0[2] & ENABLE;
assign sdi_common = PORT_OUT_ROM_CHIP7_CHIP0[1] & ENABLE;
//
assign prt_column = {prt_q0[3],prt_q0[4],prt_q0[5],prt_q0[6],prt_q0[7],prt_q0[8],prt_q0[9],
                     prt_q1[0],prt_q1[1],prt_q1[2],prt_q1[3],prt_q1[4],prt_q1[5],prt_q1[6],prt_q1[7],
                     prt_q0[0],prt_q0[1]};

//-------------------
// Key Board Matrix
//-------------------
wire [3:0] key_row;
//
assign key_row[0] =  ( ~key_column[0] & (PORT_KEYPRT_CMD[7:0] == 8'h81) // CM
                     | ~key_column[1] & (PORT_KEYPRT_CMD[7:0] == 8'h85) // SQRT
                     | ~key_column[2] & (PORT_KEYPRT_CMD[7:0] == 8'h89) // DIAMOND
                     | ~key_column[3] & (PORT_KEYPRT_CMD[7:0] == 8'h8d) // -
                     | ~key_column[4] & (PORT_KEYPRT_CMD[7:0] == 8'h91) // 9
                     | ~key_column[5] & (PORT_KEYPRT_CMD[7:0] == 8'h95) // 8
                     | ~key_column[6] & (PORT_KEYPRT_CMD[7:0] == 8'h99) // 7
                     | ~key_column[7] & (PORT_KEYPRT_CMD[7:0] == 8'h9d) // SIGN
                     | ~key_column[8] & (PORT_KEYPRT_CMD[ 8])           // DP0
                     | ~key_column[9] & (PORT_KEYPRT_CMD[12])           // ROUND0
                     );
assign key_row[1] =  ( ~key_column[0] & (PORT_KEYPRT_CMD[7:0] == 8'h82) // RM
                     | ~key_column[1] & (PORT_KEYPRT_CMD[7:0] == 8'h86) // %
                     | ~key_column[2] & (PORT_KEYPRT_CMD[7:0] == 8'h8a) // /
                     | ~key_column[3] & (PORT_KEYPRT_CMD[7:0] == 8'h8e) // +
                     | ~key_column[4] & (PORT_KEYPRT_CMD[7:0] == 8'h92) // 6
                     | ~key_column[5] & (PORT_KEYPRT_CMD[7:0] == 8'h96) // 5
                     | ~key_column[6] & (PORT_KEYPRT_CMD[7:0] == 8'h9a) // 4
                     | ~key_column[7] & (PORT_KEYPRT_CMD[7:0] == 8'h9e) // EX
                     | ~key_column[8] & (PORT_KEYPRT_CMD[ 9])           // DP1
                     );
assign key_row[2] =  ( ~key_column[0] & (PORT_KEYPRT_CMD[7:0] == 8'h83) // M-
                     | ~key_column[1] & (PORT_KEYPRT_CMD[7:0] == 8'h87) // M=-
                     | ~key_column[2] & (PORT_KEYPRT_CMD[7:0] == 8'h8b) // *
                     | ~key_column[3] & (PORT_KEYPRT_CMD[7:0] == 8'h8f) // DIAMOND2
                     | ~key_column[4] & (PORT_KEYPRT_CMD[7:0] == 8'h93) // 3
                     | ~key_column[5] & (PORT_KEYPRT_CMD[7:0] == 8'h97) // 2
                     | ~key_column[6] & (PORT_KEYPRT_CMD[7:0] == 8'h9b) // 1
                     | ~key_column[7] & (PORT_KEYPRT_CMD[7:0] == 8'h9f) // CE
                     | ~key_column[8] & (PORT_KEYPRT_CMD[10])           // DP2
                     );
assign key_row[3] =  ( ~key_column[0] & (PORT_KEYPRT_CMD[7:0] == 8'h84) // M+
                     | ~key_column[1] & (PORT_KEYPRT_CMD[7:0] == 8'h88) // M=+
                     | ~key_column[2] & (PORT_KEYPRT_CMD[7:0] == 8'h8c) // =
                     | ~key_column[3] & (PORT_KEYPRT_CMD[7:0] == 8'h90) // 000
                     | ~key_column[4] & (PORT_KEYPRT_CMD[7:0] == 8'h94) // .
                     | ~key_column[5] & (PORT_KEYPRT_CMD[7:0] == 8'h98) // 00
                     | ~key_column[6] & (PORT_KEYPRT_CMD[7:0] == 8'h9c) // 0
                     | ~key_column[7] & (PORT_KEYPRT_CMD[7:0] == 8'ha0) // C
                     | ~key_column[8] & (PORT_KEYPRT_CMD[11])           // DP3
                     | ~key_column[9] & (PORT_KEYPRT_CMD[13])           // ROUND1
                     );

//------------------------------------------------
// Printer Basic Timing
//------------------------------------------------
reg  [15:0] prt_clkcnt; 
wire        prt_tick;
reg  [ 4:0] prt_tick_count;
wire        prt_drum_row_each;
wire        prt_drum_row_first;
wire        prt_drum_row_last;
wire [ 3:0] prt_drum_count;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        prt_clkcnt <= 16'h0000;
    else if (~ENABLE)
        prt_clkcnt <= 16'h0000;
    else if (prt_tick)
        prt_clkcnt <= 16'h0000;
    else
        prt_clkcnt <= prt_clkcnt + 16'h0001;
end
// Printer Tick : 16'h3000=12288, 750KHz/12288=61Hz(16.4ms)
assign prt_tick = (prt_clkcnt == 16'h2fff);
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        prt_tick_count <= 5'h00;
    else if (prt_tick & prt_drum_row_last)
        prt_tick_count <= 5'h00;
    else if (prt_tick)
        prt_tick_count <= prt_tick_count + 5'h01;
end
//
assign prt_drum_row_each  = ~prt_tick_count[0];
assign prt_drum_row_first = (prt_tick_count == 5'h00);
assign prt_drum_row_last  = (prt_tick_count == 5'h19); // 13*2=26=6'h1a
assign prt_drum_count     = prt_tick_count[4:1];

//--------------------
// Printer Control
//--------------------
wire       prt_color;
wire       prt_paper_feed;
reg        prt_color_delay;
reg        prt_hammer_delay;
reg        prt_paper_feed_delay;
wire       prt_paper_feed_req; // no need to sync (firmware handles)
wire       prt_fifo_pop;
reg  [2:0] prt_fifo_pop_sync;
//
assign prt_color          = PORT_OUT_RAM_BANK1_BANK0[0] & ENABLE; // RAM0 bit0
assign prt_hammer         = PORT_OUT_RAM_BANK1_BANK0[1] & ENABLE; // RAM0 bit1
assign prt_paper_feed     = PORT_OUT_RAM_BANK1_BANK0[3] & ENABLE; // RAM0 bit3
assign prt_paper_feed_req = PORT_KEYPRT_CMD[14];
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
    begin
        prt_color_delay      <= 1'b0;
        prt_hammer_delay     <= 1'b0;
        prt_paper_feed_delay <= 1'b0;
    end
    else
    begin
        prt_color_delay      <= prt_color;
        prt_hammer_delay     <= prt_hammer;
        prt_paper_feed_delay <= prt_paper_feed;
    end
end
//
// Synchronization of FIFO POP Signal
assign prt_fifo_pop = PORT_KEYPRT_CMD[15];
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
    begin
        prt_fifo_pop_sync[0] <= 1'b0;
        prt_fifo_pop_sync[1] <= 1'b0;
        prt_fifo_pop_sync[2] <= 1'b0;
    end
    else
    begin
        prt_fifo_pop_sync[0] <= prt_fifo_pop;
        prt_fifo_pop_sync[1] <= prt_fifo_pop_sync[0];
        prt_fifo_pop_sync[2] <= prt_fifo_pop_sync[1];
    end
end
//
// Printer FIFO Control
reg  [22:0] prt_fifo[0:255]; // fifo body
wire [22:0] prt_fifo_wdata;  // fifo write data
reg  [22:0] prt_fifo_rdata;  // fifo read data
wire        prt_fifo_we; // fifo write strobe
wire        prt_fifo_re; // fifo read strobe
reg  [ 7:0] prt_fifo_wp; // fifo write pointer
reg  [ 7:0] prt_fifo_rp; // fifo read pointer
reg  [ 8:0] prt_fifo_dc; // fifo data count (0~32)
wire        prt_fifo_full;  // fifo data full
wire        prt_fifo_empty; // fifo data empty
//
assign prt_fifo_we = (prt_color      & ~prt_color_delay      & ~prt_fifo_full)
                   | (prt_hammer     & ~prt_hammer_delay     & ~prt_fifo_full)
                   | (prt_paper_feed & ~prt_paper_feed_delay & ~prt_fifo_full);
assign prt_fifo_re = prt_fifo_pop_sync[1] & ~prt_fifo_pop_sync[2] & ~prt_fifo_empty;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        prt_fifo_wp <= 8'h00;
    else if (prt_fifo_we)
        prt_fifo_wp <= prt_fifo_wp + 8'h01;
end
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        prt_fifo_rp <= 8'h00;
    else if (prt_fifo_re)
        prt_fifo_rp <= prt_fifo_rp + 8'h01;
end
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        prt_fifo_dc <= 9'h000;
    else if (prt_fifo_we & prt_fifo_re)
        prt_fifo_dc <= prt_fifo_dc;
    else if (prt_fifo_we)
        prt_fifo_dc <= prt_fifo_dc + 9'h001;
    else if (prt_fifo_re)
        prt_fifo_dc <= prt_fifo_dc - 9'h001;
end
//
assign prt_fifo_full  = (prt_fifo_dc == 9'd256);
assign prt_fifo_empty = (prt_fifo_dc == 9'd000);
//
assign prt_fifo_wdata = (prt_color     )? 23'h02
                      : (prt_paper_feed)? 23'h01
                      : {prt_column, prt_drum_count, 2'b00};
//
always @(posedge CLK, negedge RES_N)
begin
    //prt_fifo_rdata <= prt_fifo[prt_fifo_rp];
    if (~RES_N)
        prt_fifo_rdata <= 23'h000000;
    else if (prt_fifo_re)
        prt_fifo_rdata <= prt_fifo[prt_fifo_rp];
end
//
always @(posedge CLK)
begin
    if (prt_fifo_we) prt_fifo[prt_fifo_wp] <= prt_fifo_wdata;
end

//----------------
// Status Lamp
//----------------
wire lamp_minus;
wire lamp_overflow;
wire lamp_memory;
assign lamp_minus    = PORT_OUT_RAM_BANK1_BANK0[6] & ENABLE; // Bank0 RAM1 bit2
assign lamp_overflow = PORT_OUT_RAM_BANK1_BANK0[5] & ENABLE; // Bank0 RAM1 bit1
assign lamp_memory   = PORT_OUT_RAM_BANK1_BANK0[4] & ENABLE; // Bank0 RAM1 bit0

//----------------------
// Generate Response
//----------------------
assign PORT_KEYPRT_RES =
{
    ~prt_fifo_empty,     // 1bit
    prt_fifo_rdata,      // 23bit
    lamp_minus,          // 1bit
    lamp_overflow,       // 1bit
    lamp_memory,         // 1bit
    4'b0000,             // 4bit
    prt_fifo_pop_sync[2] // 1bit
};

//-----------------------------------------------------
// Generate Port Input Signal of MCS-4 System
//-----------------------------------------------------
assign TEST = prt_drum_row_each & ENABLE;
assign PORT_IN_ROM_CHIP7_CHIP0 = (ENABLE)?
{
    4'b0000, // ROM7
    4'b0000, // ROM6
    4'b0000, // ROM5
    4'b0000, // ROM4
    4'b0000, // ROM3
    prt_paper_feed_req, 2'b00, prt_drum_row_first, // ROM2
    key_row, // ROM1
    4'b0000  // ROM0
} : 32'h00000000;
assign PORT_IN_ROM_CHIPF_CHIP8 = 0;

//===========================================================
endmodule
//===========================================================
