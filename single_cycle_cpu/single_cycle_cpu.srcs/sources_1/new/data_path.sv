`timescale 1ns / 1ps

`include "defines.sv"

module DataPath (
    input  logic        clk,
    input  logic        reset,
    input  logic        regFileWe,
    input  logic [ 3:0] aluControl,
    input  logic        aluSrcMuxSel,
    input  logic [ 2:0] RFWDSrcMuxSel,
    input  logic        branch,
    input  logic        jal,
    jalr,
    output logic [31:0] instrMemAddr,
    input  logic [31:0] instrCode,
    output logic [31:0] dataAddr,
    output logic [31:0] dataWData,
    input  logic [31:0] dataRData
);
    logic [31:0] aluResult, RFData1, RFData2;
    logic [31:0] PCSrcData, PCOutData;
    logic [31:0] immExt, aluSrcMuxOut, RFWDSrcMuxOut;
    logic btaken;
    logic PCSrcMuxSel;
    logic [31:0] PC_4_Adder_Result;
    logic [31:0] PC_imm_Adder_Result;
    logic [31:0] JALR_Mux_Out;
    logic branch_enable;

    assign instrMemAddr  = PCOutData;
    assign dataAddr      = aluResult;
    assign dataWData     = RFData2;

    assign branch_enable = branch & btaken;
    assign PCSrcMuxSel   = branch_enable | jal;

    RegisterFile U_RegFile (
        .clk(clk),
        .we(regFileWe),
        .RAddr1(instrCode[19:15]),
        .RAddr2(instrCode[24:20]),
        .WAddr(instrCode[11:7]),
        .WData(RFWDSrcMuxOut),
        .RData1(RFData1),
        .RData2(RFData2)
    );

    mux_2x1 U_ALUSrcMux (
        .sel(aluSrcMuxSel),
        .x0 (RFData2),
        .x1 (immExt),
        .y  (aluSrcMuxOut)
    );

    mux_2x1 U_JALR_Mux (
        .sel(jalr),
        .x0 (PCOutData),
        .x1 (RFData1),
        .y  (JALR_Mux_Out)
    );

    mux_5x1 U_RFWDSrcMux (
        .sel(RFWDSrcMuxSel),
        .x0 (aluResult),
        .x1 (dataRData),
        .x2 (immExt),
        .x3 (PC_imm_Adder_Result),
        .x4 (PC_4_Adder_Result),
        .y  (RFWDSrcMuxOut)
    );

    alu U_ALU (
        .aluControl(aluControl),
        .a(RFData1),
        .b(aluSrcMuxOut),
        .result(aluResult),
        .btaken(btaken)
    );

    extend U_ImmExtend (
        .instrCode(instrCode),
        .immExt(immExt)
    );

    register U_PC (
        .clk(clk),
        .reset(reset),
        .d(PCSrcData),
        .q(PCOutData)
    );

    mux_2x1 u_PCSrcMux (
        .sel(PCSrcMuxSel),
        .x0 (PC_4_Adder_Result),
        .x1 (PC_imm_Adder_Result),
        .y  (PCSrcData)
    );

    adder U_PC_4_Adder (
        .a(32'd4),
        .b(PCOutData),
        .y(PC_4_Adder_Result)
    );

    adder u_PC_imm_Adder (
        .a(immExt),
        .b(JALR_Mux_Out),
        .y(PC_imm_Adder_Result)
    );
endmodule


module alu (
    input logic [3:0] aluControl,
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] result,
    output logic btaken
);
    always_comb begin
        case (aluControl)
            `ADD:    result = a + b;
            `SUB:    result = a - b;
            `SLL:    result = a << b;
            `SRL:    result = a >> b;
            `SRA:    result = $signed(a) >>> b[4:0];
            `SLT:    result = ($signed(a) < $signed(b)) ? 1 : 0;
            `SLTU:   result = (a < b) ? 1 : 0;
            `XOR:    result = a ^ b;
            `OR:     result = a | b;
            `AND:    result = a & b;
            default: result = 32'bx;
        endcase
    end

    always_comb begin
        btaken = 1'b0;
        case (aluControl[2:0])
            `BEQ:  btaken = (a == b);
            `BNE:  btaken = (a != b);
            `BLT:  btaken = ($signed(a) < $signed(b));
            `BGE:  btaken = ($signed(a) >= $signed(b));
            `BLTU: btaken = (a < b);
            `BGEU: btaken = (a >= b);
        endcase
    end
