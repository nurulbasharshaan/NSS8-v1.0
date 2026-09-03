# 1 MB 8 Bit Heterogeneous SoC with DMA and Dynamic Frequency Scaling for Low-Power IoT  
**url:** "https://github.com/nurulbasharshaan/NSS8-v1.0/tree/Release_1"
**doi:** "10.5281/zenodo.22267097"

## 1. System Overview

This System-on-Chip (SoC) is a custom-designed, silicon-ready 8-bit microcontroller architecture optimized for ultra-low-power IoT edge nodes. Unlike traditional 8-bit microcontrollers limited to 64KB of memory and CPU-bound data transfers, this architecture features a **20-bit flat memory addressing scheme (1MB)**, an integrated **Lightweight DMA controller**, and **Software-Defined Dynamic Frequency Scaling (DFS)**. 

The system is built using a modular, memory-mapped Register-Transfer Level (RTL) design in synthesizable Verilog.

---

## 2. Key Features

* **Extended Memory Horizon:** 20-bit physical address bus allowing direct, flat addressing of up to 1MB of memory without bank-switching overhead.
* **Lightweight DMA Engine:** Autonomous 20-bit Direct Memory Access controller capable of transferring up to 64KB of data per transaction, bypassing the CPU to save energy and cycles.
* **Dynamic Frequency Scaling (DFS):** Runtime clock division via memory-mapped registers, allowing firmware to dynamically throttle system speed for power optimization.
* **Heterogeneous Bus Architecture:** Fixed-priority bus arbiter ensuring deterministic CPU execution while allowing background DMA transfers.
* **Rich Peripheral Subsystem:** Integrated UART, SPI Master, 16-bit Timer/PWM, and 8-bit GPIO.
* **Hardware Interrupt Controller:** 5-source priority-encoded interrupt system with automatic CPU context switching.

---

## 3. CPU Core Specifications (`cpu_8bit`)

* **Architecture:** 8-bit data path, 20-bit address path.
* **Execution Model:** Multi-cycle, non-pipelined state machine (FETCH $\rightarrow$ DECODE $\rightarrow$ EXECUTE $\rightarrow$ INTERRUPT).
* **Registers:**
  * **A, X, Y:** 8-bit general-purpose / index registers.
  * **PC:** 20-bit Program Counter.
  * **SP:** 8-bit Stack Pointer (initializes to `0xFF`).
  * **Flags:** 8-bit Status Register (Zero, Negative, Carry, Interrupt Disable).
* **Interrupt Vector:** Fixed hardware vector at `0xFFF00`.
* **Bus Interface:** Requires `bus_grant` from the arbiter to access memory, ensuring collision-free operation with the DMA.

### 3.1 Instruction Set Architecture (ISA)

A simplified, code-dense 8-bit instruction set:
| Opcode | Mnemonic | Description |
| :--- | :--- | :--- |
| `0x00` | `NOP` | No Operation |
| `0x01` | `LDA imm` | Load Accumulator A with immediate 8-bit value. Updates Z, N flags. |
| `0x03` | `ADD imm` | Add immediate 8-bit value to A. Updates Z, N, C flags. |
| `0x04` | `JMP imm8` | Jump: Replaces lower 8 bits of PC with immediate value (Page Jump). |
| `0x06` | `LDX imm` | Load Index Register X with immediate 8-bit value. |
| `0x07` | `LDY imm` | Load Index Register Y with immediate 8-bit value. |
| `0x09` | `CLI` | Clear Interrupt Disable flag (Enable Interrupts). |
| `0x0A` | `SEI` | Set Interrupt Disable flag (Disable Interrupts). |

---

## 4. Memory & Bus Architecture

### 4.1 Bus Arbiter (`bus_arbiter`)

* **Topology:** Unified 20-bit memory bus.
* **Arbitration Scheme:** Strict Fixed-Priority.
  * **Master 0 (CPU):** Highest priority. Guaranteed access for real-time interrupt handling.
  * **Master 1 (DMA):** Lowest priority. Granted access only during CPU idle cycles.
* **Data Width:** 8-bit bidirectional data bus.

### 4.2 Memory Subsystem (`memory`)

* **ROM:** 64KB (`0x00000` to `0x0FFFF`). Initialized via `$readmemh("firmware.hex")`.
* **RAM:** 128KB (`0x10000` to `0x1FFFF`). Single-cycle read/write SRAM model.

---

## 5. Peripheral Specifications

### 5.1 Lightweight DMA Controller (`dma_controller`)

* **Addressing:** 20-bit Source and Destination addresses.
* **Transfer Length:** 16-bit counter (supports up to 65,535 bytes per transaction).
* **Operation Modes:** Memory-to-Memory, Peripheral-to-Memory.
* **Triggering:** Software (via control register write) or Hardware (external trigger pin).
* **State Machine:** IDLE $\rightarrow$ READ $\rightarrow$ WRITE $\rightarrow$ DONE.
* **Completion:** Asserts `dma_irq` upon finishing the transfer.

### 5.2 Communication Interfaces

#### UART Transceiver

* **UART TX (`uart_tx`):** 8N1 format. Baud rate generator hardcoded for ~115,200 baud at a 25MHz system clock (achieved via DFS D=4 from a 250MHz board clock).
* **UART RX (`uart_rx`):** 8N1 format. Features a 2-stage synchronizer for metastability protection. Generates `uart_rx_irq` upon successful byte reception.

