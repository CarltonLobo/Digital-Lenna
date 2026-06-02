`timescale 1ns / 1ps

`define headerSize 54
`define imageSize 512*512

module tb();
    
    reg clk;
    reg reset; 
    reg [23:0] imgData; 
    reg imgDataValid;
    
    wire [23:0] outData; 
    wire outDataValid;
    wire sdataready;
    wire intr;
    
    integer file, file1, i, j;
    integer status;
    integer sentSize = 0;
    integer receivedData = 0;
    
    reg [7:0] r, g, b;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 0; 
        imgDataValid = 0;
        imgData = 0;
        
        #200;
        reset = 1; // Release Reset (DUT expects active high reset based on ~axi_reset_n)
        #100;

        file = $fopen("Carlton_cropped.bmp","rb");
        file1 = $fopen("output_rgb.bmp","wb");
        
        if (file == 0) begin
            $display("ERROR: Could not open input file.");
            $finish;
        end

        // Copy BMP Header
        for(i=0; i<`headerSize; i=i+1) begin
            status = $fscanf(file, "%c", r); 
            $fwrite(file1, "%c", r);
        end
        
        $display("Feeding initial 3 lines...");
        for(i=0; i < 3*512; i=i+1) begin
            @(posedge clk);
            if(sdataready) begin
                // BMP stores pixels as Blue-Green-Red
                status = $fscanf(file, "%c", b);
                status = $fscanf(file, "%c", g);
                status = $fscanf(file, "%c", r);
                imgData <= {r, g, b}; // Hardware expects Red in MSB
                imgDataValid <= 1'b1;
                sentSize = sentSize + 1;
            end else begin
                i = i - 1; 
                imgDataValid <= 1'b0;
            end
        end
        @(posedge clk) imgDataValid <= 1'b0;

        $display("Entering Line-by-Line mode...");
        while(sentSize < `imageSize) begin
            @(posedge intr); 
            for(j=0; j<512; j=j+1) begin
                @(posedge clk);
                if(sdataready) begin
                    status = $fscanf(file, "%c", b);
                    status = $fscanf(file, "%c", g);
                    status = $fscanf(file, "%c", r);
                    imgData <= {r, g, b};
                    imgDataValid <= 1'b1;
                    sentSize = sentSize + 1;
                end else begin
                    j = j - 1; 
                    imgDataValid <= 1'b0;
                end
            end
            @(posedge clk) imgDataValid <= 1'b0;
        end

        repeat(5) @(posedge intr); // Allow extra time for final pixels to exit FIFO

        #10000;
        $display("Simulation finished. Received %d pixels.", receivedData);
        $fclose(file);
        $fclose(file1);
        $finish;
    end

    // Capture Loop: BMP expects B, then G, then R
    always @(posedge clk) begin
        if(outDataValid) begin
            $fwrite(file1, "%c", outData[7:0]);   // Blue (LSB)
            $fwrite(file1, "%c", outData[15:8]);  // Green
            $fwrite(file1, "%c", outData[23:16]); // Red (MSB)
            receivedData <= receivedData + 1;
        end
    end

    imageProcessTop dut(
        .axi_clk(clk), // 100MHz Clk
        .axi_reset_n(reset), //  Active Low reset    
        .i_data_valid(imgDataValid), 
        .i_data(imgData),
        .o_data_ready(sdataready),
        .o_data_valid(outDataValid),
        .o_data(outData),
        .i_data_ready(1'b1),          
        .o_intr(intr)
    );

endmodule