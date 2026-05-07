# UART — Parameterized SystemVerilog Implementation

A fully parameterized, FSM-based Universal Asynchronous Receiver/Transmitter (UART) core implemented in SystemVerilog, targeting Xilinx FPGAs via AMD Vivado. The design covers the complete serial communication pipeline: baud rate generation, bit serialization (TX), mid-bit sampled reception (RX), and top-level loopback integration, each verified with a dedicated testbench.

---

## Architecture

```
         ┌────────────────────────────────────────────────────────────┐
         │                        top.sv                              │
         │                                                            │
         │  ┌───────────┐    tick_baud    ┌──────────┐                │
         │  │           │───────────────►│          │  tx             │
 data_in │  │  baud_gen │                │  uart_tx │─────────┐       │
────────►│  │           │───────────────►│          │         │       │
 start   │  │ CLK_FREQ  │    tick_rx     └──────────┘         │       │
────────►│  │ BAUD_RATE │                                     │ wire  │
         │  └───────────┘    tick_baud   ┌──────────┐         │       │
         │         │────────────────────►│          │◄────────┘       │
         │         │────────────────────►│  uart_rx │  rx             │
         │                  tick_rx      │          │                 │
         │                              └──────────┘                  │
         │                                   │  data_out, data_valid  │
         └───────────────────────────────────┼────────────────────────┘
                                             ▼
```

The `top` module wires the TX output directly to the RX input, forming a loopback path. A single `baud_gen` instance provides both a full-period tick (`tick_baud`) and a half-period tick (`tick_rx`) to all submodules.

---

## Module Overview

### `baud_gen` — Baud Rate Generator

Generates two timing strobes from a free-running counter:

| Signal | Fires at | Purpose |
|---|---|---|
| `tick_baud` | `count == DIV - 1` (end of period) | TX state transitions, RX stop-bit timeout |
| `tick_rx` | `count == (DIV-1)/2` (mid-period) | Mid-bit sampling in RX data path |

```
Parameters: CLK_FREQ (default 100 MHz), BAUD_RATE (default 115200)
DIV = CLK_FREQ / BAUD_RATE = 868 clock cycles per baud period
```

The counter width is computed at elaboration via `$clog2(DIV)` so the register is never oversized.

---

### `uart_tx` — Transmitter

A 4-state Mealy FSM that serializes parallel data onto a single TX line, LSB-first, with start and stop framing.

```
 IDLE ──(start)──► START ──(tick_baud)──► DATA ──(last bit & tick_baud)──► STOP
   ▲                                                                          │
   └──────────────────────────────(tick_baud)────────────────────────────────┘
```

| State | TX line | Action |
|---|---|---|
| IDLE | 1 | Loads shift register when `start` asserted |
| START | 0 | Holds start bit for one baud period |
| DATA | `shift_reg[0]` | Shifts right on each `tick_baud`; counts bits with `bit_count` |
| STOP | 1 | Holds stop bit for one baud period |

The internal shift register captures `data_in` on the IDLE→START transition and shifts right on every `tick_baud` in the DATA state, ensuring LSB-first transmission with no extra latency.

---

### `uart_rx` — Receiver

A 4-state FSM that deserializes an incoming bit stream using `tick_rx` (mid-bit) for sampling and `tick_baud` (end-of-period) for stop-bit timing.

```
 IDLE ──(rx=0)──► START ──(tick_rx)──► DATA ──(last bit & tick_rx)──► STOP
   ▲                                                                       │
   └──────────────────────────────(tick_baud)────────────────────────────┘
```

| State | Sampling signal | Action |
|---|---|---|
| IDLE | — | Detects falling edge of `rx` |
| START | `tick_rx` | Waits for mid-point of start bit before proceeding |
| DATA | `tick_rx` | Samples `rx` into `rx_reg[bit_count]` at mid-bit |
| STOP | `tick_baud` | Waits one baud period; asserts `data_valid` |

**Mid-bit sampling:** Using `tick_rx` (fired at `(DIV-1)/2`) rather than `tick_baud` ensures the RX samples each bit at the center of its eye, maximizing noise margin.

**Output assembly:** `data_out` is assembled at the final data tick as `{rx, rx_reg[count-2:0]}` — the MSB is taken directly from the `rx` line rather than from `rx_reg` to avoid a one-cycle pipeline bubble on the last bit.

`data_valid` is asserted for exactly one clock cycle after all bits are received.

---

### `top` — Loopback Integration

Instantiates one `baud_gen`, one `uart_tx`, and one `uart_rx`, wiring `tx` directly to `rx`. Exposes a clean interface for higher-level integration or constraint-based FPGA synthesis.

```systemverilog
module top #(parameter int count = 8) (
    input  logic             clk, rst, start,
    input  logic [count-1:0] data_in,
    output logic [count-1:0] data_out,
    output logic             data_valid
);
```

---

## Default Parameters

| Parameter | Value | Notes |
|---|---|---|
| `CLK_FREQ` | 100,000,000 Hz | 100 MHz system clock |
| `BAUD_RATE` | 115,200 baud | Standard high-speed UART rate |
| `count` | 8 bits | Configurable data frame width |
| `DIV` | 868 cycles | Derived: CLK_FREQ / BAUD_RATE |

All parameters are elaboration-time constants. Changing `CLK_FREQ` or `BAUD_RATE` automatically resizes the counter and recomputes timing — no manual adjustments required.

---

## Verification

Each module has a dedicated SystemVerilog testbench simulated with AMD Vivado XSim.

| Testbench | DUT | Verification strategy |
|---|---|---|
| `baud_gen_TB.sv` | `baud_gen` | Measures cycle count between `tick_baud` pulses; `$fatal` on any deviation from `DIV` |
| `uart_tx_tb.sv` | `uart_tx` | Serializes `0xA5`, captures 10 frames (start + 8 data + stop) on `tick_baud`, verifies each bit |
| `uart_rx_tb.sv` | `uart_rx` | Drives a manually serialized `0xA5` frame; asserts `data_out == 0xA5` on `data_valid` |
| `top_tb.sv` | `top` | End-to-end loopback: writes `0xA5` to TX, waits for `data_valid`, checks `data_out == 0xA5` |

---

## File Structure

```
UART/
├── UART.srcs/
│   ├── sources_1/new/
│   │   ├── baud_gen.sv          # Baud rate generator (tick_baud + tick_rx)
│   │   ├── uart_tx.sv           # UART transmitter FSM
│   │   ├── uart_rx.sv           # UART receiver FSM with mid-bit sampling
│   │   └── top.sv               # Top-level loopback integration
│   └── sim_1/new/
│       ├── baud_gen_TB.sv       # Baud period accuracy check
│       ├── uart_tx_tb.sv        # TX bit-by-bit verification
│       ├── uart_rx_tb.sv        # RX frame recovery verification
│       └── top_tb.sv            # End-to-end loopback test
└── README.md
```

---

## Tools

- **Language:** SystemVerilog (IEEE 1800-2017)
- **Simulator:** AMD Vivado XSim (behavioral simulation)
- **Target:** Xilinx 7-series / UltraScale FPGAs
- **IDE:** AMD Vivado Design Suite
