`timescale 1ns / 1ps


module Ultrasound_Peripheral (
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

    // Ulatrsound signals
    output logic trigger,
    input  logic echo

);

    logic start;
    logic [8:0] distance;
    logic error;


    APB_Intf_US u_APB_Intf_US (.*);

    Ultrasound_top u_Ultrasound_top (
        .*,
        .clk  (PCLK),
        .reset(PRESET)
    );

endmodule


module APB_Intf_US (
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
    //output signals
    output logic        start,
    input  logic [ 8:0] distance,
    input  logic        error
);

    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    assign start = slv_reg0[0];  // UCR

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            slv_reg3 <= 0;

        end else begin
            slv_reg1 <= {31'b0, error};
            slv_reg2 <= error ? 32'b0 : {23'b0, distance};
            PREADY   <= 0;
            if (PSEL && PENABLE) begin
                PREADY <= 1;
                if (PWRITE) begin
                    if (PADDR[3:2] == 2'd0) begin
                        slv_reg0 <= PWDATA; // UCR , lsb로 0,1 보내서 측정 시작 write
                    end
                end
            end else if (slv_reg0[0]) begin
                slv_reg0 <= 0;
            end
        end
    end

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) begin
            PRDATA <= 32'b0;
        end else if (PSEL && PENABLE && !PWRITE) begin
            case (PADDR[3:2])
                2'd1: PRDATA <= slv_reg1;  // USR
                2'd2: PRDATA <= slv_reg2;  // UDR
                default: PRDATA <= 32'b0;
            endcase
        end
    end
endmodule

module Ultrasound_top (
    input logic clk,
    input logic reset,
    input logic start,
    input logic echo,
    output logic trigger,
    output logic [8:0] distance,
    output logic error
);

    logic en_clk_div, tick_10us, tick_1us, echo_high, time_out;
    logic en_wait_cnt, wait_time_out;

    US_Controlunit u_US_Controlunit (.*);

    clk_divider_US u_clk_divider (.*);

    distance_calculator u_distance_calculator (.*);

    wait_echo_counter u_wait_echo_counter (.*);
endmodule


module US_Controlunit (
    input  logic clk,
    input  logic reset,
    // APB Intf US
    input  logic start,
    output logic error,
    // 초음파 센서
    input  logic echo,
    output logic trigger,
    // clk divider
    output logic en_clk_div,
    input  logic tick_10us,
    // distance_calculator
    output logic echo_high,
    input  logic time_out,
    // wait echo cnt
    output logic en_wait_cnt,
    input  logic wait_time_out
);

    localparam IDLE = 2'b00, TRIG = 2'b01, WAIT_ECHO = 2'b10, HIGH_ECHO = 2'b11;

    logic [1:0] state_reg, state_next;
    logic trigger_reg, trigger_next;
    logic en_reg, en_next;
    logic echo_high_reg, echo_high_next;
    logic prev_start, start_pulse;
    logic error_reg, error_next;
    logic echo_sync1, echo_sync2;
    logic echo_rising, echo_falling;
    logic en_wait_cnt_reg, en_wait_cnt_next;

    assign trigger = trigger_reg;
    assign en_clk_div = en_reg;
    assign echo_high = echo_high_reg;
    assign error = error_reg;
    assign en_wait_cnt = en_wait_cnt_reg;
    assign echo_rising = !echo_sync2 & echo_sync1;
    assign echo_falling = echo_sync2 & !echo_sync1;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state_reg <= 0;
            trigger_reg <= 0;
            en_reg <= 0;
            echo_high_reg <= 0;
            error_reg <= 0;
            echo_sync1 <= 0;
            echo_sync2 <= 0;
            en_wait_cnt_reg <= 0;
        end else begin
            state_reg <= state_next;
            trigger_reg <= trigger_next;
            en_reg <= en_next;
            echo_high_reg <= echo_high_next;
            prev_start <= start;
            error_reg <= error_next;
            echo_sync1 <= echo;
            echo_sync2 <= echo_sync1;
            en_wait_cnt_reg <= en_wait_cnt_next;
        end
    end

    assign start_pulse = !prev_start & start;

    always_comb begin
        state_next = state_reg;
        trigger_next = trigger_reg;
        en_next = en_reg;
        echo_high_next = echo_high_reg;
        error_next = error_reg;
        en_wait_cnt_next = en_wait_cnt_reg;

        case (state_reg)
            IDLE: begin
                trigger_next = 0;
                en_next = 0;
                echo_high_next = 0;
                en_wait_cnt_next = 0;

                if (start_pulse) begin
                    state_next = TRIG;
                    trigger_next = 1;
                    en_next = 1;
                    error_next = 0;
                end
            end

            TRIG: begin
                trigger_next = 1;
                en_next = 1;
                echo_high_next = 0;
                error_next = 0;

                if (tick_10us) begin
                    state_next = WAIT_ECHO;
                    trigger_next = 0;
                    en_wait_cnt_next = 1;
                end
            end

            WAIT_ECHO: begin
                trigger_next = 0;
                en_next = 0;
                echo_high_next = 0;
                en_wait_cnt_next = 1;

                if (wait_time_out) begin
                    state_next = IDLE;
                    en_wait_cnt_next = 0;
                    error_next = 1;
                end else if (echo_rising) begin
                    state_next = HIGH_ECHO;
                    en_next = 1;
                    en_wait_cnt_next = 0;
                end
            end

            HIGH_ECHO: begin
                trigger_next = 0;
                en_next = 1;
                echo_high_next = 1;

                if (time_out) begin
                    state_next = IDLE;
                    error_next = 1;
                end else if (echo_falling) begin
                    state_next = IDLE;
                end
            end
        endcase
    end
endmodule

module clk_divider_US (
    input  logic clk,
    input  logic reset,
    input  logic en_clk_div,
    output logic tick_1us,
    output logic tick_10us
);

    logic [$clog2(100):0] count_1us;
    logic [3:0] count_10us;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count_1us  <= 0;
            count_10us <= 0;
            tick_1us   <= 0;
            tick_10us  <= 0;
        end else begin
            if (en_clk_div) begin
                if (count_1us == 100 - 1) begin  // 1us 조건
                    count_1us <= 0;
                    tick_1us  <= 1;

                    if (count_10us == 10 - 1) begin  // 10us 조건
                        count_10us <= 0;
                        tick_10us  <= 1;
                    end else begin
                        count_10us <= count_10us + 1;
                        tick_10us  <= 0;
                    end


                end else begin
                    count_1us <= count_1us + 1;
                    tick_1us  <= 0;
                    tick_10us <= 0;
                end
            end else begin
                count_1us  <= 0;
                count_10us <= 0;
                tick_1us   <= 0;
                tick_10us  <= 0;
            end
        end
    end
endmodule

module distance_calculator (
    input logic clk,
    input logic reset,
    input logic echo_high,
    input logic tick_1us,
    output logic [8:0] distance,
    output logic time_out
);

    parameter TIME_MAX = 25000;

    logic [$clog2(TIME_MAX)-1:0] echo_high_cnt, count_save;

    logic prev_echo_high;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            echo_high_cnt <= 0;
            count_save <= 0;
            time_out <= 0;
            prev_echo_high <= 0;
        end else begin
            prev_echo_high <= echo_high;
            if (echo_high) begin
                if (tick_1us) begin
                    if (echo_high_cnt == TIME_MAX - 1) begin
                        time_out <= 1;
                        echo_high_cnt <= 0;
                    end else begin
                        time_out <= 0;
                        echo_high_cnt <= echo_high_cnt + 1;
                    end
                end
            end else begin
                if (prev_echo_high && !echo_high) begin
                    count_save <= echo_high_cnt;
                end
                echo_high_cnt <= 0;
                time_out <= 0;
            end
        end
    end

    // assign distance = count_save / 58;
    assign distance = (count_save * 1130) >> 16;

endmodule

module wait_echo_counter (
    input  logic clk,
    input  logic reset,
    input  logic en_wait_cnt,
    output logic wait_time_out
);

    parameter TIMEOUT_WAIT = 500000;  // 5ms
    logic [$clog2(TIMEOUT_WAIT)-1:0] count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            wait_time_out <= 0;
        end else begin
            if (en_wait_cnt) begin
                if (count == TIMEOUT_WAIT - 1) begin
                    count <= 0;
                    wait_time_out <= 1;
                end else begin
                    count <= count + 1;
                    wait_time_out <= 0;
                end
            end else begin
                count <= 0;
                wait_time_out <= 0;
            end
        end
    end
endmodule
