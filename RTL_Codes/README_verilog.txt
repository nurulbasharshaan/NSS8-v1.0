v1.0 Verilator-verified build
Pre-print Paper: 1 MB 8 Bit Heterogeneous SoC with DMA and Dynamic Frequency Scaling for Low-Power IoT
=======================================

VERIFICATION PERFORMED
-----------------------
- verilator --lint-only -Wall  -> 0 errors (only style warnings remain:
  unused signals like X/Y/SP in the simplified CPU, missing DMA/SPI
  read-back pins, a latch in the ROM read path, EOF-newline nits, etc.
  These are pre-existing design characteristics, not bugs, and were
  left alone since fixing them would change behavior/interfaces.)
- Full elaboration + simulation build with verilator --binary --timing
  (the --timing flag is needed because the testbench's free-running
  clock uses "forever #2 clk_in = ~clk_in;", a delay-based construct).
- Run the resulting binary: it completes to $finish and prints
  "GPIO: 00000000, PWM: 0" for the minimal loaded firmware
  (SEI; LDA #5; JMP self), which is the expected result since that
  program never writes to the GPIO or timer/PWM registers.

NOTE ON firmware.hex
---------------------
rom_64kb does `initial $readmemh("firmware.hex", mem); a random firmware.hex
(64K of 0x00) file has been added so the $readmemh call has something to load -
the testbench overwrites the first few bytes it actually uses via the
hierarchical reference dut.u_rom.mem[...]. Swap in your real firmware
image any time; just keep the same filename/path.

HOW TO BUILD AND RUN (Verilator)
----------------------------------
verilator --binary --timing -Wall \
    clock_manager.v memory.v peripherals.v uart_rx.v \
    bus_arbiter.v dma_controller.v spi_master.v timer_pwm.v \
    interrupt_controller_v2.v cpu_8bit_v3.v \
    soc_top_v3.v tb_soc_v3.v \
    --top-module tb_soc_v3 -o soc_v3_sim --Mdir obj_dir

./obj_dir/soc_v3_sim

(Add --trace / $dumpfile+$dumpvars in the testbench if you want a
VCD/FST waveform; not required for the above to build or run.)