#### SPI Master (`spi_master`)

* **Modes:** Supports all 4 SPI modes (CPOL and CPHA configurable).
* **Clock Generation:** Programmable clock divider (`SPI_CLK = sys_clk / (2*(div+1))`).
* **Data Width:** 8-bit full-duplex shift register.
* **Status:** Hardware `busy` flag and `rx_valid` pulse. Generates `spi_irq` on transfer completion.

### 5.3 Timer & PWM (`timer_pwm`)

* **Counter:** 16-bit up-counter.
* **Prescaler:** 16-bit programmable prescaler for flexible timebase generation.
* **PWM Generation:** 16-bit compare register for variable duty-cycle PWM output.
* **Interrupts:** Configurable overflow interrupt (`timer_irq`).

### 5.4 General Purpose I/O (`gpio_8bit`)

* **Width:** 8-bit output port.
* **Control:** Direct memory-mapped write.

---

## 6. System Management

### 6.1 Interrupt Controller (`interrupt_controller`)

* **Sources:** 5 Hardware Interrupts (UART RX, DMA, SPI, Timer, GPIO).
* **Priority Encoder (Highest to Lowest):**
  1. UART RX
  2. DMA Completion
  3. SPI Completion
  4. Timer Overflow
  5. GPIO
* **Mechanism:** Latches requests, asserts `cpu_irq`, and provides a 4-bit `irq_source` ID. Cleared via memory-mapped register write.

### 6.2 Dynamic Clock Manager (`clock_manager`)

* **Function:** Divides the input board clock (`clk_in`) to generate the internal `sys_clk`.
* **Control:** Runtime adjustable via memory-mapped register.
* **Formula:** `sys_clk = clk_in / (2 * (clk_div_reg + 1))`. (If `clk_div_reg == 0`, runs at max frequency of `clk_in / 2`).

---

## 7. Complete Memory Map

| Address Range       | Size    | Peripheral / Module | Access Type | Description                           |
|:------------------- |:------- |:------------------- |:----------- |:------------------------------------- |
| `0x00000 - 0x0FFFF` | 64KB    | **ROM**             | Read        | 64KB Program Memory (Firmware)        |
| `0x10000 - 0x1FFFF` | 128KB   | **RAM**             | Read/Write  | 128KB Data / Stack Memory             |
| `0x80000`           | 1 Byte  | **UART TX**         | Write       | Transmit data byte                    |
| `0x80001`           | 1 Byte  | **UART RX**         | Read        | Receive data byte                     |
| `0x80002`           | 1 Byte  | **GPIO**            | Read/Write  | 8-bit GPIO output port                |
| `0x80003`           | 1 Byte  | **Clock Div**       | Write       | Dynamic Frequency Scaling register    |
| `0x80004`           | 1 Byte  | **IRQ Ctrl**        | Read/Write  | Read: IRQ Source ID. Write: Clear IRQ |
| `0x85000`           | 1 Byte  | **SPI Control**     | Write       | SPI Control (Start, CPOL, CPHA)       |
| `0x85001`           | 1 Byte  | **SPI Clk Div**     | Write       | SPI Clock Divider                     |
| `0x85002`           | 1 Byte  | **SPI TX**          | Write       | SPI Transmit Data                     |
| `0x85003`           | 1 Byte  | **SPI RX**          | Read        | SPI Receive Data                      |
| `0x85004`           | 1 Byte  | **SPI Status**      | Read        | SPI Status (Busy, RX Valid)           |
| `0x86000`           | 1 Byte  | **Timer Ctrl**      | Write       | Timer Control (Enable, IRQ, PWM)      |
| `0x86001 - 0x86002` | 2 Bytes | **Timer Pre**       | Write       | 16-bit Prescaler                      |
| `0x86003 - 0x86004` | 2 Bytes | **Timer Cnt**       | Read        | 16-bit Counter (Read-only)            |
| `0x86005 - 0x86006` | 2 Bytes | **Timer Cmp**       | Write       | 16-bit Compare (PWM Duty)             |
| `0x86007`           | 1 Byte  | **Timer Stat**      | Read/Write  | Overflow flag (Write 1 to clear)      |
| `0x90000 - 0x90002` | 3 Bytes | **DMA Src**         | Write       | 20-bit DMA Source Address             |
| `0x90003 - 0x90005` | 3 Bytes | **DMA Dst**         | Write       | 20-bit DMA Destination Address        |
| `0x90006 - 0x90007` | 2 Bytes | **DMA Len**         | Write       | 16-bit DMA Transfer Length            |
| `0x90008`           | 1 Byte  | **DMA Ctrl**        | Write       | DMA Control (Bit 0: Start)            |
| `0x90009`           | 1 Byte  | **DMA Stat**        | Read        | DMA Status (Bit 0: Busy, Bit 1: Done) |

---

## 8. Physical Design & Silicon Readiness

* **Target Technology:** Designed for synthesis in standard CMOS flows (e.g., SkyWater 130nm PDK via OpenLane).
* **Clocking:** Synchronous design, single global clock domain (`sys_clk`), synchronous resets (active low `rst_n`).
* **ASIC Considerations:** The logic-based clock divider is intended for FPGA/functional simulation. For ASIC tape-out, it is recommended to bypass the logic divider and use a foundry-provided Clock Tree Synthesis (CTS) friendly clock network or hardware PLL.
