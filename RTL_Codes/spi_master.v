 module spi_master (
    input  wire       clk, rst_n,
    
    // Memory-mapped control registers
    input  wire [19:0] cfg_addr,
    input  wire [7:0]  cfg_wr_data,
    output reg  [7:0]  cfg_rd_data,
    input  wire        cfg_wr_en,
    input  wire        cfg_rd_en,
    
    // SPI Physical Pins
    output reg        spi_clk_pin,
    output reg        spi_mosi,
    input  wire       spi_miso,
    output reg        spi_cs_n,
    
    output reg        irq,    // Transfer complete
    output reg        busy
);
    // Register Map:
    // 0x85000: Control (bit 0=start, bit 1=CPOL, bit 2=CPHA)
    // 0x85001: Clock divider (SPI clk = sys_clk / (2*(div+1)))
    // 0x85002: TX Data (write to send)
    // 0x85003: RX Data (read to receive)
    // 0x85004: Status (bit 0=busy, bit 1=rx_valid)
    
    reg [7:0] clk_div;
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [7:0] shift_reg;
    reg [15:0] clk_counter;
    reg [3:0] bit_counter;
    reg rx_valid;
    reg cpol, cpha;
    
    localparam IDLE = 0, TRANSFER = 1;
    reg [0:0] state;
    
    // Register write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 1;
            tx_data <= 0;
            cpol <= 0; cpha <= 0;
            spi_cs_n <= 1;
        end else if (cfg_wr_en) begin
            case (cfg_addr)
                20'h85000: begin
                    cpol <= cfg_wr_data[1];
                    cpha <= cfg_wr_data[2];
                    if (cfg_wr_data[0] && state == IDLE) begin
                        // Start transfer handled in state machine
                    end
                end
                20'h85001: clk_div <= cfg_wr_data;
                20'h85002: tx_data <= cfg_wr_data;
            endcase
        end
    end
    
    // Register read
    always @(*) begin
        cfg_rd_data = 8'hFF;
        case (cfg_addr)
            20'h85003: cfg_rd_data = rx_data;
            20'h85004: cfg_rd_data = {6'b0, busy, rx_valid};
            default:   cfg_rd_data = 8'hFF;
        endcase
    end
    
    // SPI State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            irq <= 0;
            rx_valid <= 0;
            spi_clk_pin <= 0;
            spi_mosi <= 0;
            bit_counter <= 0;
            clk_counter <= 0;
            shift_reg <= 0;
        end else begin
            rx_valid <= 0;
            irq <= 0;
            
            case (state)
                IDLE: begin
                    busy <= 0;
                    spi_cs_n <= 1;
                    spi_clk_pin <= cpol;
                    if (cfg_wr_en && cfg_addr == 20'h85000 && cfg_wr_data[0]) begin
                        state <= TRANSFER;
                        busy <= 1;
                        spi_cs_n <= 0;
                        shift_reg <= tx_data;
                        bit_counter <= 0;
                        clk_counter <= 0;
                        spi_clk_pin <= cpol ^ cpha;  // Initial clock phase
                    end
                end
                
                TRANSFER: begin
                    if (clk_counter >= clk_div) begin
                        clk_counter <= 0;
                        spi_clk_pin <= ~spi_clk_pin;
                        
                        // On falling edge (for mode 0): shift out MOSI, sample MISO
                        if (spi_clk_pin == (cpol ^ cpha)) begin
                            spi_mosi <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], spi_miso};
                            bit_counter <= bit_counter + 1;
                            
                            if (bit_counter == 7) begin
                                // Transfer complete
                                rx_data <= {shift_reg[6:0], spi_miso};
                                rx_valid <= 1;
                                irq <= 1;
                                state <= IDLE;
                            end
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
            endcase
        end
    end
endmodule
