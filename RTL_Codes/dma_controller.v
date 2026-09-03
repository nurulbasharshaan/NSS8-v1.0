module dma_controller (
    input  wire       clk, rst_n,
    
    // Memory-mapped control registers (from CPU)
    input  wire [19:0] cfg_addr,
    input  wire [7:0]  cfg_wr_data,
    output reg  [7:0]  cfg_rd_data,
    input  wire        cfg_wr_en,
    input  wire        cfg_rd_en,
    
    // DMA Bus (to bus arbiter)
    output reg  [19:0] dma_addr,
    output reg  [7:0]  dma_wr_data,
    input  wire [7:0]  dma_rd_data,
    output reg         dma_wr_en,
    output reg         dma_rd_en,
    
    // Trigger from peripherals
    input  wire        trigger,
    output reg         irq,         // Transfer complete interrupt
    
    output reg         busy
);
    // DMA Configuration Registers (memory-mapped)
    // 0x90000: Source address low byte
    // 0x90001: Source address mid byte
    // 0x90002: Source address high byte (4 bits)
    // 0x90003: Dest address low byte
    // 0x90004: Dest address mid byte
    // 0x90005: Dest address high byte (4 bits)
    // 0x90006: Length low byte
    // 0x90007: Length high byte
    // 0x90008: Control (bit 0 = start, bit 1 = direction 0=mem2mem, 1=periph2mem)
    // 0x90009: Status (bit 0 = busy, bit 1 = done)
    
    reg [19:0] src_addr;
    reg [19:0] dst_addr;
    reg [15:0] length;
    reg [15:0] counter;
    reg [7:0]  data_buffer;
    
    localparam IDLE = 0, READ = 1, WRITE = 2, DONE = 3;
    reg [1:0] state = IDLE;
    
    // Register write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_addr <= 0; dst_addr <= 0; length <= 0;
        end else if (cfg_wr_en) begin
            case (cfg_addr)
                20'h90000: src_addr[7:0]   <= cfg_wr_data;
                20'h90001: src_addr[15:8]  <= cfg_wr_data;
                20'h90002: src_addr[19:16] <= cfg_wr_data[3:0];
                20'h90003: dst_addr[7:0]   <= cfg_wr_data;
                20'h90004: dst_addr[15:8]  <= cfg_wr_data;
                20'h90005: dst_addr[19:16] <= cfg_wr_data[3:0];
                20'h90006: length[7:0]     <= cfg_wr_data;
                20'h90007: length[15:8]    <= cfg_wr_data;
            endcase
        end
    end
    
    // Register read logic
    always @(*) begin
        cfg_rd_data = 8'h00;
        case (cfg_addr)
            20'h90009: cfg_rd_data = {6'b0, busy, (state == DONE)};
            default:   cfg_rd_data = 8'hFF;
        endcase
    end
    
    // DMA State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            irq <= 0;
            counter <= 0;
            dma_wr_en <= 0;
            dma_rd_en <= 0;
        end else begin
            dma_wr_en <= 0;
            dma_rd_en <= 0;
            
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (trigger || (cfg_wr_en && cfg_addr == 20'h90008 && cfg_wr_data[0])) begin
                        state <= READ;
                        counter <= 0;
                        busy <= 1;
                        irq <= 0;
                    end
                end
                
                READ: begin
                    dma_addr <= src_addr + counter;
                    dma_rd_en <= 1;
                    state <= WRITE;
                end
                
                WRITE: begin
                    data_buffer <= dma_rd_data;
                    dma_addr <= dst_addr + counter;
                    dma_wr_data <= dma_rd_data;
                    dma_wr_en <= 1;
                    counter <= counter + 1;
                    
                    if (counter + 1 >= length) begin
                        state <= DONE;
                    end else begin
                        state <= READ;
                    end
                end
                
                DONE: begin
                    busy <= 0;
                    irq <= 1;  // Signal transfer complete
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