endmodule

module register (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] d,
    output logic [31:0] q
);
    always_ff @(posedge clk, posedge reset) begin
        if (reset) q <= 0;
        else q <= d;
    end
endmodule

module adder (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] y
);
    assign y = a + b;
endmodule

module RegisterFile (
    input  logic        clk,
    input  logic        we,
    input  logic [ 4:0] RAddr1,
    input  logic [ 4:0] RAddr2,
    input  logic [ 4:0] WAddr,
    input  logic [31:0] WData,
    output logic [31:0] RData1,
    output logic [31:0] RData2
);
    logic [31:0] RegFile[0:2**5-1];

    initial begin
        for (int i = 0; i < 32; i++) begin
            RegFile[i] = i;
        end
    end

    always_ff @(posedge clk) begin
        if (we) RegFile[WAddr] <= WData;
    end

    assign RData1 = (RAddr1 != 0) ? RegFile[RAddr1] : 32'b0;
    assign RData2 = (RAddr2 != 0) ? RegFile[RAddr2] : 32'b0;
endmodule

module mux_2x1 (
    input  logic        sel,
    input  logic [31:0] x0,
    input  logic [31:0] x1,
    output logic [31:0] y
);
    always_comb begin
        case (sel)
            1'b0:    y = x0;
            1'b1:    y = x1;
            default: y = 32'bx;
        endcase
    end
endmodule

module mux_5x1 (
    input  logic [ 2:0] sel,
    input  logic [31:0] x0,
    input  logic [31:0] x1,
    input  logic [31:0] x2,
    input  logic [31:0] x3,
    input  logic [31:0] x4,
    output logic [31:0] y
);
    always_comb begin
        case (sel)
            3'd0:    y = x0;
            3'd1:    y = x1;
            3'd2:    y = x2;
            3'd3:    y = x3;
            3'd4 :   y = x4;
            default: y = 32'bx;
        endcase
    end
endmodule

module extend (
    input  logic [31:0] instrCode,
    output logic [31:0] immExt
);
    wire [6:0] opcode = instrCode[6:0];
    wire [2:0] func3 = instrCode[14:12];

    always_comb begin
        immExt = 32'bx;
        case (opcode)
            `OP_TYPE_R: immExt = 32'bx;

            `OP_TYPE_L: immExt = {{20{instrCode[31]}}, instrCode[31:20]};

            `OP_TYPE_S:
            immExt = {{20{instrCode[31]}}, instrCode[31:25], instrCode[11:7]};

            `OP_TYPE_I: begin
                case (func3)
                    3'b001:  immExt = {27'b0, instrCode[24:20]};
                    3'b101:  immExt = {27'b0, instrCode[24:20]};
                    3'b011:  immExt = {20'b0, instrCode[31:20]};
                    default: immExt = {{20{instrCode[31]}}, instrCode[31:20]};
                endcase
            end

            `OP_TYPE_B: begin
                immExt = {
                    {19{instrCode[31]}},
                    instrCode[31],
                    instrCode[7],
                    instrCode[30:25],
                    instrCode[11:8],
                    1'b0
                };
            end

            `OP_TYPE_LU: begin
                immExt = {instrCode[31:12], {12'b0}};
            end

            `OP_TYPE_AU: begin
                immExt = {instrCode[31:12], {12'b0}};
            end

            `OP_TYPE_J: begin
                immExt = {
                    {11{instrCode[31]}},
                    instrCode[31],
                    instrCode[19:12],
                    instrCode[20],
                    instrCode[30:21],
                    1'b0
                };
            end

            `OP_TYPE_JL: begin
                immExt = {{20{instrCode[31]}}, instrCode[31:20]};
            end


            default: immExt = 32'bx;
        endcase
    end
endmodule
