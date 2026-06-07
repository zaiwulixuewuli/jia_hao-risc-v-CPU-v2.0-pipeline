module dmem (
    input  wire        clk,
    input  wire        mem_we,
    input  wire [2:0]  mem_type,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data        // 同步读取，寄存器输出
);

    // 1024 x 32bit 内存
    reg [31:0] ram [0:1023];

    // 初始化（可综合，大多数工具支持）
    integer idx;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1)
            ram[idx] = 32'h0;
    end

    wire [9:0] word_addr   = addr[11:2];
    wire [1:0] byte_offset = addr[1:0];

    // ----- 写数据整理（将 write_data 放到正确的字节位置）-----
    wire [31:0] din_word;   // 实际写入 RAM 的 32 位数据
    assign din_word = (mem_we) ? 
        ( (mem_type[1:0] == 2'b00) ? (write_data[7:0]  << (byte_offset * 8)) :
          (mem_type[1:0] == 2'b01) ? (write_data[15:0] << ((byte_offset[1] ? 2 : 0) * 8)) :
          write_data ) : 32'h0;   // 无写操作时 din_word 无效

    // ----- 字节写使能生成 -----
    reg [3:0] we_byte;
    always @(*) begin
        we_byte = 4'b0;
        if (mem_we) begin
            case (mem_type[1:0])
                2'b00: begin  // SB
                    case (byte_offset)
                        2'b00: we_byte[0] = 1'b1;
                        2'b01: we_byte[1] = 1'b1;
                        2'b10: we_byte[2] = 1'b1;
                        2'b11: we_byte[3] = 1'b1;
                    endcase
                end
                2'b01: begin  // SH
                    if (byte_offset[1] == 1'b0) begin
                        we_byte[1:0] = 2'b11;
                    end else begin
                        we_byte[3:2] = 2'b11;
                    end
                end
                2'b10: begin  // SW
                    we_byte = 4'b1111;
                end
                default: we_byte = 4'b0000;
            endcase
        end
    end

    // ----- BRAM 写优先 + 字节使能模板（可综合为块 RAM）-----
    reg [31:0] dout;       // 读数据缓冲
    always @(posedge clk) begin
        // 写操作（独立字节使能）
        if (we_byte[0]) ram[word_addr][7:0]   <= din_word[7:0];
        if (we_byte[1]) ram[word_addr][15:8]  <= din_word[15:8];
        if (we_byte[2]) ram[word_addr][23:16] <= din_word[23:16];
        if (we_byte[3]) ram[word_addr][31:24] <= din_word[31:24];

        // 读操作（写优先：若本周期写使能且地址相同，dout 得到新写入的数据）
        dout <= ram[word_addr];
    end

    // ----- 扩展逻辑（基于 dout，组合输出到 read_data）-----
    always @(*) begin
        case (mem_type)
            3'b000:  // LB
                case (byte_offset)
                    2'b00: read_data = {{24{dout[7]}}, dout[7:0]};
                    2'b01: read_data = {{24{dout[15]}}, dout[15:8]};
                    2'b10: read_data = {{24{dout[23]}}, dout[23:16]};
                    2'b11: read_data = {{24{dout[31]}}, dout[31:24]};
                endcase
            3'b001:  // LH
                if (byte_offset[1] == 0)
                    read_data = {{16{dout[15]}}, dout[15:0]};
                else
                    read_data = {{16{dout[31]}}, dout[31:16]};
            3'b010:  // LW
                read_data = dout;
            3'b100:  // LBU
                case (byte_offset)
                    2'b00: read_data = {24'b0, dout[7:0]};
                    2'b01: read_data = {24'b0, dout[15:8]};
                    2'b10: read_data = {24'b0, dout[23:16]};
                    2'b11: read_data = {24'b0, dout[31:24]};
                endcase
            3'b101:  // LHU
                if (byte_offset[1] == 0)
                    read_data = {16'b0, dout[15:0]};
                else
                    read_data = {16'b0, dout[31:16]};
            default: read_data = dout;
        endcase
    end

endmodule