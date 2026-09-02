module uart_tx (
    input  wire       clk, rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_wr_en,
    output reg        tx_pin
);
    reg [9:0] shift_reg;
    reg [15:0] baud_counter;
    reg busy = 0;
    localparam BAUD_DIV = 16'd217; // ~115200 baud at 40MHz (40M/115200)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin busy <= 0; tx_pin <= 1; end
        else if (!busy && tx_wr_en) begin
            shift_reg <= {1'b1, tx_data, 1'b0}; // Stop, Data, Start
            busy <= 1; baud_counter <= 0;
        end else if (busy) begin
            if (baud_counter >= BAUD_DIV) begin
                baud_counter <= 0;
                shift_reg <= {1'b1, shift_reg[9:1]};
                tx_pin <= shift_reg[0];
                if (shift_reg[9:1] == 9'h1FF) busy <= 0; // Done
            end else baud_counter <= baud_counter + 1;
        end
    end
endmodule

module gpio_8bit (
    input  wire       clk, rst_n,
    input  wire [7:0] wr_data,
    input  wire       wr_en,
    output reg  [7:0] pins
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pins <= 0;
        else if (wr_en) pins <= wr_data;
    end
endmodule