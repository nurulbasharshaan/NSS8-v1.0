module timer_pwm (
    input  wire       clk, rst_n,
    
    // Memory-mapped registers
    input  wire [19:0] cfg_addr,
    input  wire [7:0]  cfg_wr_data,
    output reg  [7:0]  cfg_rd_data,
    input  wire        cfg_wr_en,
    input  wire        cfg_rd_en,
    
    output reg        pwm_out,
    output reg        irq     // Overflow interrupt
);
    // Register Map:
    // 0x86000: Control (bit 0=enable, bit 1=irq_enable, bit 2=pwm_enable)
    // 0x86001: Prescaler low
    // 0x86002: Prescaler high
    // 0x86003: Counter low (read-only)
    // 0x86004: Counter high (read-only)
    // 0x86005: Compare low (PWM duty cycle)
    // 0x86006: Compare high
    // 0x86007: Status (bit 0=overflow flag, write 1 to clear)
    
    reg [15:0] prescaler;
    reg [15:0] prescale_counter;
    reg [15:0] counter;
    reg [15:0] compare;
    reg enable, irq_enable, pwm_enable;
    reg overflow_flag;
    
    // Register write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler <= 0;
            compare <= 0;
            enable <= 0;
            irq_enable <= 0;
            pwm_enable <= 0;
            overflow_flag <= 0;
        end else if (cfg_wr_en) begin
            case (cfg_addr)
                20'h86000: begin
                    enable     <= cfg_wr_data[0];
                    irq_enable <= cfg_wr_data[1];
                    pwm_enable <= cfg_wr_data[2];
                end
                20'h86001: prescaler[7:0]  <= cfg_wr_data;
                20'h86002: prescaler[15:8] <= cfg_wr_data;
                20'h86005: compare[7:0]    <= cfg_wr_data;
                20'h86006: compare[15:8]   <= cfg_wr_data;
                20'h86007: if (cfg_wr_data[0]) overflow_flag <= 0;
            endcase
        end
    end
    
    // Register read
    always @(*) begin
        cfg_rd_data = 8'hFF;
        case (cfg_addr)
            20'h86003: cfg_rd_data = counter[7:0];
            20'h86004: cfg_rd_data = counter[15:8];
            20'h86007: cfg_rd_data = {7'b0, overflow_flag};
            default:   cfg_rd_data = 8'hFF;
        endcase
    end
    
    // Timer logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            prescale_counter <= 0;
            pwm_out <= 0;
            irq <= 0;
        end else begin
            irq <= 0;
            
            if (enable) begin
                if (prescale_counter >= prescaler) begin
                    prescale_counter <= 0;
                    counter <= counter + 1;
                    
                    // PWM output
                    if (pwm_enable) begin
                        pwm_out <= (counter < compare) ? 1'b1 : 1'b0;
                    end
                    
                    // Overflow detection
                    if (counter == 16'hFFFF) begin
                        overflow_flag <= 1;
                        if (irq_enable) irq <= 1;
                    end
                end else begin
                    prescale_counter <= prescale_counter + 1;
                end
            end else begin
                counter <= 0;
                prescale_counter <= 0;
            end
        end
    end
endmodule