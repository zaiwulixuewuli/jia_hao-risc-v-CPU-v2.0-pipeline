module mem_io (
    input  wire        clk,
    input  wire        mem_we,
    input  wire [2:0]  mem_type,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

    dmem u_dmem (
        .clk(clk),
        .mem_we(mem_we),
        .mem_type(mem_type),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
    );

endmodule
