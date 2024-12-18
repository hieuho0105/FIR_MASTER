module tb_fir_core();

    reg iClk;
    reg iRstn;
    reg iChipSelect_Control;
    reg iWrite_Control;
    reg iRead_Control;
    reg [4:0] iAddress_Control;
    reg [31:0] iData_Control;
    wire [31:0] oData_Control;

    reg [31:0] iReadData_Master_Read;
    reg iWait_Master_Read;
    wire [31:0] oAddress_Master_Read;
    wire oRead_Master_Read;

    reg iWait_Master_Write;
    wire [31:0] oAddress_Master_Write;
    wire oWrite_Master_Write;
    wire [31:0] oWriteData_Master_Write;

    wire [3:0] state;
    wire [3:0] tap_index;
    wire [31:0] status;
    wire [31:0] control;
    wire [31:0] config_base_x;
    wire [31:0] config_base_h;
    wire [31:0] config_base_y;

    // wire [7:0] x0, x1, x2, x3, x4, x5, x6, x7;
    // wire [7:0] h0, h1, h2, h3, h4, h5, h6, h7;
    wire [7:0] x [0:7];
    wire [7:0] h [0:7];
    wire signed [16:0] y;

    // Memory model (for simulating master memory interaction)
    reg [31:0] memory [0:255];

    // Instantiate FIR Core
    fir_core uut (
        .iClk(iClk),
        .iRstn(iRstn),
        .iChipSelect_Control(iChipSelect_Control),
        .iWrite_Control(iWrite_Control),
        .iRead_Control(iRead_Control),
        .iAddress_Control(iAddress_Control),
        .iData_Control(iData_Control),
        .oData_Control(oData_Control),
        .oAddress_Master_Read(oAddress_Master_Read),
        .oRead_Master_Read(oRead_Master_Read),
        .iReadData_Master_Read(iReadData_Master_Read),
        .iWait_Master_Read(iWait_Master_Read),
        .oAddress_Master_Write(oAddress_Master_Write),
        .oWrite_Master_Write(oWrite_Master_Write),
        .oWriteData_Master_Write(oWriteData_Master_Write),
        .iWait_Master_Write(iWait_Master_Write)
    );

    // Clock generation
    initial iClk = 0;
    always #5 iClk = ~iClk;

    // Initialize memory contents
    initial begin
        // Memory for x values (inputs)
        memory[0] = 32'h00000001; // x[0] = 1
        memory[1] = 32'h00000002; // x[1] = 2
        memory[2] = 32'h00000003; // x[2] = 3
        memory[3] = 32'h00000004; // x[3] = 4
        memory[4] = 32'h00000005; // x[4] = 5
        memory[5] = 32'h00000006; // x[5] = 6
        memory[6] = 32'h00000007; // x[6] = 7
        memory[7] = 32'h00000008; // x[7] = 8

        // Memory for h values (coefficients)
        memory[8] = 32'h00000009; // h[0] = 1
        memory[9] = 32'h00000007; // h[1] = 2
        memory[10] = 32'h00000006; // h[2] = 3
        memory[11] = 32'h00000005; // h[3] = 4
        memory[12] = 32'h00000004; // h[4] = 5
        memory[13] = 32'h00000003; // h[5] = 6
        memory[14] = 32'h00000002; // h[6] = 7
        memory[15] = 32'h00000001; // h[7] = 8
    end

    // Simulate memory read
    always @(posedge iClk) begin
        if (oRead_Master_Read) begin
            iWait_Master_Read <= 0; // No wait state for read
            iReadData_Master_Read <= memory[(oAddress_Master_Read[7:0])]; // Address offset
        end 
    end

    // Simulate memory write
    always @(posedge iClk) begin
        if (oWrite_Master_Write) begin
            iWait_Master_Write <= 0; // No wait state for write
            memory[(oAddress_Master_Write[7:0])] <= oWriteData_Master_Write;
        end 
    end

    // Test sequence
    initial begin
        // Initialize signals
        iRstn = 0;
        iChipSelect_Control = 0;
        iWrite_Control = 0;
        iRead_Control = 0;
        iAddress_Control = 0;
        iData_Control = 0;
        iReadData_Master_Read = 0;
        iWait_Master_Read = 0;
        iWait_Master_Write = 0;

        // Reset the design
        #20;
        iRstn = 1;

        // Configure base addresses
        iChipSelect_Control = 1;
        iWrite_Control = 1;

        iAddress_Control = 5'h00; iData_Control = 32'h00000000; #10; // Base address x = 0
        iAddress_Control = 5'h01; iData_Control = 32'h00000008; #10; // Base address h = 8
        iAddress_Control = 5'h02; iData_Control = 32'h00000010; #10; // Base address y = 16

        iWrite_Control = 0;
        iChipSelect_Control = 0;

        // Start FIR computation
        iChipSelect_Control = 1;
        iWrite_Control = 1;
        iAddress_Control = 5'h03; iData_Control = 32'h1; #10; // Start signal
        iWrite_Control = 0;
        iChipSelect_Control = 0;

        // Wait for computation to complete
        wait(uut.status[0] == 1); // Wait until "done" flag is set
        #20;

        // Read result from memory
        $display("Result y = %d", memory[64 >> 2]);

        // End simulation
        #100;
        $stop;
    end

    // Generate individual signals for x and h arrays
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_x_h
            assign x[i] = uut.x[i];
            assign h[i] = uut.h[i];
        end
    endgenerate

    // Assign other internal signals for monitoring
    assign state = uut.state;
    assign tap_index = uut.tap_index;
    assign status = uut.status;
    assign control = uut.control;
    assign config_base_x = uut.config_base_x;
    assign config_base_h = uut.config_base_h;
    assign config_base_y = uut.config_base_y;
    assign y = uut.y;

endmodule