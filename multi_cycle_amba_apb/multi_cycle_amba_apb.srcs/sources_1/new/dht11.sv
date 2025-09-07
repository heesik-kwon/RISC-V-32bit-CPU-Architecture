`timescale 1ns / 1ps
module DHT11_Controller_Periph (
    // global signal  
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // outport signals
    inout               dht_io

    // for verification
    // output logic [7:0]  led,
    // output logic [7:0]  led_dht

);
    logic        start_trig;
    logic        done;
    logic [15:0] hmd;
    logic [15:0] tmp;
    logic [ 7:0] sum;

    APB_SlaveIntf_dht11 U_APB_Intf_dht11 (.*);
    dht11_controller U_dht11_controller (.*);
endmodule

module APB_SlaveIntf_dht11 (
    // global signal 
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    // output logic [7:0] led,
    // internal signals
    output logic        start_trig,
    input  logic        done,
    input  logic [15:0] hmd,
    input  logic [15:0] tmp,
    input  logic [ 7:0] sum
);
    typedef enum {
        IDLE,
        CHECK,
        CHECK_TRIGGER,
        TRIGGER,
        READ,
        HOLD,
        HOLD2
    } state_e;
    state_e state, state_next;

    logic [31:0] slv_reg0, slv_reg0_next;
    logic [31:0] slv_reg1, slv_reg2, slv_reg3;
    logic [31:0] PREADY_next;
    logic [31:0] PRDATA_next;
    // logic [7:0] led_next;

    logic start_trig_next;
    assign slv_reg1 = {16'b0, hmd};
    assign slv_reg2 = {16'b0, tmp};
    assign slv_reg3[7:0] = sum;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            state    <= IDLE;
            PRDATA   <= 0;
            PREADY   <= 1'b0;
            start_trig <= 0;
            // led     <= 0;
        end else begin
            slv_reg0 <= slv_reg0_next;
            state    <= state_next;
            PRDATA   <= PRDATA_next;
            PREADY   <= PREADY_next;
            start_trig <= start_trig_next;
            // led     <= led_next;
        end
    end

    always_comb begin
        slv_reg0_next = slv_reg0;
        state_next = state;
        PRDATA_next = PRDATA;
        PREADY_next = PREADY;
        // led_next = led;
        start_trig_next = start_trig;
        case (state)
            IDLE: begin
                slv_reg0_next = 1'b0;
                PREADY_next = 1'b0;
                start_trig_next = 1'b0;
                if (PSEL && PENABLE) begin
                    state_next = CHECK;
                end
            end

            CHECK: begin
                if (PWRITE) begin
                    // led_next[0] = 1'b1;
                    state_next = CHECK_TRIGGER;
                    case (PADDR[3:2])
                        2'd0: slv_reg0_next = PWDATA;
                        2'd1: ;  //slv_reg1 = PWDATA;
                        2'd2: ;  //slv_reg2 = PWDATA;
                        2'd3: ;  //slv_reg3 = PWDATA;
                    endcase
                end else begin
                    state_next = READ;
                    case (PADDR[3:2])
                        2'd0: ;  //PRDATA = slv_reg0;
                        2'd1: begin
                            PRDATA_next = slv_reg1;
                            // led_next[6] = 1'b1;
                        end
                        2'd2: PRDATA_next = slv_reg2;
                        2'd3: PRDATA_next = slv_reg3;
                    endcase
                end
            end
            CHECK_TRIGGER: begin
                // led_next[1] = 1'b1;
                if (slv_reg0 != 0) begin
                    state_next = TRIGGER;
                    start_trig_next = 1'b1;
                end else begin
                    slv_reg0_next = 1'b0;
                    state_next = HOLD;
                    PREADY_next = 1'b1;
                end

            end

            TRIGGER: begin
                // led_next[2] = 1'b1;
                slv_reg0_next   = 0;
                start_trig_next = 1'b0;
                if (done) begin
                    // led_next[3] = 1'b1;
                    state_next  = HOLD;
                    PREADY_next = 1'b1;
                end
            end


            READ: begin
                state_next  = HOLD;
                PREADY_next = 1'b1;
                // led_next[7] = 1'b1;
            end

            HOLD: begin
                state_next  = IDLE;
                PREADY_next = 1'b0;
                // led_next[4] = 1'b1;
            end
        endcase
    end
endmodule


module dht11_controller (
    input               PCLK,
    input               PRESET,
    inout               dht_io,
    input  logic        start_trig,
    output logic        done,
    output logic [15:0] hmd,
    output logic [15:0] tmp,
    output logic [ 7:0] sum

);
    parameter START_CNT = 18000, WAIT_CNT = 30, SYNC_CNT = 80, DATA_0 = 40,
    STOP_CNT = 5, TIMEOUT = 20000, BIT_COUNT = 40;
    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_LOW = 3, SYNC_HIGH = 4, DATA_SYNC = 5, DATA_HIGH_WAIT = 6, DATA_CHECK = 7, HOLD_ON = 8;

    logic [3:0] state, next;
    logic [$clog2(START_CNT)-1:0] time_count_reg, time_count_next;
    // reg [$clog2(WAIT_CNT)-1:0] us30_count_reg, us30_count_next;


    logic io_out_reg, io_out_next;  // io라도 reg, next써야함
    logic led_ind_reg, led_ind_next;
    logic io_oe_reg, io_oe_next;  // output enable


    logic [$clog2(BIT_COUNT)-1:0] bit_count_reg, bit_count_next;

    logic [39:0] data_reg, data_next;  //data 받을 때

    logic sensor_done, sensor_done_next;

    logic clk_1us;

    assign dht_io = (io_oe_reg) ? io_out_reg : 1'bZ;
    assign hmd[15:8] = data_reg[39:32];
    assign hmd[7:0] = data_reg[31:24];
    assign tmp[15:8] = data_reg[23:16];
    assign tmp[7:0] = data_reg[15:8];
    assign sum = data_reg[7:0];

    assign done = sensor_done;

    always @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            state <= 0;
            time_count_reg <= 0;
            io_out_reg <= 1;
            led_ind_reg <= 0;
            io_oe_reg <= 0;
            bit_count_reg <= 0;
            data_reg <= 0;
            sensor_done <= 0;
            // led_dht<=0;

        end else begin
            state <= next;
            time_count_reg <= time_count_next;
            io_out_reg <= io_out_next;
            led_ind_reg <= led_ind_next;
            io_oe_reg <= io_oe_next;
            bit_count_reg <= bit_count_next;
            data_reg <= data_next;
            sensor_done <= sensor_done_next;
            // led_dht <= led_dht_next ;
        end
    end

    always @(*) begin
        next = state;
        time_count_next = time_count_reg;
        io_out_next = io_out_reg;
        led_ind_next = led_ind_reg;
        io_oe_next = io_oe_reg;
        bit_count_next = bit_count_reg;
        data_next = data_reg;
        sensor_done_next = sensor_done;
        // led_dht_next = led_dht;
        case (state)
            IDLE: begin
                io_out_next = 1;
                io_oe_next = 1;
                led_ind_next = 1'b0;
                sensor_done_next = 1'b0;
                // led_dht_next = 0;
                if (start_trig) begin
                    next = START;
                    time_count_next = 0;
                    led_ind_next = 1'b1;
                    // led_dht_next[0] = 1;
                end
            end

            START: begin
                io_out_next = 0;
                io_oe_next  = 1;
                if (clk_1us) begin
                    if (time_count_reg == START_CNT - 1) begin
                        next = WAIT;
                        time_count_next = 0;
                    end else begin
                        time_count_next = time_count_reg + 1;
                    end
                end
            end
            WAIT: begin
                io_out_next = 1;
                io_oe_next  = 1;

                if (clk_1us) begin
                    if (time_count_reg == WAIT_CNT - 1) begin
                        next = SYNC_LOW;
                        time_count_next = 0;
                        // led_dht_next[1] = 1;              
                    end else begin
                        time_count_next = time_count_reg + 1;
                    end
                end
            end


            //sensor의 신호

            SYNC_LOW: begin  //state=3, 80us
                //io_out_next는 바꿔줄 필요없음 high impedance가 되니깐
                io_oe_next = 0;     //io_out_reg을 output으로 사용할 때만 Z상태가 돼서 외부에서 값을 읽을 수가 있음 
                //count할 필요 없음 low로 넘어가는지 high로 넘어가는지만 판단
                if (clk_1us) begin
                    if (dht_io) begin
                        next = SYNC_HIGH;
                        time_count_next = 0;
                        // led_dht_next[2] = 1;
                    end
                end
            end

            SYNC_HIGH: begin  //state=4, 80us
                io_oe_next = 0;
                if (clk_1us) begin
                    if (!dht_io) begin
                        next = DATA_SYNC;
                        time_count_next = 0;
                        // led_dht_next[3] = 1;
                    end
                end
            end

            DATA_SYNC: begin  // state=5
                if (clk_1us) begin
                    if (dht_io) begin
                        next = DATA_HIGH_WAIT;
                        // led_dht_next[4] = 1;                
                    end
                end
            end

            DATA_HIGH_WAIT: begin
                io_oe_next = 0;
                if (clk_1us) begin
                    if (!dht_io) begin
                        // High 끝남 → bit 판단 준비
                        next = DATA_CHECK;
                        // led_dht_next[5] = 1;                
                    end else begin
                        // High 유지 중 → 시간 누적
                        time_count_next = time_count_reg + 1;
                        next = DATA_HIGH_WAIT;
                    end
                end
            end

            DATA_CHECK: begin
                // time_count 기준으로 0인지 1인지 결정
                data_next[BIT_COUNT - 1 - bit_count_reg] = (time_count_reg <= DATA_0) ? 1'b0 : 1'b1;
                time_count_next = 0;
                if (bit_count_reg == BIT_COUNT - 1) begin
                    next = HOLD_ON;
                    bit_count_next = 0;
                    sensor_done_next = 1;
                    // led_dht_next[7] = 1;
                end else begin
                    next = DATA_SYNC;
                    bit_count_next = bit_count_reg + 1;
                    // led_dht_next[6] = 1;
                end
            end

            HOLD_ON: begin
                next = IDLE;
                sensor_done_next = 0;
            end
        endcase
    end

    baud_tick U_BAUD_TICK (
        .PCLK(PCLK),
        .PRESET(PRESET),
        .clk_1us(clk_1us)
    );
endmodule

module baud_tick (
    input  logic PCLK,
    input  logic PRESET,
    output logic clk_1us
);
    parameter COUNT = 100;
    reg [$clog2(COUNT)-1:0] r_count;

    always @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            r_count <= 0;
            clk_1us <= 0;
        end else begin
            if (r_count == COUNT-1) begin   //COUNT가 99일 때만 tick을 1clk동안 생성
                r_count = 0;
                clk_1us <= 1;
            end else begin  //COUNT <99면 tick을 0으로 유지
                r_count = r_count + 1;
                clk_1us <= 0;
            end
        end
    end
endmodule
