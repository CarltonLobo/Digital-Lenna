`timescale 1ns / 1ps

module linebuffer(
    input wire i_clk,
    input wire i_rst,
    input wire [23:0] i_data,
    input wire i_data_valid,
    input wire i_rd_data,
    output wire [71:0] o_data
);
    
    // Increased to 640 to match VGA width
    reg [23:0] line [639:0]; 
    reg [9:0] wrPntr; // 10 bits needed for 0-639
    reg [9:0] rdPntr;
    
    reg [23:0] p1, p2, p3;

    // Write Logic
    always @(posedge i_clk) begin
        if(i_data_valid)
            line[wrPntr] <= i_data;
    end

    always @(posedge i_clk) begin
        if(i_rst) 
            wrPntr <= 0;
        else if(i_data_valid) begin
            if (wrPntr == 639) wrPntr <= 0;
            else              wrPntr <= wrPntr + 1;
        end
    end

    // Read Logic with Sliding Window
    always @(posedge i_clk) begin
        if(i_rst) begin
            rdPntr <= 0;
            p1 <= 0; p2 <= 0; p3 <= 0;
        end else if(i_rd_data) begin
            if (rdPntr == 639) rdPntr <= 0;
            else              rdPntr <= rdPntr + 1;
            
            p1 <= line[rdPntr];
            p2 <= p1;
            p3 <= p2;
        end
    end

    assign o_data = {p1, p2, p3};
    
endmodule