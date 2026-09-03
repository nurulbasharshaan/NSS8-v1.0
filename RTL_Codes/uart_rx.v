 module uart_rx (
    input  wire       clk, rst_n,
    input  wire       rx_pin,
    output reg [7:0]  rx_data,
    output reg        rx_valid,    // Pulse when data is ready
    output reg        irq          // Interrupt request
);
    reg [3:0] bit_count = 0;
    reg [15:0] baud_counter;
    reg [9:0] shift_reg;
    reg busy = 0;
    localparam BAUD_DIV = 16'd217; // ~115200 baud at 40MHz
    
    // Synchronize RX pin to avoid metastability
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx_pin;
        rx_sync2 <= rx_sync1;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0; rx_valid <= 0; irq <= 0;
            bit_count <= 0; baud_counter <= 0;
        end else begin
            rx_valid <= 0; // Clear valid pulse
            
            if (!busy && !rx_sync2) begin
                // Start bit detected
                busy <= 1;
                baud_counter <= 0;
                bit_count <= 0;
            end else if (busy) begin
                if (baud_counter >= BAUD_DIV) begin
                    baud_counter <= 0;
                    shift_reg <= {rx_sync2, shift_reg[8:1]};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 9) begin // 8 data + 1 stop
                        rx_data <= shift_reg[8:1];
                        rx_valid <= 1;
                        irq <= 1; // Trigger interrupt
                        busy <= 0;
                    end
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end
        end
    end
endmodule
