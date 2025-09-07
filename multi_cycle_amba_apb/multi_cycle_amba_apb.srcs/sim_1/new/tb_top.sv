`timescale 1ns / 1ps

module tb_top ();

    logic clk, reset;

    MCU DUT (
        .clk  (clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        #10 reset = 0;

        #200 $finish;
    end

endmodule
