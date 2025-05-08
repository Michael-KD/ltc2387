module ltc2387_18_interface #(
    // Parameters 
    parameter ADC_WIDTH = 18 /*bits*/ )(

    // ADC interface
    input  wire        dco,             // Data Clock Out (single-ended)
    input  wire        da,           // Data Lane 1 (single-ended, odd bits)
    input  wire        db,           // Data Lane 2 (single-ended, even bits)
    output  wire       cnv,             // Conversion start signal to adc
    output wire        clk,     // clock output to adc
    output wire        tl,          // two lane, ouput to adc carrier

    // FPGA interface
    output wire [17:0] adc_data_out,    // Reconstructed 18-bit ADC output
    output wire        adc_data_valid,  // High when new data is valid
    input wire         trig_int,        // signal from fpga to start conversion
    input  wire        reset_int,           // Active-high reset
    input wire        sys_clk_int // System clock (FPGA clock domain)
);







endmodule