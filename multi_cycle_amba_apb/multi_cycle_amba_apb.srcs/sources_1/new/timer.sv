`timescale 1ns / 1ps

module timer_periph (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    logic [31:0] tcnt;
    logic en;
    logic clear;
    logic [31:0] psc;
    logic [31:0] arr;

    APB_Intf_TIMER u_APB_Intf_Timer (.*);

    Timer u_timer (
        .clk(PCLK),
        .reset(PRESET),
        .en(en),
        .clear(clear),
        .psc(psc),
        .arr(arr),
        .tcnt(tcnt)
    );


endmodule

module APB_Intf_TIMER (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,


    input logic [31:0] tcnt,
    output logic en,
    output logic clear,
    output logic [31:0] psc,
    output logic [31:0] arr
);

    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    assign en = slv_reg0[0];  // TCR[0]
    assign clear = slv_reg0[1];  // TCR[1]
    // assign slv_reg1 = tcnt;
    assign psc = slv_reg2;
    assign arr = slv_reg3;

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) begin
            PREADY   <= 0;
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;
        end else begin
            slv_reg1 <= tcnt;
            PREADY   <= 0;
            if (PSEL && PENABLE) begin
                PREADY <= 1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd2: slv_reg2 <= PWDATA;
                        2'd3: slv_reg3 <= PWDATA;
                    endcase
                end
            end
        end
    end

    always_comb begin
        if (PSEL && PENABLE && !PWRITE) begin
            case (PADDR[3:2])
                2'd1: PRDATA = slv_reg1;  // tcnt
                default: PRDATA = 32'b0;
            endcase
        end else begin
            PRDATA = 32'b0;  // 필수로 초기화
        end
    end
endmodule

module Timer (
    input logic clk,
    input logic reset,
    input logic en,
    input logic clear,
    input logic [31:0] psc,
    input logic [31:0] arr,
    output logic [31:0] tcnt
);

    logic tick;

    prescaler u_prescaler (.*);

    counter_timer u_counter (.*);
endmodule

module counter_timer (
    input logic clk,
    input logic reset,
    input logic tick,
    input logic clear,
    input logic [31:0] arr,
    output logic [31:0] tcnt
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            tcnt <= 0;
        end else begin
            if (tick) begin
                if (tcnt == arr) begin
                    tcnt <= 0;
                end else begin
                    tcnt <= tcnt + 1;
                end
            end
        end
    end
endmodule

module prescaler (
    input logic clk,
    input logic reset,
    input logic en,
    input logic clear,
    input logic [31:0] psc,
    output logic tick
);
    logic [31:0] clk_count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset || clear) begin
            clk_count <= 0;
            tick <= 0;
        end else begin
            if (en) begin
                if (clk_count == psc) begin
                    clk_count <= 0;
                    tick <= 1;
                end else begin
                    tick <= 0;
                    clk_count <= clk_count + 1;
                end
            end
        end
    end

endmodule
