module clock_manager (
    input  wire       clk_in,      // Physical board clock (e.g., 250 MHz)
    input  wire       rst_n,
    input  wire [7:0] clk_div_reg, // Runtime register to change speed
    output reg        sys_clk      // Scaled system clock (e.g., 40 MHz)
);
    reg [7:0] counter = 0;
    reg [7:0] target_div;

    // If clk_div_reg is 0, run at max speed (divide by 1). 
    // Otherwise, divide by (clk_div_reg + 1).
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            sys_clk <= 0;
            target_div <= 5; // Default: ~40MHz if clk_in is 250MHz (250/6)
        end else begin
            target_div <= (clk_div_reg == 0) ? 0 : clk_div_reg;
            
            if (counter >= target_div) begin
                counter <= 0;
                sys_clk <= ~sys_clk; // Toggle clock
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule