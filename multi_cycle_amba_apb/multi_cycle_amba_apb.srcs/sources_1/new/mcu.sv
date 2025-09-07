`timescale 1ns / 1ps

module MCU (
    input  logic       clk,
    input  logic       reset,
    output logic [7:0] GPOA,
    input  logic [7:0] GPIB,
    inout  logic [7:0] GPIOC,
    inout  logic [7:0] GPIOD,
    output logic [3:0] FND_comm,
    output logic [7:0] FND_font,
    input  logic       rx,
    output logic       tx,
    input  logic       echo,
    output logic       trigger,
    inout              dht_io
);

    // global signals
    logic        PCLK;
    logic        PRESET;
    // APB Interface Signals
    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic        PWRITE;
    logic        PENABLE;
    logic        PSEL_RAM;
    logic        PSEL_GPOA;
    logic        PSEL_GPIB;
    logic        PSEL_GPIOC;
    logic        PSEL_GPIOD;
    logic        PSEL_FND;
    logic        PSEL_UART;
    logic        PSEL_TIMER;
    logic        PSEL_US;
    logic        PSEL_DHT;
    logic [31:0] PRDATA_RAM;
    logic [31:0] PRDATA_GPOA;
    logic [31:0] PRDATA_GPIB;
    logic [31:0] PRDATA_GPIOC;
    logic [31:0] PRDATA_GPIOD;
    logic [31:0] PRDATA_FND;
    logic [31:0] PRDATA_UART;
    logic [31:0] PRDATA_TIMER;
    logic [31:0] PRDATA_US;
    logic [31:0] PRDATA_DHT;
    logic        PREADY_RAM;
    logic        PREADY_GPOA;
    logic        PREADY_GPIB;
    logic        PREADY_GPIOC;
    logic        PREADY_GPIOD;
    logic        PREADY_FND;
    logic        PREADY_UART;
    logic        PREADY_TIMER;
    logic        PREADY_US;
    logic        PREADY_DHT;

    // CPU - APB_Master Signals
    logic        transfer;
    logic        ready;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        write;
    logic        dataWe;
    logic [31:0] dataAddr;
    logic [31:0] dataWData;
    logic [31:0] dataRData;

    // ROM Signals
    logic [31:0] instrCode;
    logic [31:0] instrMemAddr;

    assign PCLK = clk;
    assign PRESET = reset;
    assign addr = dataAddr;
    assign wdata = dataWData;
    assign dataRData = rdata;
    assign write = dataWe;

    rom U_ROM (
        .addr(instrMemAddr),
        .data(instrCode)
    );

    RV32I_Core U_Core (.*);

    APB_Master U_APB_Master (
        .*,
        .PSEL0(PSEL_RAM),
        .PSEL1(PSEL_GPOA),
        .PSEL2(PSEL_GPIB),
        .PSEL3(PSEL_GPIOC),
        .PSEL4(PSEL_GPIOD),
        .PSEL5(PSEL_FND),
        .PSEL6(PSEL_UART),
        .PSEL7(PSEL_TIMER),
        .PSEL8(PSEL_US),
        .PSEL9(PSEL_DHT),
        .PSEL10(),
        .PRDATA0(PRDATA_RAM),
        .PRDATA1(PRDATA_GPOA),
        .PRDATA2(PRDATA_GPIB),
        .PRDATA3(PRDATA_GPIOC),
        .PRDATA4(PRDATA_GPIOD),
        .PRDATA5(PRDATA_FND),
        .PRDATA6(PRDATA_UART),
        .PRDATA7(PRDATA_TIMER),
        .PRDATA8(PRDATA_US),
        .PRDATA9(PRDATA_DHT),
        .PRDATA10(),
        .PREADY0(PREADY_RAM),
        .PREADY1(PREADY_GPOA),
        .PREADY2(PREADY_GPIB),
        .PREADY3(PREADY_GPIOC),
        .PREADY4(PREADY_GPIOD),
        .PREADY5(PREADY_FND),
        .PREADY6(PREADY_UART),
        .PREADY7(PREADY_TIMER),
        .PREADY8(PREADY_US),
        .PREADY9(PREADY_DHT),
        .PREADY10()
    );

    ram U_RAM (
        .*,
        .PSEL  (PSEL_RAM),
        .PRDATA(PRDATA_RAM),
        .PREADY(PREADY_RAM)
    );

    GPO_Periph U_GPOA (
        .*,
        .PSEL   (PSEL_GPOA),
        .PRDATA (PRDATA_GPOA),
        .PREADY (PREADY_GPOA),
        .outPort(GPOA)
    );

    GPI_Periph U_GPIB (
        .*,
        .PSEL  (PSEL_GPIB),
        .PRDATA(PRDATA_GPIB),
        .PREADY(PREADY_GPIB),
        .inPort(GPIB)
    );

    GPIO_Periph U_GPIOC (
        .*,
        .PSEL  (PSEL_GPIOC),
        .PRDATA(PRDATA_GPIOC),
        .PREADY(PREADY_GPIOC),
        .GPIO  (GPIOC)
    );

    GPIO_Periph U_GPIOD (
        .*,
        .PSEL  (PSEL_GPIOD),
        .PRDATA(PRDATA_GPIOD),
        .PREADY(PREADY_GPIOD),
        .GPIO  (GPIOD)
    );

    FND_Periph u_FND_Periph (
        .*,
        .PSEL  (PSEL_FND),
        .PRDATA(PRDATA_FND),
        .PREADY(PREADY_FND)
    );


    uart_Periph u_UART_FIFO_Periph (
        .*,
        .PSEL  (PSEL_UART),
        .PRDATA(PRDATA_UART),
        .PREADY(PREADY_UART)
    );

    timer_periph u_timer_periph (
        .*,
        .PSEL  (PSEL_TIMER),
        .PRDATA(PRDATA_TIMER),
        .PREADY(PREADY_TIMER)
    );

    Ultrasound_Peripheral u_Ultrasound_Periph (
        .*,
        .PSEL  (PSEL_US),
        .PRDATA(PRDATA_US),
        .PREADY(PREADY_US)

    );

    DHT11_Controller_Periph u_DHT11_Controller_Periph (
        .*,
        .PSEL  (PSEL_DHT),
        .PRDATA(PRDATA_DHT),
        .PREADY(PREADY_DHT)
    );
endmodule
