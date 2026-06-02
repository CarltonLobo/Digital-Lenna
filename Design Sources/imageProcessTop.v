`timescale 1ns / 1ps
module imageProcessTop(
    input wire axi_clk, 
    input wire axi_reset_n,
    input wire i_data_valid, 
    input wire [23:0] i_data, 
    output wire o_data_ready,
    output wire o_data_valid, 
    output wire [23:0] o_data, 
    input wire i_data_ready,
    output wire o_intr,
    input wire kern_blur,
    input wire kern_inv,
    input wire kern_sharp,
    input wire kern_gaus,
    input wire kern_sobel,
    input wire kern_emboss,
    input wire kern_prewitt,
    input wire kern_lap
);
    wire [215:0] pixel_data;
    wire pixel_data_valid, axis_prog_full;
    wire [23:0] convolved_data;
    wire convolved_data_valid;
    wire [31:0] fifo_output_data; // Temporary 32-bit wire for FIFO output

    assign o_data_ready = ~axis_prog_full;
    
    // Extract the lower 24 bits for the final output
    assign o_data = fifo_output_data[23:0];

    imageControl IC (
        .i_clk(axi_clk), .i_rst(~axi_reset_n),
        .i_pixel_data(i_data), .i_pixel_valid(i_data_valid),
        .o_pixel_data(pixel_data), .o_pixel_data_valid(pixel_data_valid),
        .intr(o_intr)
    );

    conv conv_inst (
        .i_clk(axi_clk), .i_pixel_data(pixel_data), .i_pixel_data_valid(pixel_data_valid),
        .o_convolved_data(convolved_data), .o_convolved_data_valid(convolved_data_valid),
        .kern_blur(kern_blur),
        .kern_inv(kern_inv),
        .kern_sharp(kern_sharp),
        .kern_gaus(kern_gaus),
        .kern_sobel(kern_sobel),
        .kern_emboss(kern_emboss),
        .kern_prewitt(kern_prewitt),
        .kern_lap(kern_lap)
    );

    // Padding the 24-bit convolved_data to 32-bits with 8 leading zeros
    outputBuffer OB (
        .s_aclk(axi_clk), .s_aresetn(axi_reset_n),
        .s_axis_tvalid(convolved_data_valid), 
        .s_axis_tdata({8'h00, convolved_data}), // Padding here
        .m_axis_tvalid(o_data_valid), 
        .m_axis_tready(i_data_ready), 
        .m_axis_tdata(fifo_output_data),        // Connected to 32-bit wire
        .axis_prog_full(axis_prog_full)
    );
endmodule