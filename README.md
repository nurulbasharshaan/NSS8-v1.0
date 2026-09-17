# 1 MB 8-Bit Heterogeneous SoC with DMA and Dynamic Frequency Scaling for Low-Power IoT

### Phase 1 Architectural Research Preview

DOI: 10.13140/RG.2.2.12219.58404  
Link: https://doi.org/10.13140/RG.2.2.12219.58404

**Authors:** Nurul Bashar, Samiul Hossain, Shafin Ibnul Mohasin
**Affiliation:** ASIC Physical Design Department, PrimeSilicon Technology (BD) Ltd., Dhaka, Bangladesh
**Copyright:** © 2026 Nurul Bashar. All Rights Reserved.

---

## Overview

This repository contains the RTL implementation of a custom 8-bit System-on-Chip
(SoC) designed for ultra-low-power IoT edge nodes. Unlike traditional 8-bit
microcontrollers restricted to a 64 KB address space and CPU-controlled data
transfers, this architecture features:

- **20-bit flat physical addressing**, providing a theoretical 1 MB address space
  without bank switching.
- **Lightweight DMA**, supporting 20-bit source/destination addresses and up to
  65,535 bytes per transaction.
- **Software-defined Dynamic Frequency Scaling (DFS)** through a memory-mapped
  clock-divider register.
- **Fixed-priority heterogeneous bus arbitration** between CPU and DMA.
- **Compact single-core 8-bit CPU** with a 20-bit program counter/address path.
- **UART, SPI, Timer/PWM, GPIO, and interrupt-control peripherals.**

