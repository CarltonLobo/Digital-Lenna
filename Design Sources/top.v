`timescale 1ns / 1ps
`default_nettype none

module top
    (   input wire i_top_clk,
        input wire i_top_rst,
        input wire kern_blur,
        input wire kern_inv,
        input wire kern_sharp,
        input wire kern_gaus,
        input wire kern_sobel,
        input wire kern_emboss,
        input wire kern_prewitt,
        input wire kern_lap,
        
        input wire  i_top_cam_start, 
        output wire o_top_cam_done, 
        
        // I/O to camera
        input wire       i_top_pclk, 
        input wire [7:0] i_top_pix_byte,
        input wire       i_top_pix_vsync,
        input wire       i_top_pix_href,
        output wire      o_top_reset,
        output wire      o_top_pwdn,
        output wire      o_top_xclk,
        output wire      o_top_siod,
        output wire      o_top_sioc,
        
        // I/O to VGA 
        output wire [3:0] o_top_vga_red,
        output wire [3:0] o_top_vga_green,
        output wire [3:0] o_top_vga_blue,
        output wire       o_top_vga_vsync,
        output wire       o_top_vga_hsync
    );
      
    // --- Signal Declarations ---
    wire [11:0] cam_pix_data;
    wire [18:0] cam_pix_addr;
    wire [11:0] bram_out_data;
    wire [18:0] vga_pix_addr;
    
    wire [23:0] processed_data;
    wire        processed_valid;
    
    // VGA Internal Signals
    wire vga_hsync_int, vga_vsync_int, vga_video_active;
    
    // Reset synchronizers
    reg r1_rstn_top_clk,    r2_rstn_top_clk;
    reg r1_rstn_pclk,       r2_rstn_pclk;
    reg r1_rstn_clk25m,     r2_rstn_clk25m; 
        
    wire w_clk25m; 
    wire image_clk;
    
    // Generate clocks for camera and VGA
    clk_wiz_1 clock_gen (
        .clk_in1(i_top_clk),
        .clk_out1(w_clk25m),
        .clk_out2(o_top_xclk),
        .clk_out3(image_clk)
    );
    
    wire w_rst_btn_db; 
    localparam DELAY_TOP_TB = 240_000; 
    debouncer #( .DELAY(DELAY_TOP_TB) ) top_btn_db (
        .i_clk(i_top_clk),
        .i_btn_in(~i_top_rst),
        .o_btn_db(w_rst_btn_db)
    ); 
    
    // --- Synchronization Logic ---
    always @(posedge i_top_clk or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_top_clk, r1_rstn_top_clk} <= 0; 
        else              {r2_rstn_top_clk, r1_rstn_top_clk} <= {r1_rstn_top_clk, 1'b1}; 
    end 
    always @(posedge w_clk25m or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_clk25m, r1_rstn_clk25m} <= 0; 
        else              {r2_rstn_clk25m, r1_rstn_clk25m} <= {r1_rstn_clk25m, 1'b1}; 
    end
    always @(posedge i_top_pclk or negedge w_rst_btn_db) begin
        if(!w_rst_btn_db) {r2_rstn_pclk, r1_rstn_pclk} <= 0; 
        else              {r2_rstn_pclk, r1_rstn_pclk} <= {r1_rstn_pclk, 1'b1}; 
    end 
    
    // --- Camera Interface ---
    cam_top #( .CAM_CONFIG_CLK(100_000_000) ) OV7670_cam (
        .i_clk(i_top_clk),
        .i_rstn_clk(r2_rstn_top_clk),
        .i_rstn_pclk(r2_rstn_pclk),
        .i_cam_start(i_top_cam_start),
        .o_cam_done(o_top_cam_done), 
        .i_pclk(i_top_pclk),
        .i_pix_byte(i_top_pix_byte), 
        .i_vsync(i_top_pix_vsync), 
        .i_href(i_top_pix_href),
        .o_reset(o_top_reset),
        .o_pwdn(o_top_pwdn),
        .o_siod(o_top_siod),
        .o_sioc(o_top_sioc), 
        .o_pix_data(cam_pix_data),
        .o_pix_addr(cam_pix_addr)
    );
    
    // --- Frame Buffer ---
    mem_bram #(.WIDTH(12), .DEPTH(640*480)) pixel_memory (
        .i_wclk(i_top_pclk),
        .i_wr(1'b1),
        .i_wr_addr(cam_pix_addr),
        .i_bram_data(cam_pix_data),
        .i_bram_en(1'b1),
        .i_rclk(w_clk25m),
        .i_rd(1'b1),
        .i_rd_addr(vga_pix_addr),
        .o_bram_data(bram_out_data)
    );

    // --- Image Processing Pipeline ---
    imageProcessTop processor (
        .axi_clk(w_clk25m),
        .axi_reset_n(r2_rstn_clk25m),
        .i_data_valid(vga_video_active), 
        .i_data({4'h0, bram_out_data[11:8], 4'h0, bram_out_data[7:4], 4'h0, bram_out_data[3:0]}),
        .o_data_ready(), 
        .o_data_valid(processed_valid),
        .o_data(processed_data),
        .i_data_ready(1'b1),
        .o_intr(),
        .kern_blur(kern_blur),
        .kern_inv(kern_inv),
        .kern_sharp(kern_sharp),
        .kern_gaus(kern_gaus),
        .kern_sobel(kern_sobel),
        .kern_emboss(kern_emboss),
        .kern_prewitt(kern_prewitt),
        .kern_lap(kern_lap)
    );

    // --- VGA Controller ---
    vga_top display_interface ( // This module is only used for generating the hsync and vsync pulses
    // the pixel values are determined directly by the image top
        .i_clk25m(!w_clk25m),
        .i_rstn_clk25m(r2_rstn_clk25m),
        .o_VGA_vsync(vga_vsync_int),
        .o_VGA_hsync(vga_hsync_int),
        .o_VGA_video(vga_video_active), 
        .o_VGA_red(),    
        .o_VGA_green(), 
        .o_VGA_blue(),  
        .i_pix_data(12'b0), 
        .o_pix_addr(vga_pix_addr)
    );
    
    // --- SYNC DELAY PIPELINE (The Fix) ---
    // We delay the timing signals to match the processing latency.
    // Tweak LATENCY_TAP if the image is slightly off-center.
    localparam LATENCY_TAP = 10; 
    reg [31:0] d_hsync, d_vsync, d_active;
    
    always @(posedge w_clk25m) begin
        if(!r2_rstn_clk25m) begin
            d_hsync  <= 32'hFFFFFFFF;
            d_vsync  <= 32'hFFFFFFFF;
            d_active <= 32'h0;
        end else begin
            d_hsync  <= {d_hsync[30:0],  vga_hsync_int};
            d_vsync  <= {d_vsync[30:0],  vga_vsync_int};
            d_active <= {d_active[30:0], vga_video_active};
        end
    end

    // Assign delayed timing signals to the physical pins
    assign o_top_vga_hsync = d_hsync[LATENCY_TAP];
    assign o_top_vga_vsync = d_vsync[LATENCY_TAP];

    // Gate the data with the delayed active signal to stop stretching
    assign o_top_vga_red   = (d_active[LATENCY_TAP]) ? processed_data[19:16] : 4'h0;
    assign o_top_vga_green = (d_active[LATENCY_TAP]) ? processed_data[11:8] : 4'h0;
    assign o_top_vga_blue  = (d_active[LATENCY_TAP]) ? processed_data[3:0]   : 4'h0;
    
endmodule