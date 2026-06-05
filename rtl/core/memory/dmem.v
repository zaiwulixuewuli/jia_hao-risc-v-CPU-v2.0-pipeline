module dmem (
    input  wire        clk,
    input  wire        mem_we,
    input  wire [2:0]  mem_type,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data        // 同步读取，寄存器输出
);

    reg [31:0] ram [0:1023];

    // 初始化 RAM（可综合，大多数工具支持）
    integer idx;
    initial begin
        for (idx = 0; idx < 1024; idx = idx + 1)
            ram[idx] = 32'h0;
    end

    wire [9:0] word_addr   = addr[11:2];
    wire [1:0] byte_offset = addr[1:0];

    // 写转发：保存上一周期的写信息（用于下一周期读转发，但同步读不需要？）
    // 实际上同步读时，同一周期内写和读同时发生，需要先写后读的转发。
    // 我们直接在 always 块内处理：先读原始值，再写，再根据地址相等决定输出。

    always @(posedge clk) begin
        // 1. 读取当前地址的原始数据（此时尚未写入新值）
        reg [31:0] raw_word;
        raw_word = ram[word_addr];

        // 2. 若写使能，生成新字并写入
        if (mem_we) begin
            case (mem_type[1:0])
                2'b00: begin  // SB
                    case (byte_offset)
                        2'b00: raw_word[7:0]   = write_data[7:0];
                        2'b01: raw_word[15:8]  = write_data[7:0];
                        2'b10: raw_word[23:16] = write_data[7:0];
                        2'b11: raw_word[31:24] = write_data[7:0];
                    endcase
                end
                2'b01: begin  // SH
                    case (byte_offset[1])
                        1'b0: raw_word[15:0]  = write_data[15:0];
                        1'b1: raw_word[31:16] = write_data[15:0];
                    endcase
                end
                2'b10:        // SW
                    raw_word = write_data;
                default: ;
            endcase
            ram[word_addr] <= raw_word;   // 写入新值
        end

        // 3. 根据 mem_type 扩展数据并输出到 read_data
        //    注意：此时 raw_word 已经反映写操作后的新值（如果写使能且地址匹配）
        case (mem_type)
            3'b000:  // LB
                case (byte_offset)
                    2'b00: read_data <= {{24{raw_word[7]}}, raw_word[7:0]};
                    2'b01: read_data <= {{24{raw_word[15]}}, raw_word[15:8]};
                    2'b10: read_data <= {{24{raw_word[23]}}, raw_word[23:16]};
                    2'b11: read_data <= {{24{raw_word[31]}}, raw_word[31:24]};
                endcase
            3'b001:  // LH
                case (byte_offset[1])
                    1'b0: read_data <= {{16{raw_word[15]}}, raw_word[15:0]};
                    1'b1: read_data <= {{16{raw_word[31]}}, raw_word[31:16]};
                endcase
            3'b010:  // LW
                read_data <= raw_word;
            3'b100:  // LBU
                case (byte_offset)
                    2'b00: read_data <= {24'b0, raw_word[7:0]};
                    2'b01: read_data <= {24'b0, raw_word[15:8]};
                    2'b10: read_data <= {24'b0, raw_word[23:16]};
                    2'b11: read_data <= {24'b0, raw_word[31:24]};
                endcase
            3'b101:  // LHU
                case (byte_offset[1])
                    1'b0: read_data <= {16'b0, raw_word[15:0]};
                    1'b1: read_data <= {16'b0, raw_word[31:16]};
                endcase
            default:
                read_data <= raw_word;
        endcase
    end

endmodule