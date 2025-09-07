// Ultrasound Testbench - Full Verification Environment (With Phase-tagged display)
`timescale 1ns / 1ps

interface APB_us_Controller;
    logic        PCLK;
    logic        PRESET;
    logic [ 3:0] PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        trigger;
    logic        echo;
endinterface

class transaction_apb;
    rand logic [ 3:0] PADDR;
    rand logic        PWRITE;
    rand logic [31:0] PWDATA;
    logic      [31:0] PRDATA;
    logic             PSEL;
    logic             PENABLE;
    logic             PREADY;

    constraint c_addr_dist {
        PADDR dist {
            4'h0 := 60,  // UCR : 60%
            4'h4 := 20,  // USR : 20%
            4'h8 := 20  // UDR : 20%
        };
    }

    constraint c_pwd {
        if (PADDR == 4'h0)
        PWDATA dist {
            32'd0 := 10,
            32'd1 := 90
        };  // UCR : wdata=1 80%, wdata=0 20%
        else
        PWDATA == 32'hFFFF_FFFF;
    }

    constraint c_pwrite {
        if (PADDR == 4'h0)
        PWRITE dist {
            1 := 90,
            0 := 10
        };  // UCR : write 90%, read 10%
        else
        if (PADDR == 4'h4)
        PWRITE dist {
            0 := 90,
            1 := 10
        };  // USR : read 90%, write 10%
        else
        if (PADDR == 4'h8)
        PWRITE dist {
            0 := 90,
            1 := 10
        };  // UDR : read 90%, write 10%
    }

    task display(string tag);
        $display(
            "[%s] PADDR=0x%0h PWRITE=%0b PWDATA=0x%08h PRDATA=0x%08h PSEL=%0b PENABLE=%0b PREADY=%0b",
            tag, PADDR, PWRITE, PWDATA, PRDATA, PSEL, PENABLE, PREADY);
    endtask

endclass

class transaction_echo;
    // 랜덤 변수
    rand int echo_delay_us;
    rand int echo_width_us;
    rand bit expect_timeout;
    rand int timeout_type;  // 0: delay timeout, 1: width timeout

    // 결과 저장용 변수
    int expect_distance;

    // timeout 발생 여부 (전체 20%)
    constraint timeout_weighted {
        expect_timeout dist {
            0 := 80,  // 정상 echo
            1 := 20  // timeout 발생
        };
    }

    // timeout 종류 선택 (delay vs width, 각각 50%씩)
    constraint timeout_type_select {
        if (expect_timeout)
        timeout_type dist {
            0 := 50,  // delay timeout
            1 := 50  // width timeout
        };
        else
        timeout_type == -1;  // 비활성화
    }

    // delay/width 값 제약 (timeout 또는 정상일 경우 각각 다름)
    constraint timeout_logic {
        if (expect_timeout) {
            if (timeout_type == 0) {  // delay timeout (echo 지연 너무 김)
                echo_delay_us inside {[6000 : 8000]};
                echo_width_us inside {[100 : 10000]};
            } else
            if (timeout_type == 1) {  // width timeout (echo 폭 너무 김)
                echo_delay_us inside {[100 : 500]};
                echo_width_us inside {[26000 : 28000]};
            }
        } else {
            echo_delay_us inside {[100 : 500]};
            echo_width_us inside {[100 : 10000]};
        }
    }

    // 거리 계산 (정상 echo일 경우만)
    function void post_randomize();
        if (expect_timeout) expect_distance = 0;
        else expect_distance = echo_width_us / 58;
    endfunction

    // 출력용
    task display();
        $display(
            "[ECHO] delay=%0d us, width=%0d us, timeout=%0d (type=%s), expect_dist=%0d cm",
            echo_delay_us, echo_width_us, expect_timeout,
            (timeout_type == 0) ? "delay" : (timeout_type == 1) ? "width" : "N/A",
            expect_distance);
    endtask
endclass

class generator;
    mailbox #(transaction_apb) Gen2Drv_apb_mbox;
    mailbox #(transaction_echo) Gen2Drv_echo_mbox;
    event gen_next_event;

    // logic [$clog2(1000)-1:0] timeout_test;

    function new(mailbox#(transaction_apb) Gen2Drv_apb_mbox,
                 mailbox#(transaction_echo) Gen2Drv_echo_mbox,
                 event gen_next_event);
        this.Gen2Drv_apb_mbox = Gen2Drv_apb_mbox;
        this.Gen2Drv_echo_mbox = Gen2Drv_echo_mbox;
        this.gen_next_event = gen_next_event;
        // timeout_test = 0;
    endfunction

    task run(int count);
        transaction_apb  apb_tr;
        transaction_echo echo_tr;


        repeat (count) begin
            apb_tr  = new();
            echo_tr = new();

            if (!apb_tr.randomize()) $error("APB tr Randomization failed!");

            if (apb_tr.PADDR == 4'h0 && apb_tr.PWRITE == 1 && apb_tr.PWDATA == 32'd1) begin
                echo_tr = new();
                if (!echo_tr.randomize())
                    $error("ECHO tr Randomization failed!");
                echo_tr.post_randomize();
                // echo_tr.display();
                Gen2Drv_echo_mbox.put(echo_tr);
            end

            apb_tr.display("GEN");
            // echo_tr.post_randomize();

            Gen2Drv_apb_mbox.put(apb_tr);
            // Gen2Drv_echo_mbox.put(echo_tr);
            // if (echo_tr.expect_timeout) begin
            //     timeout_test = timeout_test+1;
            // end
            @(gen_next_event);
        end
    endtask
endclass

class driver;
    virtual APB_us_Controller us_intf;

    mailbox #(transaction_apb) Gen2Drv_apb_mbox;
    mailbox #(transaction_echo) Gen2Drv_echo_mbox;

    mailbox #(transaction_echo) Drv2Scb_echo_mbox;
    event gen_next_event;

    transaction_apb apb_tr;
    transaction_echo echo_tr;

    function new(mailbox#(transaction_apb) Gen2Drv_apb_mbox,
                 mailbox#(transaction_echo) Gen2Drv_echo_mbox,
                 mailbox#(transaction_echo) Drv2Scb_echo_mbox,
                 virtual APB_us_Controller us_intf, event gen_next_event);
        this.Gen2Drv_apb_mbox = Gen2Drv_apb_mbox;
        this.Gen2Drv_echo_mbox = Gen2Drv_echo_mbox;
        this.Drv2Scb_echo_mbox = Drv2Scb_echo_mbox;
        this.gen_next_event = gen_next_event;
        this.us_intf = us_intf;
    endfunction

    task drive_echo_pulse(time delay_us, time width_us);
        #(delay_us * 1000);
        us_intf.echo <= 1;
        #(width_us * 1000);
        us_intf.echo <= 0;
    endtask

    task run();
        forever begin
            Gen2Drv_apb_mbox.get(apb_tr);
            apb_tr.display("DRV");

            @(posedge us_intf.PCLK);
            us_intf.PADDR   <= apb_tr.PADDR;
            us_intf.PWDATA  <= apb_tr.PWDATA;
            us_intf.PWRITE  <= apb_tr.PWRITE;
            us_intf.PSEL    <= 1;
            us_intf.PENABLE <= 0;

            @(posedge us_intf.PCLK);
            us_intf.PENABLE <= 1;

            wait (us_intf.PREADY);
            @(posedge us_intf.PCLK);
            us_intf.PSEL    <= 0;
            us_intf.PENABLE <= 0;
            @(posedge us_intf.PCLK);
            @(posedge us_intf.PCLK);

            if (apb_tr.PADDR == 4'h0 && apb_tr.PWRITE && apb_tr.PWDATA == 1) begin
                Gen2Drv_echo_mbox.get(echo_tr);
                Drv2Scb_echo_mbox.put(echo_tr);
                @(negedge us_intf.trigger);
                drive_echo_pulse(echo_tr.echo_delay_us, echo_tr.echo_width_us);

                @(posedge us_intf.PCLK);
                us_intf.PADDR   <= apb_tr.PADDR;
                us_intf.PWDATA  <= 0;
                us_intf.PWRITE  <= apb_tr.PWRITE;
                us_intf.PSEL    <= 1;
                us_intf.PENABLE <= 0;

                @(posedge us_intf.PCLK);
                us_intf.PENABLE <= 1;

                wait (us_intf.PREADY);
                @(posedge us_intf.PCLK);
                us_intf.PSEL    <= 0;
                us_intf.PENABLE <= 0;
                @(posedge us_intf.PCLK);
                @(posedge us_intf.PCLK);
            end

            // @(posedge us_intf.PCLK);
            // @(posedge us_intf.PCLK);
            // ->gen_next_event;
        end
    endtask
endclass

class monitor;
    virtual APB_us_Controller  us_intf;
    mailbox #(transaction_apb) Mon2Scb_apb_mbox;


    function new(mailbox#(transaction_apb) Mon2Scb_apb_mbox,
                 virtual APB_us_Controller us_intf);
        this.Mon2Scb_apb_mbox = Mon2Scb_apb_mbox;
        this.us_intf = us_intf;
    endfunction

    task run();
        transaction_apb apb_tr;
        forever begin
            apb_tr = new();
            @(posedge us_intf.PREADY);
            #1;
            apb_tr.PADDR = us_intf.PADDR;
            apb_tr.PRDATA = us_intf.PRDATA;
            apb_tr.PWRITE = us_intf.PWRITE;
            apb_tr.PWDATA = us_intf.PWDATA;
            apb_tr.PSEL = us_intf.PSEL;
            apb_tr.PENABLE = us_intf.PENABLE;
            apb_tr.PREADY = us_intf.PREADY;
            Mon2Scb_apb_mbox.put(apb_tr);
            apb_tr.display("MON");

            @(posedge us_intf.PCLK);
            @(posedge us_intf.PCLK);
            @(posedge us_intf.PCLK);
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction_apb) Mon2Scb_apb_mbox;
    mailbox #(transaction_echo) Drv2Scb_echo_mbox;
    event gen_next_event;

    logic [$clog2(10000)-1:0] write_test;
    logic [$clog2(10000)-1:0] read_test;
    logic [$clog2(10000)-1:0] pass_test;
    logic [$clog2(10000)-1:0] fail_test;
    logic [$clog2(10000)-1:0] total_test;

    logic [$clog2(10000)-1:0] timeout_test;
    logic [$clog2(10000)-1:0] usr_read_test;
    logic [$clog2(10000)-1:0] udr_read_test;
    logic [$clog2(10000)-1:0] ucr_write_test;
    logic [$clog2(10000)-1:0] ucr_notrig_test;

    logic [$clog2(10000)-1:0] ucr_read_test;
    logic [$clog2(10000)-1:0] usr_write_test;
    logic [$clog2(10000)-1:0] udr_write_test;
    logic [$clog2(10000)-1:0] nodata_read_test;


    function new(mailbox#(transaction_apb) Mon2Scb_apb_mbox,
                 mailbox#(transaction_echo) Drv2Scb_echo_mbox,
                 event gen_next_event);
        this.Mon2Scb_apb_mbox = Mon2Scb_apb_mbox;
        this.Drv2Scb_echo_mbox = Drv2Scb_echo_mbox;
        this.gen_next_event = gen_next_event;
        write_test = 0;
        ucr_write_test = 0;
        read_test = 0;
        pass_test = 0;
        fail_test = 0;
        total_test = 0;
        usr_read_test = 0;
        udr_read_test = 0;
        timeout_test = 0;
        ucr_notrig_test = 0;
        ucr_read_test = 0;
        usr_write_test = 0;
        udr_write_test = 0;
        nodata_read_test = 0;
    endfunction

    task run();
        transaction_apb apb_tr;
        transaction_echo echo_tr;
        bit echo_valid = 0;
        bit echo_happened = 0;

        forever begin
            Mon2Scb_apb_mbox.get(apb_tr);
            apb_tr.display("SCB");
            total_test = total_test + 1;

            // paddr ==0 일떄 (UCR)
            if (apb_tr.PENABLE == 1 && apb_tr.PADDR == 4'h0) begin
                if (apb_tr.PWRITE && apb_tr.PWDATA == 1) begin
                    write_test = write_test + 1;
                    ucr_write_test = ucr_write_test + 1;
                    pass_test = pass_test + 1;
                    Drv2Scb_echo_mbox.get(
                        echo_tr);  // write 시점에 echo_tr 기억
                    echo_valid = 1;
                    echo_happened = 1;

                end else if (apb_tr.PWRITE && apb_tr.PWDATA == 0) begin
                    if (echo_happened) begin
                        $display(
                            "(PASS) trigger O : echo_delay_us=%0d echo_width_us=%0d expect_timeout=%0d expected_dist=%0d"
                            , echo_tr.echo_delay_us, echo_tr.echo_width_us,
                            echo_tr.expect_timeout, echo_tr.expect_distance);
                        total_test = total_test - 1;
                        echo_happened = 0;
                        if (echo_tr.expect_timeout) begin
                            timeout_test = timeout_test + 1;
                        end
                        ->gen_next_event;
                    end else begin
                        write_test = write_test + 1;
                        ucr_notrig_test = ucr_notrig_test + 1;
                        // ucr_write_test = ucr_write_test+1;
                        pass_test = pass_test + 1;
                        $display(
                            "(PASS) trigger X : You write '0' at UCR. Ther is no action");
                        ->gen_next_event;
                    end

                end else if (!apb_tr.PWRITE) begin
                    read_test = read_test + 1;
                    ucr_read_test = ucr_read_test + 1;
                    $display(
                        "(PASS) trigger X : UCR is only writeable. There is no action");
                    ->gen_next_event;
                end

            end

            // paddr == 4 or 8 (USR, UDR)
            if (apb_tr.PENABLE == 1 && (apb_tr.PADDR == 4'h4 || apb_tr.PADDR == 4'h8)) begin
                if (echo_valid) begin
                    // echo_tr가 있는 경우만 비교 수행
                    case (apb_tr.PADDR)
                        4'h4: begin
                            if (!apb_tr.PWRITE) begin
                                read_test = read_test + 1;
                                usr_read_test = usr_read_test + 1;
                                if (echo_tr.expect_timeout == apb_tr.PRDATA[0]) begin
                                    pass_test = pass_test + 1;
                                    $display(
                                        "(PASS) Timeout match (expected=%0d, actual=%0d)",
                                        echo_tr.expect_timeout,
                                        apb_tr.PRDATA[0]);
                                    ->gen_next_event;
                                end else begin
                                    fail_test = fail_test + 1;
                                    $display(
                                        "(FAIL) Timeout mismatch! expected=%0d, actual=%0d",
                                        echo_tr.expect_timeout,
                                        apb_tr.PRDATA[0]);
                                    ->gen_next_event;
                                end
                            end else if (apb_tr.PWRITE) begin
                                write_test = write_test + 1;
                                usr_write_test = usr_write_test + 1;
                                $display(
                                    "USR is only readalbe. There is no action");
                                ->gen_next_event;
                            end

                        end

                        4'h8: begin
                            if (!apb_tr.PWRITE) begin
                                if (echo_tr.expect_timeout) begin
                                    read_test = read_test + 1;
                                    udr_read_test = udr_read_test + 1;
                                    if (echo_tr.expect_distance == apb_tr.PRDATA) begin
                                        pass_test = pass_test + 1;
                                        $display(
                                            "(PASS) timeout happend, distance is 0 expect_dist= %0d , acutual_dist = %0d",
                                            echo_tr.expect_distance,
                                            apb_tr.PRDATA);
                                        ->gen_next_event;
                                    end else begin
                                        fail_test = fail_test + 1;
                                        $display(
                                            "(FAIL) timeout happend, distance is not 0 expect_dist= %0d , acutual_dist = %0d",
                                            echo_tr.expect_distance,
                                            apb_tr.PRDATA);
                                        ->gen_next_event;
                                    end
                                end else if (apb_tr.PRDATA == echo_tr.expect_distance) begin
                                    read_test = read_test + 1;
                                    pass_test = pass_test + 1;
                                    udr_read_test = udr_read_test + 1;
                                    $display(
                                        "(PASS) Distance match: expected dist:%0d , actual dist: %0d",
                                        echo_tr.expect_distance, apb_tr.PRDATA);
                                    ->gen_next_event;
                                end else begin
                                    read_test = read_test + 1;
                                    fail_test = fail_test + 1;
                                    udr_read_test = udr_read_test + 1;
                                    $display(
                                        "(FAIL) Distance mismatch: expected %0d, got %0d",
                                        echo_tr.expect_distance, apb_tr.PRDATA);
                                    ->gen_next_event;
                                end
                            end else if (apb_tr.PWRITE) begin
                                write_test = write_test + 1;
                                udr_write_test = udr_write_test + 1;
                                $display(
                                    "UDR is only readable. There is no action");
                                ->gen_next_event;
                            end
                        end
                    endcase
                end else begin
                    if (apb_tr.PWRITE) begin
                        write_test = write_test + 1;
                        // pass_test = pass_test +1;
                        if (apb_tr.PADDR == 4'h4) begin
                            usr_write_test = usr_write_test + 1;
                        end else begin
                            udr_write_test = udr_write_test + 1;
                        end
                        $display(
                            "(PASS) Trigger not happend. There is no Ultrasound measure data. Also USR/UDR is only readble");
                        ->gen_next_event;
                    end else begin
                        read_test = read_test + 1;
                        pass_test = pass_test + 1;
                        nodata_read_test = nodata_read_test + 1;
                        $display(
                            "(PASS) Trigger not happend. There is no Ultrasound measure data");
                        ->gen_next_event;
                    end
                end

                // ->gen_next_event; 
            end
        end
    endtask
endclass

class environment;
    mailbox #(transaction_apb)  Gen2Drv_apb_mbox;
    mailbox #(transaction_echo) Gen2Drv_echo_mbox;
    mailbox #(transaction_apb)  Mon2Scb_apb_mbox;
    mailbox #(transaction_echo) Drv2Scb_echo_mbox;
    event                       gen_next_event;
    virtual APB_us_Controller   us_intf;

    generator                   us_gen;
    driver                      us_drv;
    monitor                     us_mon;
    scoreboard                  us_scb;

    function new(virtual APB_us_Controller us_intf);
        this.us_intf = us_intf;
        Gen2Drv_apb_mbox = new();
        Gen2Drv_echo_mbox = new();
        Mon2Scb_apb_mbox = new();
        Drv2Scb_echo_mbox = new();
        us_gen = new(Gen2Drv_apb_mbox, Gen2Drv_echo_mbox, gen_next_event);
        us_drv = new(
            Gen2Drv_apb_mbox,
            Gen2Drv_echo_mbox,
            Drv2Scb_echo_mbox,
            us_intf,
            gen_next_event
        );
        us_mon = new(Mon2Scb_apb_mbox, us_intf);
        us_scb = new(Mon2Scb_apb_mbox, Drv2Scb_echo_mbox, gen_next_event);
    endfunction

    task run(int count);
        fork
            us_gen.run(count);
            us_drv.run();
            us_mon.run();
            us_scb.run();
        join_any
    endtask


    task report();
        $display("========================================");
        $display("==           Final Report            ==");
        $display("========================================");

        $display(
            "---------Valid Access Test-----------: %0d",
            us_scb.ucr_notrig_test + us_scb.ucr_write_test + us_scb.usr_read_test + us_scb.udr_read_test + us_scb.nodata_read_test);
        $display("1. Write Test (UCR Trigger)          : %0d",
                 us_scb.ucr_write_test + us_scb.ucr_notrig_test);
        $display(" 1-1. Timeout case                   : %0d",
                 us_scb.timeout_test);
        $display(" 1-2. Normal case                    : %0d",
                 us_scb.ucr_write_test - us_scb.timeout_test);
        $display(" 1-3. No Trigger case                : %0d",
                 us_scb.ucr_notrig_test);
        $display(
            "2. Read Test (USR + UDR)             : %0d",
            us_scb.usr_read_test + us_scb.udr_read_test + us_scb.nodata_read_test);
        $display(" 2-1. USR (Status) Read              : %0d",
                 us_scb.usr_read_test);
        $display(" 2-2. UDR (Distance) Read            : %0d",
                 us_scb.udr_read_test);
        $display(" 2-3. No measure data                : %0d",
                 us_scb.nodata_read_test);
        $display("3. PASS  Test                        : %0d",
                 us_scb.pass_test);
        $display("4. FAIL  Test                        : %0d",
                 us_scb.fail_test);
        $display("");
        $display(
            "--------Invalid Access Test----------: %0d",
            us_scb.ucr_read_test + us_scb.usr_write_test + us_scb.udr_write_test);
        $display("5. UCR Read (Invalid)                : %0d",
                 us_scb.ucr_read_test);
        $display("6. USR Write (Invalid)               : %0d",
                 us_scb.usr_write_test);
        $display("7. UDR Write (Invalid)               : %0d",
                 us_scb.udr_write_test);
        $display("");
        $display("8. Total Test                        : %0d",
                 us_scb.total_test);
        $display("========================================");
        $display("==      test bench is finished!      ==");
        $display("========================================");
    endtask

endclass

module tb_US_SystemVerilog;
    APB_us_Controller us_intf ();
    environment us_env;

    always #5 us_intf.PCLK = ~us_intf.PCLK;

    initial begin
        us_intf.PCLK   = 0;
        us_intf.echo   = 0;
        us_intf.PRESET = 1;
        #10 us_intf.PRESET = 0;

        us_env = new(us_intf);
        us_env.run(100);
        #10 $display("finish!");
        us_env.report();
        $finish;
    end

    Ultrasound_Peripheral DUT (
        .PCLK   (us_intf.PCLK),
        .PRESET (us_intf.PRESET),
        .PADDR  (us_intf.PADDR),
        .PWDATA (us_intf.PWDATA),
        .PWRITE (us_intf.PWRITE),
        .PENABLE(us_intf.PENABLE),
        .PSEL   (us_intf.PSEL),
        .PRDATA (us_intf.PRDATA),
        .PREADY (us_intf.PREADY),
        .trigger(us_intf.trigger),
        .echo   (us_intf.echo)
    );
endmodule
