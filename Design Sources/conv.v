`timescale 1ns / 1ps

module conv(
    input  wire         i_clk,
    input  wire [215:0] i_pixel_data,
    input  wire         i_pixel_data_valid,
    output reg [23:0]   o_convolved_data,
    output reg          o_convolved_data_valid,
    input wire kern_blur,
    input wire kern_inv,
    input wire kern_sharp,
    input wire kern_gaus,
    input wire kern_sobel,
    input wire kern_emboss,
    input wire kern_prewitt,
    input wire kern_lap
);
        
    integer i; 
    reg signed [7:0] kernel [8:0];
    reg signed [7:0] kernel_y [8:0];   // Sobel Gy kernel
    
    // Grayscale value for each pixel in the 3x3 window (Sobel only)
    reg [7:0] gray [8:0];
    
    // Stage 1: Multiplier outputs
    reg signed [23:0] multDataR[8:0], multDataG[8:0], multDataB[8:0];
    reg multDataValid;
    
    // Stage 2: Intermediate sums
    reg signed [23:0] sumDataIntR, sumDataIntG, sumDataIntB;
    reg signed [23:0] sumDataR, sumDataG, sumDataB;
    reg sumDataValid;

    // -------------------------------------------------------
    // Integer square root (restoring algorithm)
    // -------------------------------------------------------
    function [10:0] isqrt;
        input [21:0] num;
        reg [21:0] op, res, one;
        integer k;
        begin
            op  = num;
            res = 0;
            for (k = 10; k >= 0; k = k - 1) begin
                one = 22'd1 << (2 * k);
                if (op >= res + one) begin
                    op  = op - res - one;
                    res = (res >> 1) + one;
                end else begin
                    res = res >> 1;
                end
            end
            isqrt = res[10:0];
        end
    endfunction
    
    // -------------------------------------------------------
    // Grayscale: Combinational 
    // -------------------------------------------------------
    always @(*) begin
        for (i = 0; i < 9; i = i + 1) begin
            gray[i] = (i_pixel_data[i*24+16 +: 8] 
                     + i_pixel_data[i*24+8  +: 8] 
                     + i_pixel_data[i*24+0  +: 8]) / 3;
        end
    end
    
    // -------------------------------------------------------
    // Kernel Selection: Combinational
    // -------------------------------------------------------
    always @(*) begin
        // Default Gx / Main Kernel
        if(kern_blur) begin
            for(i=0; i<9; i=i+1) kernel[i] = 1; 
        end else if(kern_inv) begin
            for(i=0; i<9; i=i+1) begin kernel[i] = 0; end
            kernel[4] = -1;
        end else if(kern_sharp) begin
            kernel[0]= 0;  kernel[1]=-1;  kernel[2]= 0; 
            kernel[3]=-1;  kernel[4]= 5;  kernel[5]=-1; 
            kernel[6]= 0;  kernel[7]=-1;  kernel[8]= 0;
        end else if(kern_emboss) begin
            kernel[0]=-2;  kernel[1]=-1;  kernel[2]= 0; 
            kernel[3]=-1;  kernel[4]= 1;  kernel[5]= 1; 
            kernel[6]= 0;  kernel[7]= 1;  kernel[8]= 2; 
        end else if (kern_gaus) begin
            for(i=0; i<9; i=i+1) kernel[i] = (i%2) + 1;
            kernel[4] = 5;
        end else if (kern_sobel) begin
            kernel[0]=-1; kernel[1]= 0; kernel[2]= 1;
            kernel[3]=-2; kernel[4]= 0; kernel[5]= 2;
            kernel[6]=-1; kernel[7]= 0; kernel[8]= 1;
        end else if(kern_prewitt)begin
            kernel[0]=-1; kernel[1]= 0; kernel[2]= 1;
            kernel[3]=-1; kernel[4]= 0; kernel[5]= 1;
            kernel[6]=-1; kernel[7]= 0; kernel[8]= 1;
        end else if(kern_lap)begin
            kernel[0]= 0;  kernel[1]=-1;  kernel[2]= 0; 
            kernel[3]=-1;  kernel[4]= 4;  kernel[5]=-1; 
            kernel[6]= 0;  kernel[7]=-1;  kernel[8]= 0;
        end else begin
            for(i=0; i<9; i=i+1) kernel[i] = 0;
            kernel[4] = 1;
        end

        // Gy Kernel for Sobel (otherwise all 0)
        if (kern_sobel) begin
            kernel_y[0]=-1; kernel_y[1]=-2; kernel_y[2]=-1;
            kernel_y[3]= 0; kernel_y[4]= 0; kernel_y[5]= 0;
            kernel_y[6]= 1; kernel_y[7]= 2; kernel_y[8]= 1;
        end else if (kern_prewitt)begin
            kernel_y[0]=-1; kernel_y[1]=-1; kernel_y[2]=-1;
            kernel_y[3]= 0; kernel_y[4]= 0; kernel_y[5]= 0;
            kernel_y[6]= 1; kernel_y[7]= 1; kernel_y[8]= 1;
        end else begin
            for(i=0; i<9; i=i+1) kernel_y[i] = 0;
        end
    end
    
    // -------------------------------------------------------
    // Stage 1: Multiplication (Registered)
    // -------------------------------------------------------
    always @(posedge i_clk) begin
        for(i=0; i<9; i=i+1) begin
            if (kern_sobel | kern_prewitt) begin
                multDataR[i] <= kernel[i]   * $signed({1'b0, gray[i]});
                multDataG[i] <= kernel_y[i] * $signed({1'b0, gray[i]});
                multDataB[i] <= 0;
            end else begin
                multDataR[i] <= kernel[i] * $signed({1'b0, i_pixel_data[i*24+16 +: 8]});
                multDataG[i] <= kernel[i] * $signed({1'b0, i_pixel_data[i*24+8  +: 8]});
                multDataB[i] <= kernel[i] * $signed({1'b0, i_pixel_data[i*24+0  +: 8]});
            end
        end
        multDataValid <= i_pixel_data_valid;
    end
    
    // -------------------------------------------------------
    // Stage 2a: Combinational Summation
    // -------------------------------------------------------
    always @(*) begin
        sumDataIntR = 0; sumDataIntG = 0; sumDataIntB = 0;
        for(i=0; i<9; i=i+1) begin
            sumDataIntR = sumDataIntR + multDataR[i];
            sumDataIntG = sumDataIntG + multDataG[i];
            sumDataIntB = sumDataIntB + multDataB[i];
        end
    end
    
    // -------------------------------------------------------
    // Stage 2b: Registered Sum & Division
    // -------------------------------------------------------
    always @(posedge i_clk) begin
        if(kern_blur) begin
            sumDataR <= sumDataIntR / 9;
            sumDataG <= sumDataIntG / 9;
            sumDataB <= sumDataIntB / 9;
        end else if(kern_gaus) begin
            sumDataR <= sumDataIntR / 16;
            sumDataG <= sumDataIntG / 16;
            sumDataB <= sumDataIntB / 16;
        end else begin
            sumDataR <= sumDataIntR;
            sumDataG <= sumDataIntG;
            sumDataB <= sumDataIntB;
        end
        sumDataValid <= multDataValid;
    end

    // -------------------------------------------------------
    // Sobel & Prewitt Magnitude Calculation (Wire logic)
    // -------------------------------------------------------
    wire signed [23:0] gx_val = sumDataR;
    wire signed [23:0] gy_val = sumDataG;
    wire [23:0] gx_abs = gx_val[23] ? (~gx_val + 1) : gx_val;
    wire [23:0] gy_abs = gy_val[23] ? (~gy_val + 1) : gy_val;
    wire [21:0] mag_sq = (gx_abs[10:0] * gx_abs[10:0]) + (gy_abs[10:0] * gy_abs[10:0]);
    wire [10:0] mag    = isqrt(mag_sq);
    wire [7:0]  mag_clamped = (mag > 11'd255) ? 8'd255 : mag[7:0];

    // -------------------------------------------------------
    // Stage 3: Output Clipping, Packing, and Final Selection
    // -------------------------------------------------------
    always @(posedge i_clk) begin
        if (kern_sobel | kern_prewitt) begin
            // Sobel uses pre-calculated magnitude (usually grayscale)
            o_convolved_data <= {mag_clamped, mag_clamped, mag_clamped};
            
        end else if (kern_inv) begin
            // Skip clamping for Invert to allow the bits to wrap/flip 
            // This produces the negative image effect
            o_convolved_data <= { sumDataR[7:0], sumDataG[7:0], sumDataB[7:0] };
            
        end else begin
            // Clamping/Saturation for Blur, Sharpen, Emboss, Gaussian, and Identity
            
            // Red Channel
            if (sumDataR[23]) o_convolved_data[23:16] <= 8'd0;
            else if (sumDataR > 24'd15) o_convolved_data[23:16] <= 8'd15;
            else o_convolved_data[23:16] <= sumDataR[7:0];

            // Green Channel
            if (sumDataG[23]) o_convolved_data[15:8] <= 8'd0;
            else if (sumDataG > 24'd15) o_convolved_data[15:8] <= 8'd15;
            else o_convolved_data[15:8] <= sumDataG[7:0];

            // Blue Channel
            if (sumDataB[23]) o_convolved_data[7:0] <= 8'd0;
            else if (sumDataB > 24'd15) o_convolved_data[7:0] <= 8'd15;
            else o_convolved_data[7:0] <= sumDataB[7:0];
        end
        
        o_convolved_data_valid <= sumDataValid;
    end
        
endmodule