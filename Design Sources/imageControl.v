`timescale 1ns / 1ps

module imageControl(
    input  wire         i_clk,
    input  wire         i_rst,
    input  wire [23:0]  i_pixel_data,
    input  wire         i_pixel_valid,
    output reg  [215:0] o_pixel_data,
    output wire         o_pixel_data_valid,
    output reg          intr
);

    // 10-bit counters needed for 640 horizontal pixels (0 to 639)
    reg [9:0]  pixelCounter;
    reg [9:0]  rdCounter;
    reg [12:0] totalPixelCounter; // Increased range for 640-based calculations

    reg [1:0] currentWrLineBuffer;
    reg [1:0] currentRdLineBuffer;

    reg rd_line_buffer;
    reg next_rd_line_buffer;

    reg rdState;
    reg nextRdState;

    reg [3:0] lineBufferWriteEnable;

    // Outputs from linebuffers
    wire [71:0] lB0o_data;
    wire [71:0] lB1o_data;
    wire [71:0] lB2o_data;
    wire [71:0] lB3o_data;

    localparam IDLE      = 1'b0;
    localparam RD_BUFFER = 1'b1;

    assign o_pixel_data_valid = rd_line_buffer;

    //--- total pixel counter ---
    always @(posedge i_clk) begin
        if(i_rst)
            totalPixelCounter <= 0;
        else begin
            if(i_pixel_valid && !rd_line_buffer)
                totalPixelCounter <= totalPixelCounter + 1;
            else if(rd_line_buffer && !i_pixel_valid)
                totalPixelCounter <= totalPixelCounter - 1;
        end
    end

    //--- FSM seq ---
    always @(posedge i_clk) begin
        if(i_rst) begin
            rdState <= IDLE;
            rd_line_buffer <= 0;
            intr <= 'b0;
        end else begin
            rdState <= nextRdState;
            rd_line_buffer <= next_rd_line_buffer;
        end
    end

    //--- FSM comb ---
    always @(*) begin
        nextRdState = rdState;
        next_rd_line_buffer = rd_line_buffer;

        case(rdState)
            IDLE: begin
                intr = 'b0;
                // Trigger when 3 full lines (640 * 3 = 1920) are stored
                if(totalPixelCounter >= 1920) begin
                    next_rd_line_buffer = 1;
                    nextRdState = RD_BUFFER;
                end
            end
            RD_BUFFER: begin
                // Read a full 640-pixel line
                if(rdCounter == 639) begin
                    next_rd_line_buffer = 0;
                    nextRdState = IDLE;
                    intr = 'b1;
                end
            end
        endcase
    end

    //--- write pointer ---
    always @(posedge i_clk) begin
        if(i_rst)
            pixelCounter <= 0;
        else if(i_pixel_valid) begin
            if(pixelCounter == 639) pixelCounter <= 0;
            else                   pixelCounter <= pixelCounter + 1;
        end
    end

    //--- write buffer select ---
    always @(posedge i_clk) begin
        if(i_rst)
            currentWrLineBuffer <= 0;
        else if(pixelCounter == 639 && i_pixel_valid)
            currentWrLineBuffer <= currentWrLineBuffer + 1;
    end

    //--- write enables ---
    always @(*) begin
        lineBufferWriteEnable = 4'b0000;
        lineBufferWriteEnable[currentWrLineBuffer] = i_pixel_valid;
    end

    //--- read counter ---
    always @(posedge i_clk) begin
        if(i_rst)
            rdCounter <= 0;
        else if(rd_line_buffer) begin
            if(rdCounter == 639) rdCounter <= 0;
            else                rdCounter <= rdCounter + 1;
        end
    end

    //--- read buffer select ---
    always @(posedge i_clk) begin
        if(i_rst)
            currentRdLineBuffer <= 0;
        else if(rdCounter == 639 && rd_line_buffer)
            currentRdLineBuffer <= currentRdLineBuffer + 1;
    end

    //--- output register mux (3x3 Window Construction) ---
    
    always @(posedge i_clk) begin
        if(i_rst)
            o_pixel_data <= 0;
        else if(rd_line_buffer) begin
            case(currentRdLineBuffer)
                0: o_pixel_data <= {lB2o_data, lB3o_data, lB0o_data}; 
                1: o_pixel_data <= {lB3o_data, lB0o_data, lB1o_data};
                2: o_pixel_data <= {lB0o_data, lB1o_data, lB2o_data};
                3: o_pixel_data <= {lB1o_data, lB2o_data, lB3o_data};
            endcase
        end
    end

    //--- instantiate line buffers ---
    linebuffer lB0(.i_clk(i_clk), .i_rst(i_rst), .i_data(i_pixel_data), .i_data_valid(lineBufferWriteEnable[0]), .o_data(lB0o_data), .i_rd_data(rd_line_buffer));
    linebuffer lB1(.i_clk(i_clk), .i_rst(i_rst), .i_data(i_pixel_data), .i_data_valid(lineBufferWriteEnable[1]), .o_data(lB1o_data), .i_rd_data(rd_line_buffer));
    linebuffer lB2(.i_clk(i_clk), .i_rst(i_rst), .i_data(i_pixel_data), .i_data_valid(lineBufferWriteEnable[2]), .o_data(lB2o_data), .i_rd_data(rd_line_buffer));
    linebuffer lB3(.i_clk(i_clk), .i_rst(i_rst), .i_data(i_pixel_data), .i_data_valid(lineBufferWriteEnable[3]), .o_data(lB3o_data), .i_rd_data(rd_line_buffer));

endmodule