`timescale 1ns/1ps

module ltc2387_tb;

    // Parameters
    parameter ADC_WIDTH = 18;
    parameter SYS_CLK_FREQ = 200_000_000;
    parameter T_FIRSTCLK = (65 * SYS_CLK_FREQ) / 1_000_000_000;

    // Clock and reset
    reg sys_clk_int;
    reg reset_int;
    reg data_clk_int;

    // ADC interface signals
    wire dco;
    wire da;
    wire db;
    wire cnv;
    wire clk;
    wire tl;

    // FPGA interface signals
    wire [17:0] adc_data_out;
    wire adc_data_valid;
    reg trig_int;



    // Instantiate the DUT (Device Under Test)
    ltc2387_interface #(
        .ADC_WIDTH(ADC_WIDTH),
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .T_FIRSTCLK(T_FIRSTCLK)
    ) dut (
        .dco(dco),
        .da(da),
        .db(db),
        .cnv(cnv),
        .clk(clk),
        .tl(tl),
        .adc_data_out(adc_data_out),
        .adc_data_valid(adc_data_valid),
        .trig_int(trig_int),
        .reset_int(reset_int),
        .sys_clk_int(sys_clk_int),
        .data_clk_int(data_clk_int)
    );

    // Instantiate the virtual ADC
    virtual_adc #(
        .ADC_WIDTH(ADC_WIDTH),
        .NUM_SAMPLES(2) // Example: Use 2 samples for testing
    ) virtual_adc_inst (
        .clk(clk),
        .reset(reset_int),
        .cnv(cnv),
        .dco(dco),
        .da(da),
        .db(db),
        .fast_clk(sys_clk_int) // Use sys_clk_int as the fast clock
    );

    // Clock generation
    initial begin
        sys_clk_int = 0;
        forever #0.3 sys_clk_int = ~sys_clk_int;
    end

    initial begin
        data_clk_int = 0;
        forever #12 data_clk_int = ~data_clk_int;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        reset_int = 1;
        trig_int = 0;

        // Apply reset
        #20 reset_int = 0;

        // Start a conversion
        #10 trig_int = 1;
        #10 trig_int = 0;

        // Wait for data to be valid
        @(posedge adc_data_valid);
        $display("ADC Data Out: %h", adc_data_out);

        // End simulation
        #100 $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time: %0t | State: %b | CNV: %b | ADC Data Valid: %b | ADC Data Out: %h",
                 $time, dut.state, cnv, adc_data_valid, adc_data_out);
    end

endmodule