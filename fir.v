module fir_core (
    // Global signals
    input             iClk,                // Clock
    input             iRstn,               // Reset (active low)
    // Configuration
    input             iChipSelect_Control, // Chip select
    input             iWrite_Control,      // Write enable
    input             iRead_Control,       // Read enable
    input      [4:0]  iAddress_Control,    // Address
    input      [31:0] iData_Control,       // Write data
    output reg [31:0] oData_Control,       // Read data
    // Master Read
    output reg [31:0] oAddress_Master_Read, // Memory address
    output reg        oRead_Master_Read,    // Memory read enable
    input      [31:0] iReadData_Master_Read,// Memory read data
    input             iWait_Master_Read,    // Memory read wait request
    // Master Write
    output reg [31:0] oAddress_Master_Write,  // Memory address
    output reg        oWrite_Master_Write,    // Memory write enable
    output reg [31:0] oWriteData_Master_Write,// Memory write data
    input             iWait_Master_Write      // Memory write wait request
);

    // Parameters
    parameter NUM_TAPS = 8;       // Number of taps
    parameter ADDR_BASE_X = 32'h00000000; // Base address for x
    parameter ADDR_BASE_H = 32'h00000000; // Base address for h
    parameter ADDR_BASE_Y = 32'h00000000; // Base address for y

    // Internal registers
    reg [7:0] x[NUM_TAPS-1:0];    // Input data x
    reg [7:0] h[NUM_TAPS-1:0];    // Coefficients h
    reg signed [16:0] y;          // Output y
    reg [3:0] state;              // FSM state
    reg [3:0] tap_index;          // Index for reading x and h

    // FSM states
    localparam IDLE      = 3'd0,
               READ_X    = 3'd1,
               READ_H    = 3'd2,
               COMPUTE   = 3'd3,
               WRITE_Y   = 3'd4,
               DONE      = 3'd5;

    reg [2:0] next_state;

    // Configuration registers
    reg [31:0] config_base_x;
    reg [31:0] config_base_h;
    reg [31:0] config_base_y;
    reg [31:0] control;
    reg [31:0] status;

    // Slave interface for configuration
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            config_base_x <= ADDR_BASE_X;
            config_base_h <= ADDR_BASE_H;
            config_base_y <= ADDR_BASE_Y;
            control <= 32'd0;
        end else if (iChipSelect_Control && iWrite_Control) begin
            case (iAddress_Control)
                5'h00: config_base_x <= iData_Control;
                5'h01: config_base_h <= iData_Control;
                5'h02: config_base_y <= iData_Control;
                5'h03: control <= iData_Control;
            endcase
        end
    end

    // Read-back logic for configuration
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            oData_Control <= 32'd0;
        end else if (iChipSelect_Control && iRead_Control) begin
            case (iAddress_Control)
                5'h00: oData_Control <= config_base_x;
                5'h01: oData_Control <= config_base_h;
                5'h02: oData_Control <= config_base_y;
                5'h03: oData_Control <= control;
                5'h04: oData_Control <= status;
            endcase
        end
    end

    // FSM for FIR filter operation
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            state <= IDLE;
            tap_index <= 0;
            y <= 0;
            oRead_Master_Read <= 0;
            oWrite_Master_Write <= 0;
            oAddress_Master_Read <= 0;
            oWriteData_Master_Write <= 0;
            status <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        oRead_Master_Read = 0;
        oWrite_Master_Write = 0;

        case (state)
            IDLE: begin
                if (control[0]) begin // Start signal
                    tap_index = 0;
                    oAddress_Master_Read = config_base_x;
                    oRead_Master_Read = 1;
                    next_state = READ_X;
                end
            end

            READ_X: begin
                if (!iWait_Master_Read) begin
                    x[tap_index] = iReadData_Master_Read[7:0];
                    if (tap_index < NUM_TAPS - 1) begin
                        tap_index = tap_index + 1;
                        oAddress_Master_Read = config_base_x + tap_index;
                        oRead_Master_Read = 1;
                    end else begin
                        tap_index = 0;
                        oAddress_Master_Read = config_base_h;
                        oRead_Master_Read = 1;
                        next_state = READ_H;
                    end
                end
            end

            READ_H: begin
                if (!iWait_Master_Read) begin
                    h[tap_index] = iReadData_Master_Read[7:0];
                    if (tap_index < NUM_TAPS - 1) begin
                        tap_index = tap_index + 1;
                        oAddress_Master_Read = config_base_h + tap_index;
                        oRead_Master_Read = 1;
                    end else begin
                        tap_index = 0;
                        y = 0;
                        next_state = COMPUTE;
                    end
                end
            end

            COMPUTE: begin
                y = 0;
                for (tap_index = 0; tap_index < NUM_TAPS; tap_index = tap_index + 1) begin
                    y = y + x[tap_index] * h[NUM_TAPS - 1 - tap_index];
                end

                next_state = WRITE_Y;
            end

            WRITE_Y: begin
                if (!iWait_Master_Write) begin
                    oAddress_Master_Write = config_base_y;
                    oWriteData_Master_Write = y;
                    oWrite_Master_Write = 1;
                    
                    next_state = DONE;
                end
            end

            DONE: begin
                oWrite_Master_Write = 0;
                    status[0] = 1; // Done signal
                    control[0] = 0;
                // if (!control[0]) begin // Wait for start signal to be cleared
                //     status[0] = 0;
                    next_state = IDLE;
                //end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule