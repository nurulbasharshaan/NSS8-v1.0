module ram_128kb (
    input  wire       clk, wr_en, rd_en,
    input  wire [16:0] addr, // 17 bits = 128KB
    output reg  [7:0]  rd_data
);
    reg [7:0] mem [0:131071]; // 128 KB array
    always @(posedge clk) begin
        if (wr_en) mem[addr] <= wr_data;
        if (rd_en) rd_data <= mem[addr];
    end
endmodule

module rom_64kb (
    input  wire       rd_en,
    input  wire [15:0] addr, // 16 bits = 64KB
    output reg  [7:0]  rd_data
);
    // Initialize ROM with a simple program (See Testbench for details)
    reg [7:0] mem [0:65535]; 
    initial $readmemh("firmware.hex", mem);
    
    always @(*) begin
        if (rd_en) rd_data = mem[addr];
    end
endmodule