> **Release Status:** This is a **Phase 1 Research Preview** intended to
> establish architectural priority and enable academic review of the core
> microarchitecture. It is **not** claimed to be a fully verified or
> silicon-ready Golden Release. See
> [Phase 1 Status & Known Limitations](#phase-1-status--known-limitations)
> and `PHASE1_RELEASE.md`.

---

## Key Architectural Features

### Extended 1 MB Memory Horizon

The 20-bit physical address bus provides:

2^20 = 1,048,576 bytes = 1 MB

The current RTL implements 64 KB ROM (`0x00000–0x0FFFF`) and 128 KB RAM
(`0x10000–0x1FFFF`). The remainder of the 20-bit address space is reserved for
memory-mapped peripherals and future memory expansion.

### Lightweight DMA Engine

- 20-bit source address, 20-bit destination address, 16-bit transfer length
  (up to 65,535 bytes per transaction)
- Software start control; hardware trigger pin reserved (tied low in Phase 1)
- Memory-to-memory operation
- Completion interrupt (`dma_irq`)
- Reference state machine: `IDLE → READ → WRITE → DONE`
- Dual bus role: **slave** during configuration (`0x90000–0x90009`),
  **master** during transfer (bus Master 1)

### Dynamic Frequency Scaling (DFS)

Firmware writes the clock-divider register `D` at `0x80003`. The clock manager
toggles `sys_clk` every `(D+1)` board-clock cycles; a full period requires two
toggles, therefore:

```
f_sys = f_in / (2 * (D + 1))
```

Operating points with `f_in = 250 MHz`:

| D   | f_sys      | Note                                                          |
| --- | ---------- | ------------------------------------------------------------- |
| 0   | 125 MHz    | Maximum configured frequency (`f_in / 2`)                     |
| 4   | 25 MHz     | UART-correct operating point (~115.2 kbaud)                   |
| 5   | ≈20.83 MHz | Clock-manager reset shadow (momentary; see limitations)       |
| 7   | 15.625 MHz | 8× reduction vs. D=0 (87.5% first-order dynamic-power saving) |
| 255 | ≈488 kHz   | Slowest operating point                                       |

### Heterogeneous Bus Architecture

The unified 20-bit memory bus uses a strict fixed-priority, combinational
arbiter:

- **Master 0 — CPU:** highest priority (deterministic ISR latency)
- **Master 1 — DMA:** cycle-steals only when the CPU asserts no strobes

The policy favors predictable CPU responsiveness over maximum DMA throughput.

### 8-Bit CPU Core (`cpu_8bit_v3`)

- 8-bit data path, 20-bit address path / program counter
- **Execution model: multi-cycle, non-pipelined state machine** with four
  conceptual states (FETCH, DECODE, EXECUTE, INTERRUPT); 3 bus-granted cycles
  per instruction
- Registers: A, X, Y (8-bit), PC (20-bit), SP (8-bit, resets to `0xFF`),
  status flags Z / N / C / I
- Fixed interrupt vector at `0xFFF00` with automatic I-flag masking
- Reference ISA: `NOP, LDA, ADD, JMP (page), LDX, LDY, CLI, SEI`

### Peripheral Subsystem

- **UART TX/RX:** 8N1, 2-stage RX input synchronizer, `BAUD_DIV = 217`
  (bit period = 218 `sys_clk` cycles) → ≈115.2 kbaud at `f_sys = 25 MHz`
- **SPI Master:** configurable CPOL/CPHA control, programmable divider
  `f_SPI = f_sys / (2 * (div + 1))`, 8-bit full-duplex shift register,
  busy/rx-valid status, completion interrupt
- **Timer/PWM:** 16-bit counter, 16-bit prescaler, 16-bit compare (PWM duty),
  overflow interrupt
- **GPIO:** 8-bit memory-mapped output port

### Interrupt Controller (`interrupt_controller_v2`)

- Five sources, fixed priority: **UART RX > DMA > SPI > Timer > GPIO**
  (GPIO reserved in Phase 1)
- Control path: 1-bit `cpu_irq` wired directly to the CPU
- Data path: 4-bit `irq_source` ID readable at `0x80004` via the read mux

---

## Directory Structure

```text
8bit-heterogeneous-soc/
├── rtl/
│   ├── soc_top.v            
│   ├── cpu_8bit.v           
│   ├── bus_arbiter.v           
│   ├── dma_controller.v       
│   ├── clock_manager.v         
│   ├── interrupt_controller_v2.v
│   ├── memory.v               
│   ├── peripherals.v          
│   ├── uart_rx.v 
│   ├── spi_master.v
│   └── timer_pwm.v
├── testbench/                                        
├── LICENSE                    
├── CONTRIBUTING.md
├── CITATION.cff
├── DATASHEET.md
├── PHASE1_RELEASE.md
└── README.md
```

---

## Complete Memory Map

| Address Range     | Size   | Module        | Access | Function                        |
|:----------------- |:------ |:------------- |:------ |:------------------------------- |
| `0x00000–0x0FFFF` | 64 KB  | ROM           | R      | Program memory (`firmware.hex`) |
| `0x10000–0x1FFFF` | 128 KB | RAM           | R/W    | Data and stack memory           |
| `0x80000`         | 1 B    | UART TX       | W      | Transmit byte                   |
| `0x80001`         | 1 B    | UART RX       | R      | Receive byte                    |
| `0x80002`         | 1 B    | GPIO          | R/W    | GPIO port                       |
| `0x80003`         | 1 B    | Clock Div     | W      | DFS divider                     |
| `0x80004`         | 1 B    | IRQ Ctrl      | R/W    | IRQ source ID / clear           |
| `0x85000`         | 1 B    | SPI Control   | W      | Start, CPOL, CPHA               |
| `0x85001`         | 1 B    | SPI Clock Div | W      | SPI divider                     |
| `0x85002`         | 1 B    | SPI TX        | W      | SPI transmit byte               |
| `0x85003`         | 1 B    | SPI RX        | R      | SPI receive byte                |
| `0x85004`         | 1 B    | SPI Status    | R      | Busy / RX-valid                 |
| `0x86000`         | 1 B    | Timer Ctrl    | W      | Enable / IRQ / PWM              |
| `0x86001–0x86002` | 2 B    | Timer Pre     | W      | Prescaler                       |
| `0x86003–0x86004` | 2 B    | Timer Cnt     | R      | Counter                         |
| `0x86005–0x86006` | 2 B    | Timer Cmp     | W      | PWM compare                     |
| `0x86007`         | 1 B    | Timer Stat    | R/W    | Overflow status / clear         |
| `0x90000–0x90002` | 3 B    | DMA Src       | W      | 20-bit source address           |
| `0x90003–0x90005` | 3 B    | DMA Dst       | W      | 20-bit destination address      |
| `0x90006–0x90007` | 2 B    | DMA Len       | W      | Transfer length                 |
| `0x90008`         | 1 B    | DMA Ctrl      | W      | Start control                   |
| `0x90009`         | 1 B    | DMA Stat      | R      | Busy / done status              |

---

## Phase 1 Status & Known Limitations

This release is an architectural research preview. The following limitations are
known from the current RTL snapshot and are intended for resolution in the
Golden Release:

1. **Peripheral read-backs:** the read multiplexer in `soc_top_v3.v` currently
   returns constants rather than live registers for UART RX, GPIO, DMA, SPI,
   and Timer read-backs.
2. **UART RX sampling:** aligned to the baud-counter reset edge rather than the
   bit center.
3. **Clock divider reset:** the top-level `clk_div_reg_r` lacks a reset;
   firmware or the testbench must write `0x80003` to establish a defined
   `sys_clk` division ratio in simulation.
4. **Interrupt clearing:** `clear_irq` is not yet mapped to the `0x80004` write
   decode, so serviced interrupt flags persist; the UART RX interrupt is
   level-held and requires self-clearing or clear-path gating.
5. **GPIO interrupt:** `gpio_irq` is currently undriven and reserved for
   future use.
6. **DMA read data:** the read multiplexer currently drives only
   `cpu_rd_data`, leaving the unified-bus `mem_rd_data` undriven and causing
   DMA reads to resolve to `X` in simulation.
7. **Clock generation:** `clock_manager.v` uses a logic-based toggle for
   `sys_clk`, intended for functional simulation only; an ASIC tape-out must
   use a foundry-supported PLL/divider with a CTS-compatible clock network.

**Verification status:** this repository must not be represented as fully
verified, timing-closed, or silicon-ready until those activities are completed.

---

## Documentation

- `DATASHEET.md` — full hardware specification and feature reference
- `PHASE1_RELEASE.md` — release scope and claims
- `CONTRIBUTING.md` — contribution terms (includes commercial-rights grant)
- `LICENSE` — Academic, Research, and Hobbyist Non-Commercial License v1.0

---

## Citation

If you use this architecture, RTL, or its concepts in academic research, please
cite:

```bibtex
@misc{bashar2026soc,
  author       = {Bashar, Nurul and Hossain, Samiul and Mohasin, Shafin Ibnul},
  title        = {1 MB 8-Bit Heterogeneous SoC with DMA and Dynamic Frequency
                  Scaling for Low-Power IoT},
  year         = {2026},
  note         = {Phase-1 research preview; RTL and materials archived at
                  DOI 10.13140/RG.2.2.12219.58404},
  doi          = {10.13140/RG.2.2.12219.58404},
  url          = {https://github.com/nurulbasharshaan/NSS8-v1.0/tree/Release_1}
}
```

---

## License

This repository is released under the
**Academic, Research, and Hobbyist Non-Commercial License, Version 1.0**
(© 2026 Nurul Bashar, all copyright reserved).

- Free for personal learning, academic research, coursework, and hobbyist use
- Commercial use, commercial products, paid engineering services, and
  commercial distribution require a separate written license aggrements

See [`LICENSE`](LICENSE) for the complete terms.

### Commercial Licensing

For commercial licensing, ASIC integration, or commercial product development:
**nurulboshor1920@gmail.com**
