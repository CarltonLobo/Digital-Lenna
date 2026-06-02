`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.01.2026 03:56:23
// Design Name: 
// Module Name: ProcInput
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ProcInput(
    input clk, // rn 25Mhz
    input resetn,
    input add,
    input data
    );
    
    reg imgDataValid;
    reg [23:0] imgData;
    wire dataReady;
    wire dataValid;
    wire [23:0] outData;
    // process BRAM data 
    
    
    
    // initialize the img proc block
    imageProcessTop proc(
    .axi_clk(clk), 
    .axi_reset_n(resetn),
    .i_data_valid(imgDataValid), // triggered when the vga requires a new pixel 
    .i_data(imgData), // 24 bit input
    .o_data_ready(dataReady),
    .o_data_valid(dataValid), 
    .o_data(outData),  // 24 bit output
    .i_data_ready(1'b1),
    .o_intr(intr)
    );
    
    
endmodule
