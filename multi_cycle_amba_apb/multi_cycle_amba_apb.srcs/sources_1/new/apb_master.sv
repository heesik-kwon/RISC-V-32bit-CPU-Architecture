`timescale 1ns / 1ps

module APB_Master (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    output logic        PWRITE,
    output logic        PENABLE,
    output logic        PSEL0,
    output logic        PSEL1,
    output logic        PSEL2,
    output logic        PSEL3,
    output logic        PSEL4,
    output logic        PSEL5,
    output logic        PSEL6,
    output logic        PSEL7,
    output logic        PSEL8,
    output logic        PSEL9,
    output logic        PSEL10,
    input  logic [31:0] PRDATA0,
    input  logic [31:0] PRDATA1,
    input  logic [31:0] PRDATA2,
    input  logic [31:0] PRDATA3,
    input  logic [31:0] PRDATA4,
    input  logic [31:0] PRDATA5,
    input  logic [31:0] PRDATA6,
    input  logic [31:0] PRDATA7,
    input  logic [31:0] PRDATA8,
    input  logic [31:0] PRDATA9,
    input  logic [31:0] PRDATA10,
    input  logic        PREADY0,
    input  logic        PREADY1,
    input  logic        PREADY2,
    input  logic        PREADY3,
    input  logic        PREADY4,
    input  logic        PREADY5,
    input  logic        PREADY6,
    input  logic        PREADY7,
    input  logic        PREADY8,
    input  logic        PREADY9,
    input  logic        PREADY10,
    // Internal Interface Signals
    input  logic        transfer,  // trigger signal
    output logic        ready,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        write      // 1:write, 0:read
);
    logic [31:0] temp_addr_next, temp_addr_reg;
    logic [31:0] temp_wdata_next, temp_wdata_reg;
    logic temp_write_next, temp_write_reg;
    logic decoder_en;
    logic [10:0] pselx;


    assign PSEL0  = pselx[0];
    assign PSEL1  = pselx[1];
    assign PSEL2  = pselx[2];
    assign PSEL3  = pselx[3];
    assign PSEL4  = pselx[4];
    assign PSEL5  = pselx[5];
    assign PSEL6  = pselx[6];
    assign PSEL7  = pselx[7];
    assign PSEL8  = pselx[8];
    assign PSEL9  = pselx[9];
    assign PSEL10 = pselx[10];

    typedef enum bit [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e state, state_next;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            state          <= IDLE;
            temp_addr_reg  <= 0;
            temp_wdata_reg <= 0;
            temp_write_reg <= 0;
        end else begin
            state          <= state_next;
            temp_addr_reg  <= temp_addr_next;
            temp_wdata_reg <= temp_wdata_next;
            temp_write_reg <= temp_write_next;
        end
    end


    always_comb begin
        state_next      = state;
        temp_addr_next  = temp_addr_reg;
        temp_wdata_next = temp_wdata_reg;
        temp_write_next = temp_write_reg;
        PADDR           = temp_addr_reg;
        PWDATA          = temp_wdata_reg;
        PWRITE          = 1'b0;
        PENABLE         = 1'b0;
        decoder_en      = 1'b0;
        case (state)
            IDLE: begin
                decoder_en = 1'b0;
                if (transfer) begin
                    state_next      = SETUP;
                    temp_addr_next  = addr;  // latching
                    temp_wdata_next = wdata;
                    temp_write_next = write;
                end
            end
            SETUP: begin
                decoder_en = 1'b1;
                PENABLE    = 1'b0;
                PADDR      = temp_addr_reg;
                if (temp_write_reg) begin
                    PWRITE = 1'b1;
                    PWDATA = temp_wdata_reg;
                end else begin
                    PWRITE = 1'b0;
                end
                state_next = ACCESS;
            end
            ACCESS: begin
                decoder_en = 1'b1;
                PENABLE    = 1'b1;
                PADDR      = temp_addr_reg;
                if (temp_write_reg) begin
                    PWRITE = 1'b1;
                    PWDATA = temp_wdata_reg;
                end else begin
                    PWRITE = 1'b0;
                end
                if (ready) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

    APB_Decoder U_APB_Decoder (
        .en (decoder_en),
        .sel(temp_addr_reg),
        .y  (pselx)
    );

    APB_Mux U_APB_Mux (
        .sel  (temp_addr_reg),
        .d0   (PRDATA0),
        .d1   (PRDATA1),
        .d2   (PRDATA2),
        .d3   (PRDATA3),
        .d4   (PRDATA4),
        .d5   (PRDATA5),
        .d6   (PRDATA6),
        .d7   (PRDATA7),
        .d8   (PRDATA8),
        .d9   (PRDATA9),
        .d10   (PRDATA10),
        .r0   (PREADY0),
        .r1   (PREADY1),
        .r2   (PREADY2),
        .r3   (PREADY3),
        .r4   (PREADY4),
        .r5   (PREADY5),
        .r6   (PREADY6),
        .r7   (PREADY7),
        .r8   (PREADY8),
        .r9   (PREADY9),
        .r10  (PREADY10),
        .rdata(rdata),
        .ready(ready)
    );
endmodule

module APB_Decoder (
    input  logic        en,
    input  logic [31:0] sel,
    output logic [10:0] y
);
    always_comb begin
        y = 11'b000_0000_0000;
        if (en) begin
            casex (sel)
                32'h1000_0xxx: y = 11'b000_0000_0001;  // bit 0
                32'h1000_1xxx: y = 11'b000_0000_0010;  // bit 1
                32'h1000_2xxx: y = 11'b000_0000_0100;  // bit 2
                32'h1000_3xxx: y = 11'b000_0000_1000;  // bit 3
                32'h1000_4xxx: y = 11'b000_0001_0000;  // bit 4
                32'h1000_5xxx: y = 11'b000_0010_0000;  // bit 5
                32'h1000_6xxx: y = 11'b000_0100_0000;  // bit 6
                32'h1000_7xxx: y = 11'b000_1000_0000;  // bit 7
                32'h1000_8xxx: y = 11'b001_0000_0000;  // bit 8
                32'h1000_9xxx: y = 11'b010_0000_0000;  // bit 9
                32'h1000_Axxx: y = 11'b100_0000_0000;  // bit 10
                // 확장 시 계속 패턴 유지 가능
            endcase
        end
    end
endmodule



module APB_Mux (
    input  logic [31:0] sel,
    input  logic [31:0] d0,
    input  logic [31:0] d1,
    input  logic [31:0] d2,
    input  logic [31:0] d3,
    input  logic [31:0] d4,
    input  logic [31:0] d5,
    input  logic [31:0] d6,
    input  logic [31:0] d7,
    input  logic [31:0] d8,
    input  logic [31:0] d9,
    input  logic [31:0] d10,
    input  logic        r0,
    input  logic        r1,
    input  logic        r2,
    input  logic        r3,
    input  logic        r4,
    input  logic        r5,
    input  logic        r6,
    input  logic        r7,
    input  logic        r8,
    input  logic        r9,
    input  logic        r10,
    output logic [31:0] rdata,
    output logic        ready
);

    always_comb begin
        rdata = 32'b0;
        casex (sel)
            32'h1000_0xxx: rdata = d0;
            32'h1000_1xxx: rdata = d1;
            32'h1000_2xxx: rdata = d2;
            32'h1000_3xxx: rdata = d3;
            32'h1000_4xxx: rdata = d4;
            32'h1000_5xxx: rdata = d5;
            32'h1000_6xxx: rdata = d6;
            32'h1000_7xxx: rdata = d7;
            32'h1000_8xxx: rdata = d8;
            32'h1000_9xxx: rdata = d9;
            32'h1000_Axxx: rdata = d10;
        endcase
    end

    always_comb begin
        ready = 1'b0;
        casex (sel)
            32'h1000_0xxx: ready = r0;
            32'h1000_1xxx: ready = r1;
            32'h1000_2xxx: ready = r2;
            32'h1000_3xxx: ready = r3;
            32'h1000_4xxx: ready = r4;
            32'h1000_5xxx: ready = r5;
            32'h1000_6xxx: ready = r6;
            32'h1000_7xxx: ready = r7;
            32'h1000_8xxx: ready = r8;
            32'h1000_9xxx: ready = r9;
            32'h1000_Axxx: ready = r10;
        endcase
    end
endmodule
