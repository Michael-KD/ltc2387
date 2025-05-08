module virtual_adc #(
    parameter ADC_WIDTH = 18,       // ADC data width
    parameter NUM_SAMPLES = 1       // Number of samples to generate
)(
    input  wire        clk,         // System clock
    input  wire        reset,       // Reset signal
    input  wire        cnv,         // Conversion start signal
    output reg         dco,         // Data Clock Out (simulated)
    output reg         da,          // Data Lane 1 (odd bits)
    output reg         db,           // Data Lane 2 (even bits)
    input wire         fast_clk,    // Fast clock for internal operations
);

    assign dco = clk; // Simulate DCO as the system clock

    // FSM states
    localparam IDLE    = 2'b00;
    localparam CONVERT = 2'b01;
    localparam OUTPUT  = 2'b10;

    reg [1:0] state = IDLE;         // Current state
    reg [3:0] bit_cnt = 0;          // Bit counter (tracks which bits are being output)
    reg [3:0] cycle_cnt = 0;        // Cycle counter (tracks 5 cycles for OUTPUT state)
    reg [3:0] sample_cnt = 0;       // Sample counter (tracks which sample is being output)
    reg capturing = 0;              // Capturing flag

    // Sample data
    reg [ADC_WIDTH-1:0] sample_data [0:NUM_SAMPLES-1]; // Array of sample data

    // Initialize sample data (example data)
    initial begin
        sample_data[0] = 18'b101010101010101010; // Example sample 1
        sample_data[1] = 18'b010101010101010101; // Example sample 2
        // Add more samples as needed
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
            sample_cnt <= 0;
            capturing <= 0;
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
                    da <= sample_data[sample_cnt][17]; // Output D[17] (odd bit)
                    db <= sample_data[sample_cnt][16]; // Output D[16] (even bit)
                    bit_cnt <= 2; // Start at bit 2 (D[15] and D[14] next)
                    if (clk) begin
                        outputting <= 1; // Set output flag
                        state <= OUTPUT; // Move to OUTPUT state
                    end
                end

                // OUTPUT: Output the remaining bits in 5 cycles
                OUTPUT: begin
                    if (cycle_cnt < 5) begin
                        if (clk && !capturing) begin
                            // On rising edge of clk
                            capturing <= 1; // Set capturing flag
                            if (dco == 0) begin
                                // On falling edge of DCO
                                dco <= 1; // Set DCO high
                                da <= sample_data[sample_cnt][17 - bit_cnt]; // Output odd bit
                                db <= sample_data[sample_cnt][16 - bit_cnt]; // Output even bit
                            end else begin
                                // On rising edge of DCO
                                dco <= 0; // Set DCO low
                                da <= sample_data[sample_cnt][17 - (bit_cnt + 1)]; // Output next odd bit
                                db <= sample_data[sample_cnt][16 - (bit_cnt + 1)]; // Output next even bit
                                bit_cnt <= bit_cnt + 2; // Increment bit counter by 2
                                cycle_cnt <= cycle_cnt + 1; // Increment cycle counter
                            end
                        end else if (!clk) begin
                            // On falling edge of clk, clear capturing flag
                            capturing <= 0;
                        end
                    end else begin
                        // After 5 cycles, go back to IDLE
                        state <= IDLE;
                        sample_cnt <= (sample_cnt + 1) % NUM_SAMPLES; // Move to the next sample
                    end
                end
            endcase
        end
    end

endmodule