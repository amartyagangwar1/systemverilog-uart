# systemverilog-uart

A ground-up UART implementation written in SystemVerilog, starting with
a parameterized baud rate tick generator and a self-checking testbench.

  ----------
  Overview
  ----------

This repository documents the step-by-step development of a UART in
SystemVerilog. The design begins with a configurable baud rate tick
generator and will expand to include transmitter (TX), receiver (RX),
and full integration.

Primary focus: - Synthesizable RTL design - Parameterized modules -
Clean reset behavior - Structured testbenches - Deterministic timing
logic

  ----------------
  Current Status
  ----------------

Completed: - Parameterized baud rate tick generator * Configurable
CLK_FREQ * Configurable BAUD_RATE * Divider derived from parameters -
SystemVerilog testbench * 100 MHz clock generation * Reset sequencing *
Tick timing verification

In Progress: - UART Transmitter (TX) - UART Receiver (RX) - Top-level
UART integration - Expanded verification and edge-case testing

  --------------------------
  Baud Rate Tick Generator
  --------------------------

The baud generator produces a single-cycle tick_baud pulse at the
configured baud rate.

Example configuration: - CLK_FREQ = 100_000_000 (100 MHz) - BAUD_RATE =
115200 - Divider ≈ 868 clock cycles

The tick_baud signal serves as the timing reference for: - UART TX bit
transmission - UART RX sampling logic

  ------------
  Simulation
  ------------

Designed for simulation using: - Vivado Simulator - QuestaSim - Synopsys
VCS

Typical workflow: 1. Compile RTL and testbench 2. Run simulation 3.
Observe tick_baud 4. Confirm expected divider behavior

  --------------------
  Planned Milestones
  --------------------

1.  Implement UART TX finite state machine
2.  Add start, data, parity, and stop bits
3.  Implement UART RX with mid-bit sampling
4.  Add assertions and coverage
5.  Loopback simulation (TX → RX)

  --------
  Author
  --------

Amartya Gangwar Electrical & Computer Engineering University of Texas at
Austin
