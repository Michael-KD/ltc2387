// Module for testbenching an LTC2387 ADC with Two-lane DDR LVDS
module virtual_adc #(
    parameter ADC_WIDTH = 18,       // ADC data width
    parameter NUM_SAMPLES = 1,       // Number of samples to generate
    parameter CYCLES_PER_SAMPLE = 9 // Number of cycles per sample
)(
    input  wire        clk,         // System clock
    input  wire        reset,       // Reset signal
    input  wire        cnv,         // Conversion start signal
    output reg         dco,         // Data Clock Out (simulated)
    output reg         da,          // Data Lane 1 (odd bits)
    output reg         db,          // Data Lane 2 (even bits)
    input wire         fast_clk     // Fast clock for internal operations
);

    // FSM states
    localparam IDLE    = 2'b00;
    localparam CONVERT = 2'b01;
    localparam OUTPUT  = 2'b10;

    reg [1:0] state = IDLE;         // Current state
    reg [4:0] bit_cnt = 0;          // Bit counter (tracks which bits are being output)
    reg [4:0] cycle_cnt = 0;        // Cycle counter (tracks 8 cycles for OUTPUT state)
    reg [3:0] sample_cnt = 0;       // Sample counter (tracks which sample is being output)



    // Sample data
    reg [ADC_WIDTH-1:0] sample_data [0:NUM_SAMPLES-1]; // Array of sample data

    // Initialize sample data (example data)
    initial begin
        // sample_data[0] = 18'b110011001100110011; // Example sample 1, 
        sample_data[0] = 18'b111111111111111111;

        // sample_data[1] = 18'b010101010101010101; // Example sample 2, 87381
    end

    // FSM logic
    always @(posedge fast_clk or posedge reset) begin
        if (reset) begin
            // Reset all signals
            state <= IDLE;
            dco <= 0;
            da <= 0;
            db <= 0;
            bit_cnt <= 0;
            cycle_cnt <= 0;
            // sample_cnt <= 0;
        end else begin
            case (state)
                // IDLE: Wait for CNV signal to go high
                IDLE: begin
                    dco <= 0;
                    da <= 0;
                    db <= 0;
                    bit_cnt <= 0;
                    cycle_cnt <= 0;
                    if (cnv) begin
                        state <= CONVERT;
                    end
                end

                // CONVERT: Output the first two bits (D[17] and D[16]) of da and db and wait for clk
                CONVERT: begin
                    da <= sample_data[0][17]; // Output D[17] (odd bit)
                    db <= sample_data[0][16]; // Output D[16] (even bit)
                    bit_cnt <= 2; // Start at bit 2 (D[15] and D[14] next)
                    if (clk) begin
                        state <= OUTPUT; // Move to OUTPUT state
                    end
                end

                // OUTPUT: Only handle state transitions here
                OUTPUT: begin
                    if (bit_cnt >= 18) begin
                        // After 5 cycles, go back to IDLE
                        state <= IDLE;
                        // sample_cnt <= (sample_cnt + 1) % NUM_SAMPLES; // Move to the next sample
                    end
                end
            endcase
        end
    end

    // Output logic on clk domain
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            da <= 0;
            db <= 0;
            bit_cnt <= 0;
            cycle_cnt <= 0;
        end else if (state == OUTPUT) begin
                dco <= clk;
                da <= sample_data[0][17 - bit_cnt];
                db <= sample_data[0][16 - bit_cnt];
                bit_cnt <= bit_cnt + 2;
        end
    end

    always @(negedge clk or posedge reset) begin
        if (state == OUTPUT) begin
                dco <= clk;
                da <= sample_data[0][17 - bit_cnt];
                db <= sample_data[0][16 - bit_cnt];
                bit_cnt <= bit_cnt + 2;
        end
    end

    
endmodule