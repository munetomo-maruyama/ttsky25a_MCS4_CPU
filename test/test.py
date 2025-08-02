#//===========================================================
#// MCS-4 Project
#//-----------------------------------------------------------
#// File Name   : test.py
#// Description : Cocotb of MCS-4 System
#//-----------------------------------------------------------
#// History :
#// Rev.01 2025.05.21 M.Maruyama First Release
#//-----------------------------------------------------------
#// Copyright (C) 2025 M.Maruyama
#//===========================================================
# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 1333 ns (750 KHz)
    clock = Clock(dut.tb_clk, 1333, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset, during reset, clear RAM contents")
    dut.tb_res.value = 0
    dut.port_keyprt_cmd.value = 0x00000000
    await ClockCycles(dut.tb_clk, 10)
    dut.tb_res.value = 1
    await ClockCycles(dut.tb_clk, 100)
    dut.tb_res.value = 0

    dut._log.info("Simulation of 141-PF Calculator")
    await ClockCycles(dut.tb_clk, 50000)
    
    # Key Input
    dut.port_keyprt_cmd.value = 0x8000009b # 1
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000097 # 2
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off    
    await ClockCycles(dut.tb_clk, 50000)

    dut.port_keyprt_cmd.value = 0x8000008e # +
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)

    dut.port_keyprt_cmd.value = 0x80000093 # 3
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x8000009a # 4
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)
    
    dut.port_keyprt_cmd.value = 0x8000008e # +
   #dut.port_keyprt_cmd.value = 0x8000008d # -
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)

    dut.port_keyprt_cmd.value = 0x8000008c # =
    await ClockCycles(dut.tb_clk, 50000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 50000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80002c01 #col=...0000, row=11
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80003001 #col=...0000, row=12
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80000001 #col=...0000, row=0
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80028401 #col=...1010, row=1 (...1_+_)
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80010801 #col=...0100, row=2 (..._2__)
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80000c01 #col=...0000, row=3
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80001001 #col=...0000, row=4
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)

    dut.port_keyprt_cmd.value = 0x80008000 # FIFO POP
    await ClockCycles(dut.tb_clk, 4)
    assert dut.port_keyprt_res.value == 0x80001401 #col=...0000, row=5
    await ClockCycles(dut.tb_clk, 10000)
    dut.port_keyprt_cmd.value = 0x80000000 # off
    await ClockCycles(dut.tb_clk, 10000)
    
    await ClockCycles(dut.tb_clk, 1000000)

#//===========================================================
# End of File
#//===========================================================
