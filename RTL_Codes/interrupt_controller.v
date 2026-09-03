module interrupt_controller_v2 (
    input  wire       clk, rst_n,
    input  wire       uart_rx_irq,
    input  wire       timer_irq,
    input  wire       gpio_irq,
    input  wire       dma_irq,
    input  wire       spi_irq,
    output reg        cpu_irq,
    output reg [3:0]  irq_source
);
    // Priority: UART > DMA > SPI > Timer > GPIO
    localparam IRQ_UART  = 4'b0001;
    localparam IRQ_DMA   = 4'b0010;
    localparam IRQ_SPI   = 4'b0011;
    localparam IRQ_TIMER = 4'b0100;
    localparam IRQ_GPIO  = 4'b0101;
    
    reg uart_pending = 0;
    reg dma_pending = 0;
    reg spi_pending = 0;
    reg timer_pending = 0;
    reg gpio_pending = 0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_pending <= 0; dma_pending <= 0; spi_pending <= 0;
            timer_pending <= 0; gpio_pending <= 0;
            cpu_irq <= 0; irq_source <= 0;
        end else begin
            // Latch requests
            if (uart_rx_irq) uart_pending <= 1;
            if (dma_irq)     dma_pending <= 1;
            if (spi_irq)     spi_pending <= 1;
            if (timer_irq)   timer_pending <= 1;
            if (gpio_irq)    gpio_pending <= 1;
            
            // Priority encoder
            if (uart_pending) begin
                cpu_irq <= 1; irq_source <= IRQ_UART;
            end else if (dma_pending) begin
                cpu_irq <= 1; irq_source <= IRQ_DMA;
            end else if (spi_pending) begin
                cpu_irq <= 1; irq_source <= IRQ_SPI;
            end else if (timer_pending) begin
                cpu_irq <= 1; irq_source <= IRQ_TIMER;
            end else if (gpio_pending) begin
                cpu_irq <= 1; irq_source <= IRQ_GPIO;
            end else begin
                cpu_irq <= 0; irq_source <= 0;
            end
        end
    end
    
    // Clear IRQ (called by CPU via memory write)
    // Memory-mapped at 0x80004: write the IRQ source ID to clear it
    task clear_irq;
        input [3:0] source;
        begin
            case (source)
                IRQ_UART:  uart_pending <= 0;
                IRQ_DMA:   dma_pending <= 0;
                IRQ_SPI:   spi_pending <= 0;
                IRQ_TIMER: timer_pending <= 0;
                IRQ_GPIO:  gpio_pending <= 0;
            endcase
        end
    endtask
endmodule
