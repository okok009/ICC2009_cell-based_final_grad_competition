`define BW 8
`define YUV2RGB_BW 13 // in(8bit)+coe(5bit)
`define YUV2RGB_COE_BW 5
`define YUV2RGBSHIFT_BW 3
`define RGB2YUV_BW 19 // in(8bit+1bit)+max_coe(8bit)+2adder(2bit)

`timescale 1ns/10ps
module CTE ( clk, reset, op_mode, in_en, yuv_in, rgb_in, busy, out_valid, rgb_out, yuv_out);
input   clk ;
input   reset ;
input   op_mode;
input   in_en;
output  busy;
output  out_valid;
input   [7:0]   yuv_in;
output  [23:0]  rgb_out;
input   [23:0]  rgb_in;
output  [7:0]   yuv_out;

parameter signed [`YUV2RGB_COE_BW -1:0] r_v_coef = 5'b01101; // point at 3 bit 1.625
parameter signed [`YUV2RGB_COE_BW -1:0] g_u_coef = 5'b11110; // point at 3 bit -0.25
parameter signed [`YUV2RGB_COE_BW -1:0] g_v_coef = 5'b11010; // point at 3 bit -0.75

// YUV2RGB
wire signed [`YUV2RGB_BW -1:0] r_nxt;
wire signed [`YUV2RGB_BW -1:0] g_u_nxt;
wire signed [`YUV2RGB_BW -1:0] g_v_nxt;
wire signed [`YUV2RGB_BW -1:0] b_nxt;
wire signed [`YUV2RGB_BW -1:0] r_result, g_result, b_result;
wire [`BW -1:0] r_out, g_out, b_out;

reg signed [`YUV2RGB_BW -1:0] y;
reg signed [`YUV2RGB_BW -1:0] r, g, b;
reg [1:0] cnt_yuv2rgb; // count
reg busy_reg;
reg out_valid_reg;

// YUV2RGB_comb
assign r_nxt = r_v_coef * $signed(yuv_in);
assign g_u_nxt = g + g_u_coef * $signed(yuv_in);
assign g_v_nxt = g + g_v_coef * $signed(yuv_in);
assign b_nxt = b + $signed({yuv_in, 4'b0000});
assign r_result = r + y;
assign g_result = g + y;
assign b_result = b + y;
assign rgb_out = {r_out, g_out, b_out};
assign busy = busy_reg;

// instance round
round_bound_YUV2RGB R_ROUND_BOUND_YUV2RGB(.x(r_result), .out_x(r_out));
round_bound_YUV2RGB G_ROUND_BOUND_YUV2RGB(.x(g_result), .out_x(g_out));
round_bound_YUV2RGB B_ROUND_BOUND_YUV2RGB(.x(b_result), .out_x(b_out));

// YUV2RGB_seq
always @(posedge clk or posedge reset) begin
    if (reset) begin
        y <= 0;
        r <= 0;
        g <= 0;
        b <= 0;
        cnt_yuv2rgb <= 0;
        busy_reg <= 0;
        out_valid_reg <= 0;
    end
    else if (~op_mode && busy_reg && out_valid_reg) begin
        busy_reg <= 0;
        out_valid_reg <= 0;
        r <= 0;
        g <= 0;
        b <= 0;
    end
    else if (~op_mode && busy_reg && cnt_yuv2rgb == 2'b00) begin
        out_valid_reg <= 1;
    end
    else if (busy_reg) begin
        busy_reg <= 0;
        out_valid_reg <= 1;
    end
    else if (~op_mode && in_en && cnt_yuv2rgb == 2'b00) begin
        g <= g_u_nxt;
        b <= b_nxt;
        cnt_yuv2rgb <= cnt_yuv2rgb + 1;
    end
    else if (~op_mode && in_en && cnt_yuv2rgb == 2'b01) begin
        y <= {1'b0, yuv_in, `YUV2RGBSHIFT_BW'b0};
        cnt_yuv2rgb <= cnt_yuv2rgb + 1;
    end
    else if (~op_mode && in_en && cnt_yuv2rgb == 2'b10) begin
        r <= r_nxt;
        g <= g_v_nxt;
        cnt_yuv2rgb <= cnt_yuv2rgb + 1;
        busy_reg <= 1;
    end
    else if (~op_mode && in_en && cnt_yuv2rgb == 2'b11) begin
        y <= {1'b0, yuv_in, `YUV2RGBSHIFT_BW'b0};
        cnt_yuv2rgb <= cnt_yuv2rgb + 1;
        busy_reg <= 1;
        out_valid_reg <= 0;
    end
end

// ==================
// RGB2YUV
// ==================
parameter signed [5 -1:0] coef_1_3 = 5'b01101;
parameter signed [7 -1:0] coef_2_1 = ;
parameter signed [8 -1:0] coef_2_2 = ;
parameter signed [8 -1:0] coef_2_3 = 8'b00110100;
parameter signed [8 -1:0] coef_3_1 = 8'b01001000;
parameter signed [8 -1:0] coef_3_2 = 8'b11000000;
parameter signed [5 -1:0] coef_3_3 = 5'b11000;
parameter signed [9 -1:0] divisor  = 9'b010100101;

wire signed [`RGB2YUV_BW -1:0] y_r_g_nxt;
wire signed [`RGB2YUV_BW -1:0] y_b_nxt;
wire signed [`RGB2YUV_BW -1:0] y_aft; // aft: after diverse
wire signed [`RGB2YUV_BW -1:0] y_nxt;
wire signed [`RGB2YUV_BW -1:0] u_r_g_nxt;
wire signed [`RGB2YUV_BW -1:0] u_b_nxt;
wire signed [`RGB2YUV_BW -1:0] u_nxt;
wire signed [`RGB2YUV_BW -1:0] v_nxt;
wire [`BW -1:0] y1_out;
wire [`BW -1:0] u_out;
wire [`BW -1:0] v_out;
wire [`BW -1:0] y2_out;

reg signed [`RGB2YUV_BW -1:0] y1_reg;
reg signed [`RGB2YUV_BW -1:0] y_r_g_reg;
reg signed [`RGB2YUV_BW -1:0] u_reg;
reg signed [`RGB2YUV_BW -1:0] v_reg;
reg signed [`BW+1 -1:0] b_reg;
reg signed [`RGB2YUV_BW -1:0] y2_reg;
reg [2:0] cnt_rgb2yuv;
reg out_valid_reg_2;

assign y_r_g_nxt = coef_1_1 * $signed({1'b0, rgb_in[23 :16]}) + coef_1_2 * $signed({1'b0, rgb_in[15 :8]});
assign y_b_nxt = coef_1_3 * $signed({1'b0, rgb_in[7 :0]});
assign y_after_div = (y_r_g_nxt + y_b_nxt)<<<1;
assign y_nxt = (y_after_div + divisor) / (divisor<<<1);
assign u_r_g_nxt = -(y_r_g_reg>>>1);
assign u_b_nxt = coef_2_3 * b_reg;
assign u_nxt = ((u_r_g_nxt + u_b_nxt)<<<1 + divisor) / (divisor<<<1);
assign v_nxt = ( (coef_3_1 * $signed({1'b0, rgb_in[23 :16]}) + coef_3_2 * $signed({1'b0, rgb_in[15 :8]}))<<<1 + ((coef_3_3 * $signed({1'b0, rgb_in[7 :0]}))<<<1 + divisor) ) / (divisor<<<1);
assign yuv_out = y1_reg;

assign out_valid = out_valid_reg || out_valid_reg_2;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        y1_reg <= 0;
        y_r_g_reg <= 0;
        u_reg <= 0;
        v_reg <= 0;
        b_reg <= 0;
        y2_reg <= 0;
        cnt_rgb2yuv <= 0;
        out_valid_reg_2 <= 0;
    end
    else if (op_mode && in_en && ~cnt_rgb2yuv) begin
        y_r_g_reg <= y_r_g_nxt;
        y1_reg <= y_nxt;
        v_reg <= v_nxt;
        b_reg <= {1'b0, rgb_in[7 :0]};
        cnt_rgb2yuv <= 1'b1;
        out_valid_reg_2 <= 1'b0;
    end
    else if (op_mode && in_en && cnt_rgb2yuv) begin
        y2_reg <= y_nxt;
        u_reg <= u_nxt;
        cnt_rgb2yuv <= 1'b0;
        out_valid_reg_2 <= 1'b1;
    end
end

endmodule

module round_bound_YUV2RGB (x, out_x);
input signed [`YUV2RGB_BW -1:0] x;
output [`BW -1:0] out_x;

wire [`YUV2RGB_BW-`YUV2RGBSHIFT_BW -1:0] x_shift;
wire [`YUV2RGB_BW-`YUV2RGBSHIFT_BW -1:0] rounded_x;
wire carry_bit;
wire sign;
wire upperbound;

assign x_shift = x>>>`YUV2RGBSHIFT_BW;
assign carry_bit = x[`YUV2RGBSHIFT_BW -1];
assign rounded_x = x_shift + carry_bit;
assign upperbound = rounded_x[9 - 1]; // check if rounded_x is >255. The reson why don't use x is x might be 255 and carrybit might be 1.
assign sign = rounded_x[`YUV2RGB_BW-`YUV2RGBSHIFT_BW -1];
assign out_x = (sign) ? `BW'b00000000 : 
                (upperbound) ? `BW'b11111111 : rounded_x;
    
endmodule

module round_bound_RGB2YUV (x, out_x);
input signed [`RGB2YUV_BW -1:0] x;
output [`BW -1:0] out_x;

wire [`RGB2YUV_BW-`YUV2RGBSHIFT_BW -1:0] x_shift;
wire [`RGB2YUV_BW-`YUV2RGBSHIFT_BW -1:0] rounded_x;
wire carry_bit;
wire sign;
wire upperbound;

assign x_shift = x>>>`YUV2RGBSHIFT_BW;
assign carry_bit = x[`YUV2RGBSHIFT_BW -1];
assign rounded_x = x_shift + carry_bit;
assign upperbound = rounded_x[9 - 1]; // check if rounded_x is >255. The reson why don't use x is x might be 255 and carrybit might be 1.
assign sign = rounded_x[`YUV2RGB_BW-`YUV2RGBSHIFT_BW -1];
assign out_x = (sign) ? `BW'b00000000 : 
                (upperbound) ? `BW'b11111111 : rounded_x;
    
endmodule
