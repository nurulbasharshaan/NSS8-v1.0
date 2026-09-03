module bus_arbiter (
    input  wire       clk, rst_n,
    
    // CPU Bus (Master 0 - higher priority)
    input  wire [19:0] cpu_addr,
    output reg  [7:0]  cpu_rd_data,
    input  wire        cpu_wr_en,
    input  wire        cpu_rd_en,
    output reg         cpu_grant,
    
    // DMA Bus (Master 1 - lower priority)
    input  wire [19:0] dma_addr,
    output reg  [7:0]  dma_rd_data,
    input  wire        dma_wr_en,
    input  wire        dma_rd_en,
    output reg         dma_grant,
    
    // Unified Memory Bus (output to RAM/ROM)
    output reg  [19:0] mem_addr,
    input  wire [7:0]  mem_rd_data,
    output reg         mem_wr_en,
    output reg         mem_rd_en
);
    // CPU always has priority (simple fixed-priority arbitration)
    always @(*) begin
        if (cpu_wr_en || cpu_rd_en) begin
            // CPU wins
            cpu_grant  = 1;
            dma_grant  = 0;
            mem_addr   = cpu_addr;
            mem_wr_data = cpu_wr_data;
            mem_wr_en  = cpu_wr_en;
            mem_rd_en  = cpu_rd_en;
            cpu_rd_data = mem_rd_data;
            dma_rd_data = 8'hFF;
        end else if (dma_wr_en || dma_rd_en) begin
            // DMA wins (only when CPU is idle)
            cpu_grant  = 0;
            dma_grant  = 1;
            mem_addr   = dma_addr;
            mem_wr_data = dma_wr_data;
            mem_wr_en  = dma_wr_en;
            mem_rd_en  = dma_rd_en;
            dma_rd_data = mem_rd_data;
            cpu_rd_data = 8'hFF;
        end else begin
            // Bus idle
            cpu_grant  = 1;
            dma_grant  = 0;
            mem_addr   = 0;
            mem_wr_data = 0;
            mem_wr_en  = 0;
            mem_rd_en  = 0;
            cpu_rd_data = mem_rd_data;
            dma_rd_data = 8'hFF;
        end
    end
endmodule