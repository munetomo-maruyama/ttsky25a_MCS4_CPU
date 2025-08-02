//===========================================================
// MCS-4 Project
//-----------------------------------------------------------
// File Name   : mcs4_shifter.v
// Description : MCS-4 10bits Shift Register (i4003)
//-----------------------------------------------------------
// History :
// Rev.01 2025.05.19 M.Maruyama First Release
//-----------------------------------------------------------
// Copyright (C) 2025 M.Maruyama
//===========================================================

//---------------------------------
// MCS-4 Shift Register Chip i4003
//---------------------------------
module MCS4_SHIFTER
(
    input  wire CLK,    // System Clock
    input  wire RES_N,  // Reset
    //
    input  wire SCK,    // Shift Clock
    input  wire SDI,    // Shift Data Input
    output wire SDO,    // Shift Data Output
    input  wire OE,     // Output Enable
    output wire [9:0] Q // Parallel Output
);

reg sck_delay;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        sck_delay <= 1'b0;
    else
        sck_delay <= SCK;
end
//
reg [9:0] sft;
//
always @(posedge CLK, negedge RES_N)
begin
    if (~RES_N)
        sft <= 10'h000;
    else if (SCK & ~sck_delay) // rising edge of sck
        sft <= {sft[8:0], SDI};
end
//
assign Q = (OE)? sft : 10'h000;
assign SDO = sft[9];

//===========================================================
endmodule
//===========================================================
