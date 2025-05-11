module ltc2387_interface #(
    // Parameters 
    parameter ADC_WIDTH = 18,
    parameter SYS_CLK_FREQ = 200_000_000,
    parameter T_FIRSTCLK = (65 * SYS_CLK_FREQ) / 1_000_000_000 // First clock high time in ns  
)(

    // ADC interface
    input  wire        dco,             // Data Clock Out (single-ended)
    input  wire        da,              // Data Lane 1 (single-ended, odd bits)
    input  wire        db,              // Data Lane 2 (single-ended, even bits)
    output reg        cnv,             // Conversion start signal to adc
    output wire        clk,             // Clock output to ADC (ADC clock domain)
    output wire        tl,              // Two-lane mode signal to ADC

    // FPGA interface
    output reg [17:0] adc_data_out,    // Reconstructed 18-bit ADC output
    output reg        adc_data_valid,  // High when new data is valid
    input  wire        trig_int,        // Signal from FPGA to start conversion
    input  wire        reset_int,       // Active-high reset
    input  wire        sys_clk_int,     // System clock (FPGA clock domain, 200MHz)
    input  wire        data_clk_int     // Data clock (ADC clock domain)       


);


    // FSM states
    localparam IDLE       = 2'b00;
    localparam WAIT_LAT   = 2'b01;
    localparam CAPTURE    = 2'b10;
    

    reg [1:0] state = IDLE;
    assign state_out = state; // Output the current state for debugging


    // Shift registers for capturing data
    reg [ADC_WIDTH/2-1:0] shift_lane_a = 0; // Odd bits (da)
    reg [ADC_WIDTH/2-1:0] shift_lane_b = 0; // Even bits (db)

    // Constant signals
    assign tl = 1'b1; 

    // Clock stuff
    reg clk_en = 0;
    assign clk = clk_en & data_clk_int; // ** want to start with slow and then try faster, use FPGA pll tools to set this


    // Counters
    reg [4:0] bit_cnt = 0;     // Bit counter for 9 bits per lane
    reg [2:0] lat_cnt = 0;     // Latency counter for conversion delay


    assign bit_cnt_out = bit_cnt; // Output the current bit count for debugging

    // FSM, IDLE -> WAIT_LAT -> CAPTURE -> IDLE
    always @(posedge sys_clk_int or posedge reset_int) begin
        if (reset_int) begin
            state <= IDLE;
            cnv <= 0;
            adc_data_valid <= 0;
            bit_cnt <= 0;
            lat_cnt <= 0;
            shift_lane_a <= 0;
            shift_lane_b <= 0;
            adc_data_out <= 0;
            clk_en <= 0;

        end else begin
            case (state)
                IDLE: begin
                    clk_en <= 0; 


                    if (trig_int) begin
                        adc_data_valid <= 0;
                        bit_cnt <= 0;
                        adc_data_out <= 0;
                        shift_lane_a <= 0;
                        shift_lane_b <= 0;

                        cnv <= 1; // Start conversion
                        state <= WAIT_LAT;
                        lat_cnt <= 0;
                    end
                end

                WAIT_LAT: begin
                    cnv <= 0;
                    lat_cnt <= lat_cnt + 1;
                    if (lat_cnt == T_FIRSTCLK) begin // Wait for ADC latency
                        state <= CAPTURE;
                        clk_en <= 1; // Enable clock for data capture
                        bit_cnt <= 2;
                        
                        shift_lane_a[7] <= da; // Capture first bit
                        shift_lane_b[7] <= db; // Capture first bit
                    end
                end

                CAPTURE: begin
                    if (bit_cnt >= 18) begin
                        adc_data_out <= reconstruct_data(shift_lane_a, shift_lane_b);   // Reconstruct data
                        adc_data_valid <= 1;
                        // state <= IDLE;
                        state <= STOP; // Stop after 1 conversion for testing
                    end else begin
                        adc_data_valid <= 0;
                    end
                end

            endcase
        end
    end



    // positive and negative edge of dco
    always @(posedge dco or negedge dco or posedge reset_int) begin
        if (reset_int) begin
            shift_lane_a <= 0;
        end else if (state == CAPTURE) begin
            shift_lane_a <= {shift_lane_a[ADC_WIDTH/2-2:0], da};
            shift_lane_b <= {shift_lane_b[ADC_WIDTH/2-2:0], db};
            bit_cnt <= bit_cnt + 2;
        end
    end


    function [17:0] reconstruct_data;
        input [8:0] lane_a; // Odd bits
        input [8:0] lane_b; // Even bits
        integer i;
        begin
            reconstruct_data = 0;
            for (i = 0; i < 9; i = i + 1) begin
                reconstruct_data[2*i+1] = lane_a[i];
                reconstruct_data[2*i]   = lane_b[i];
            end
        end
    endfunction


endmodule