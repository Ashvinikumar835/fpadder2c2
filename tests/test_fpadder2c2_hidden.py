from __future__ import annotations

import cocotb
from cocotb.triggers import Timer

import os
from pathlib import Path
from cocotb_tools.runner import get_runner


# ---------------- HELPER ---------------- #

async def apply_and_check(dut, a, b, expected):
    """Apply one test vector and check output."""

    dut.fpa.value = a
    dut.fpb.value = b
    dut.i1.value = 1

    dut.ctrl.value = 1
    await Timer(100, unit="ns")

    dut.ctrl.value = 0

    # Match your Verilog timing (ctrl delayed sampling)
    await Timer(100, unit="ns")

    assert dut.fpo.value == expected, (
        f"FAIL fpa={a:016b}, fpb={b:016b} | "
        f"got={str(dut.fpo.value)}, expected={expected:016b}"
    )


# ---------------- CONSTANTS ---------------- #

x  = 0b0100100000100000  # 8.25
y  = 0b0100000110000000  # 2.75
z  = 0b0100001010000000  # 3.25

x1 = 0b1100100000100000  # -8.25
y1 = 0b1100000110000000  # -2.75
z1 = 0b1100001010000000  # -3.25


# ---------------- TEST CASES ---------------- #

# --- Positive + Positive --- #

@cocotb.test()
async def test_pos_add_xy(dut):
    await apply_and_check(dut, x, y, 0b0100100110000000)

@cocotb.test()
async def test_pos_add_yx(dut):
    await apply_and_check(dut, y, x, 0b0100100110000000)

@cocotb.test()
async def test_pos_add_zy(dut):
    await apply_and_check(dut, z, y, 0b0100011000000000)

@cocotb.test()
async def test_pos_add_yz(dut):
    await apply_and_check(dut, y, z, 0b0100011000000000)

@cocotb.test()
async def test_pos_add_yy(dut):
    await apply_and_check(dut, y, y, 0b0100010110000000)


# --- Mixed Sign --- #

@cocotb.test()
async def test_mix_x_y1(dut):
    await apply_and_check(dut, x, y1, 0b0100010110000000)

@cocotb.test()
async def test_mix_y_x1(dut):
    await apply_and_check(dut, y, x1, 0b1100010110000000)

@cocotb.test()
async def test_mix_z_y1(dut):
    await apply_and_check(dut, z, y1, 0b0011100000000000)

@cocotb.test()
async def test_mix_y_z1(dut):
    await apply_and_check(dut, y, z1, 0b1011100000000000)

@cocotb.test()
async def test_mix_x1_y(dut):
    await apply_and_check(dut, x1, y, 0b1100010110000000)

@cocotb.test()
async def test_mix_y1_x(dut):
    await apply_and_check(dut, y1, x, 0b0100010110000000)

@cocotb.test()
async def test_mix_z1_y(dut):
    await apply_and_check(dut, z1, y, 0b1011100000000000)

@cocotb.test()
async def test_mix_y1_z(dut):
    await apply_and_check(dut, y1, z, 0b0011100000000000)


# --- Negative + Negative --- #

@cocotb.test()
async def test_neg_add_x1y1(dut):
    await apply_and_check(dut, x1, y1, 0b1100100110000000)

@cocotb.test()
async def test_neg_add_y1x1(dut):
    await apply_and_check(dut, y1, x1, 0b1100100110000000)

@cocotb.test()
async def test_neg_add_z1y1(dut):
    await apply_and_check(dut, z1, y1, 0b1100011000000000)

@cocotb.test()
async def test_neg_add_y1z1(dut):
    await apply_and_check(dut, y1, z1, 0b1100011000000000)

@cocotb.test()
async def test_neg_add_y1y1(dut):
    await apply_and_check(dut, y1, y1, 0b1100010110000000)





# ---------------- PYTEST RUNNER ---------------- #

def test_logconv_runner():
    """Pytest wrapper to run cocotb tests"""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "sources/fpadder2c2.v"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="fpadder2c2",
        always=True,
    )

    runner.test(
        hdl_toplevel="fpadder2c2",
        test_module="test_fpadder2c2_hidden"
    )
