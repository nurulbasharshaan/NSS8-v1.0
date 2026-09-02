module cpu_8bit_v3 (
    input  wire       clk, rst_n,
    input  wire       irq,
    input  wire       bus_grant,    // From bus arbiter
    
    output reg  [19:0] addr_bus,
    output reg  [7:0]  wr_data,
    input  wire [7:0]  rd_data,
    output reg         wr_en, rd_en,
    output reg         irq_ack
);
    reg [7:0] A, X, Y;
    reg [19:0] PC;
    reg [7:0] SP;
    reg [7:0] IR, operand;
    reg [7:0] flags;
    
    localparam FLAG_Z = 0, FLAG_N = 1, FLAG_C = 2, FLAG_I = 3;
    localparam FETCH = 0, DECODE = 1, EXECUTE = 2, INTERRUPT = 3;
    reg [1:0] state = FETCH;
    
    reg irq_pending = 0;
    wire [8:0] add_sum = {1'b0, A} + {1'b0, operand}; // 9-bit: bit 8 is carry-out
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC <= 20'h00000; A <= 0; X <= 0; Y <= 0; SP <= 8'hFF;
            flags <= 0; state <= FETCH; irq_pending <= 0;
            wr_en <= 0; rd_en <= 0; irq_ack <= 0;
        end else begin
            wr_en <= 0; rd_en <= 0; irq_ack <= 0;
            
            if (irq && !flags[FLAG_I]) irq_pending <= 1;
            
            case (state)
                FETCH: begin
                    if (irq_pending && !flags[FLAG_I]) begin
                        state <= INTERRUPT;
                    end else if (bus_grant) begin
                        addr_bus <= PC;
                        rd_en <= 1;
                        state <= DECODE;
                    end
                end
                
                DECODE: begin
                    if (bus_grant) begin
                        IR <= rd_data;
                        PC <= PC + 1;
                        addr_bus <= PC;
                        rd_en <= 1;
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    if (bus_grant) begin
                        operand <= rd_data;
                        PC <= PC + 1;
                        
                        case (IR)
                            8'h00: ; // NOP
                            8'h01: begin // LDA imm
                                A <= operand;
                                flags[FLAG_Z] <= (operand == 0);
                                flags[FLAG_N] <= operand[7];
                            end
                            8'h03: begin // ADD imm
                                A <= add_sum[7:0];
                                flags[FLAG_Z] <= (add_sum[7:0] == 8'h00);
                                flags[FLAG_N] <= add_sum[7];
                                flags[FLAG_C] <= add_sum[8];
                            end
                            8'h04: PC <= {PC[19:8], operand}; // JMP (simplified)
                            8'h06: X <= operand;
                            8'h07: Y <= operand;
                            8'h09: flags[FLAG_I] <= 0; // CLI
                            8'h0A: flags[FLAG_I] <= 1; // SEI
                            default: ;
                        endcase
                        state <= FETCH;
                    end
                end
                
                INTERRUPT: begin
                    irq_pending <= 0;
                    irq_ack <= 1;
                    flags[FLAG_I] <= 1;
                    PC <= 20'hFFF00;
                    state <= FETCH;
                end
            endcase
        end
    end
endmodule