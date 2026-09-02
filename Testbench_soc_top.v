`timescale 1ns/1ps
module tb_soc_v3;
    reg clk_in, rst_n;
    reg uart_rx_pin, spi_miso;
    wire [7:0] gpio;
    wire uart_tx, spi_clk, spi_mosi, spi_cs, pwm;

    initial begin clk_in = 0; forever #2 clk_in = ~clk_in; end 

    soc_top_v3 dut (
        .clk_in(clk_in), .rst_n(rst_n),
        .uart_rx_pin(uart_rx_pin), .spi_miso(spi_miso),
        .gpio_pins(gpio), .uart_tx_pin(uart_tx),
        .spi_clk_pin(spi_clk), .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs), .pwm_out(pwm)
    );

    initial begin
        $write("=== Phase 3 ESP32-Class SoC Test ===\n");
        
        // Load minimal firmware
        dut.u_rom.mem[16'h0000] = 8'h0A; // SEI (enable interrupts)
        dut.u_rom.mem[16'h0001] = 8'h00;
        dut.u_rom.mem[16'h0002] = 8'h01; // LDA 0x05
        dut.u_rom.mem[16'h0003] = 8'h05;
        dut.u_rom.mem[16'h0004] = 8'h04; // JMP 0x0004 (loop)
        dut.u_rom.mem[16'h0005] = 8'h04;
        
        rst_n = 0;
        uart_rx_pin = 1;
        spi_miso = 0;
        #50;
        rst_n = 1;
        
        #100000;
        $display("GPIO: %b, PWM: %b", gpio, pwm);
        $display("=== Simulation Complete ===");
        $finish;
    end
endmodule
