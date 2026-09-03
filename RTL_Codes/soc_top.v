module soc_top_v3 #(parameter CLK_IN_FREQ = 250000000) (
    input  wire       clk_in,
    input  wire       rst_n,
    input  wire       uart_rx_pin,
    input  wire       spi_miso,
    output wire [7:0] gpio_pins,
    output wire       uart_tx_pin,
    output wire       pwm_out
);
    wire sys_clk;
    wire [7:0] clk_div_reg;
    
    // CPU Bus
    wire [19:0] cpu_addr;
    wire [7:0]  cpu_wr_data, cpu_rd_data;
    wire        cpu_wr_en, cpu_rd_en;
    wire        cpu_irq, irq_ack, cpu_grant;
    
    // DMA Bus
    wire [19:0] dma_addr;
    wire [7:0]  dma_wr_data, dma_rd_data;
    wire        dma_wr_en, dma_rd_en, dma_grant;
    
    // Unified Memory Bus (after arbitration)
    wire [19:0] mem_addr;
    wire [7:0]  mem_wr_data, mem_rd_data;
    wire        mem_wr_en, mem_rd_en;
    
    // IRQ lines
    wire uart_rx_irq, timer_irq, gpio_irq, dma_irq, spi_irq;
    wire [3:0] irq_source;

    // === 1. Clock Manager ===
    clock_manager u_clk (
        .clk_in(clk_in), .rst_n(rst_n),
        .clk_div_reg(clk_div_reg), .sys_clk(sys_clk)
    );

    // === 2. Bus Arbiter ===
    bus_arbiter u_arbiter (
        .clk(sys_clk), .rst_n(rst_n),
        .cpu_addr(cpu_addr), .cpu_wr_data(cpu_wr_data), .cpu_rd_data(cpu_rd_data),
        .cpu_wr_en(cpu_wr_en), .cpu_rd_en(cpu_rd_en), .cpu_grant(cpu_grant),
        .dma_addr(dma_addr), .dma_wr_data(dma_wr_data), .dma_rd_data(dma_rd_data),
        .dma_wr_en(dma_wr_en), .dma_rd_en(dma_rd_en), .dma_grant(dma_grant),
        .mem_addr(mem_addr), .mem_wr_data(mem_wr_data), .mem_rd_data(mem_rd_data),
        .mem_wr_en(mem_wr_en), .mem_rd_en(mem_rd_en)
    );

    // === 3. CPU Core ===
    cpu_8bit_v3 u_cpu (
        .clk(sys_clk), .rst_n(rst_n), .irq(cpu_irq), .bus_grant(cpu_grant),
        .addr_bus(cpu_addr), .wr_data(cpu_wr_data),
        .rd_data(cpu_rd_data), .wr_en(cpu_wr_en), .rd_en(cpu_rd_en),
        .irq_ack(irq_ack)
    );

    // === 4. Interrupt Controller ===
    interrupt_controller_v2 u_irq_ctrl (
        .clk(sys_clk), .rst_n(rst_n),
        .uart_rx_irq(uart_rx_irq), .timer_irq(timer_irq), .gpio_irq(gpio_irq),
        .dma_irq(dma_irq), .spi_irq(spi_irq),
        .cpu_irq(cpu_irq), .irq_source(irq_source)
    );

    // === 5. Memory (128KB RAM, 64KB ROM) ===
    wire [7:0] ram_rd, rom_rd;
    wire ram_wr, ram_rd_en, rom_rd_en;

    ram_128kb u_ram (
        .clk(sys_clk), .wr_en(ram_wr), .rd_en(ram_rd_en),
        .addr(mem_addr[16:0]), .wr_data(mem_wr_data), .rd_data(ram_rd)
    );
    
    rom_64kb u_rom (
        .rd_en(rom_rd_en), .addr(mem_addr[15:0]), .rd_data(rom_rd)
    );

    // === 6. Peripherals ===
    uart_tx u_uart_tx (
        .clk(sys_clk), .rst_n(rst_n),
        .tx_data(cpu_wr_data), .tx_wr_en(cpu_wr_en && mem_addr == 20'h80000),
        .tx_pin(uart_tx_pin)
    );
    
    uart_rx u_uart_rx (
        .clk(sys_clk), .rst_n(rst_n),
        .rx_pin(uart_rx_pin), .irq(uart_rx_irq)
    );
    
    gpio_8bit u_gpio (
        .clk(sys_clk), .rst_n(rst_n),
        .wr_data(cpu_wr_data), .wr_en(cpu_wr_en && mem_addr == 20'h80002),
        .pins(gpio_pins)
    );
    
    dma_controller u_dma (
        .clk(sys_clk), .rst_n(rst_n),
        .cfg_addr(mem_addr), .cfg_wr_data(mem_wr_data), .cfg_rd_data(),
        .cfg_wr_en(mem_wr_en && (mem_addr >= 20'h90000 && mem_addr < 20'h9000A)),
        .cfg_rd_en(mem_rd_en && (mem_addr >= 20'h90000 && mem_addr < 20'h9000A)),
        .dma_addr(dma_addr), .dma_wr_data(dma_wr_data), .dma_rd_data(dma_rd_data),
        .dma_wr_en(dma_wr_en), .dma_rd_en(dma_rd_en),
        .trigger(1'b0), .irq(dma_irq), .busy()
    );
    
    spi_master u_spi (
        .clk(sys_clk), .rst_n(rst_n),
        .cfg_addr(mem_addr), .cfg_wr_data(mem_wr_data), .cfg_rd_data(),
        .cfg_wr_en(mem_wr_en && (mem_addr >= 20'h85000 && mem_addr < 20'h85005)),
        .cfg_rd_en(mem_rd_en && (mem_addr >= 20'h85000 && mem_addr < 20'h85005)),
        .spi_clk_pin(spi_clk_pin), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n), .irq(spi_irq), .busy()
    );
    
    timer_pwm u_timer (
        .clk(sys_clk), .rst_n(rst_n),
        .cfg_addr(mem_addr), .cfg_wr_data(mem_wr_data), .cfg_rd_data(),
        .cfg_wr_en(mem_wr_en && (mem_addr >= 20'h86000 && mem_addr < 20'h86008)),
        .cfg_rd_en(mem_rd_en && (mem_addr >= 20'h86000 && mem_addr < 20'h86008)),
        .pwm_out(pwm_out), .irq(timer_irq)
    );

    // === 7. Memory Map Decoder ===
    assign rom_rd_en = mem_rd_en && (mem_addr < 20'h10000);
    assign ram_rd_en = mem_rd_en && (mem_addr >= 20'h10000 && mem_addr < 20'h20000);
    assign ram_wr    = mem_wr_en && (mem_addr >= 20'h10000 && mem_addr < 20'h20000);

    wire clk_wr = mem_wr_en && (mem_addr == 20'h80003);
    reg [7:0] clk_div_reg_r;
    always @(posedge sys_clk) if (clk_wr) clk_div_reg_r <= mem_wr_data;
    assign clk_div_reg = clk_div_reg_r;

    // Read mux
    wire [7:0] uart_rx_rd = 8'h00;
    wire [7:0] irq_source_rd = {4'b0, irq_source};
    wire [7:0] gpio_rd = 8'h00;

    assign cpu_rd_data = (mem_addr < 20'h10000) ? rom_rd :
                         (mem_addr < 20'h20000) ? ram_rd :
                         (mem_addr == 20'h80001) ? uart_rx_rd :
                         (mem_addr == 20'h80002) ? gpio_rd :
                         (mem_addr == 20'h80004) ? irq_source_rd :
                         (mem_addr >= 20'h90000 && mem_addr < 20'h9000A) ? 8'h00 : // DMA read
                         (mem_addr >= 20'h85000 && mem_addr < 20'h85005) ? 8'h00 : // SPI read
                         (mem_addr >= 20'h86000 && mem_addr < 20'h86008) ? 8'h00 : // Timer read
                         8'hFF;
endmodule