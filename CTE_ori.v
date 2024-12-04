`define BW 8
`define YUV2RGB_BW 13 // in(8bit)+coe(5bit)
`define YUV2RGB_COE_BW 5
`define YUV2RGBSHIFT_BW 3
`define RGB2YUV_BW 18 // in(8bit+1bit)+max_coe(8bit)+2adder(2bit), min: 18

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

// instance round
round_bound R_ROUND_BOUND(.x(r_result), .out_x(r_out));
round_bound G_ROUND_BOUND(.x(g_result), .out_x(g_out));
round_bound B_ROUND_BOUND(.x(b_result), .out_x(b_out));

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
parameter signed [6 -1:0] coef_2_1 = 6'b101000;
parameter signed [7 -1:0] coef_2_2 = 7'b1001100;
parameter signed [8 -1:0] coef_2_3 = 8'b01001100;
parameter signed [8 -1:0] coef_3_1 = 8'b01001000;
parameter signed [8 -1:0] coef_3_2 = 8'b11000000;
parameter signed [5 -1:0] coef_3_3 = 5'b11000;
parameter signed [9 -1:0] divisor_pos  = 9'b010100101; // 165
parameter signed [9 -1:0] divisor_neg  = 9'b101011011; // 165

wire signed [`BW -1:0] yuv_out_nxt;
wire signed [`RGB2YUV_BW -1:0] y_r_g_nxt;
wire signed [`RGB2YUV_BW -1:0] y_b_nxt;
wire signed [`RGB2YUV_BW -1:0] y_nxt;
wire signed [`RGB2YUV_BW -1:0] u_r_g_nxt;
wire signed [`RGB2YUV_BW -1:0] u_b_nxt;
wire signed [`RGB2YUV_BW -1:0] u_nxt;
wire signed [`RGB2YUV_BW -1:0] v_nxt;
wire signed [9 -1:0] divisor;
wire signed [`RGB2YUV_BW -1:0] yuv_aft; // aft: after diverse

reg signed [`BW -1:0] yuv_out_reg;
reg [1:0] cnt_rgb2yuv;
reg out_valid_reg_2;
reg busy_reg_2;
reg [23:0] rgb_in_reg;
reg [`RGB2YUV_BW -1:0] u_r_g_reg;

assign y_r_g_nxt = -(u_r_g_reg<<<1);
assign y_b_nxt = coef_1_3 * $signed({1'b0, rgb_in_reg[7 :0]});
assign y_nxt = (y_r_g_nxt + y_b_nxt)<<<1;
assign u_r_g_nxt = coef_2_1 * $signed({1'b0, rgb_in[23 :16]}) + coef_2_2 * $signed({1'b0, rgb_in[15 :8]});
assign u_b_nxt = coef_2_3 * $signed({1'b0, rgb_in[7 :0]});
assign u_nxt = (u_r_g_nxt + u_b_nxt)<<<1;
assign v_nxt = ((coef_3_1 * $signed({1'b0, rgb_in_reg[23 :16]}) + coef_3_2 * $signed({1'b0, rgb_in_reg[15 :8]})) + coef_3_3 * $signed({1'b0, rgb_in_reg[7 :0]}))<<<1;
assign yuv_aft = (cnt_rgb2yuv == 2'b00) ? u_nxt :
                 (cnt_rgb2yuv == 2'b01) ? y_nxt :
                 (cnt_rgb2yuv == 2'b10) ? v_nxt :
                 (cnt_rgb2yuv == 2'b11) ? y_nxt : `RGB2YUV_BW'bx;
assign divisor = (yuv_aft[`RGB2YUV_BW -1]) ? divisor_neg : divisor_pos;
assign yuv_out_nxt = (yuv_aft + divisor) / (divisor_pos<<<1);
assign yuv_out = yuv_out_reg;
assign out_valid = out_valid_reg || out_valid_reg_2;
assign busy = busy_reg || busy_reg_2;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt_rgb2yuv <= 0;
        busy_reg_2 <= 0;
        out_valid_reg_2 <= 0;
        rgb_in_reg <= 0;
        yuv_out_reg <= 0;
    end
    else if (op_mode && in_en && cnt_rgb2yuv == 2'b00) begin
        rgb_in_reg <= rgb_in;
        u_r_g_reg <= u_r_g_nxt;
        cnt_rgb2yuv <= cnt_rgb2yuv + 1;
        out_valid_reg_2 <= 1;
        busy_reg_2 <= 1;
        yuv_out_reg <= yuv_out_nxt;
    end
    else if (op_mode && in_en && cnt_rgb2yuv == 2'b01) begin
        cnt_rgb2yuv <= cnt_rgb2yuv + 1;
        busy_reg_2 <= 0;
        yuv_out_reg <= yuv_out_nxt;
    end
    else if (op_mode && in_en && cnt_rgb2yuv == 2'b10) begin
        rgb_in_reg <= rgb_in;
        u_r_g_reg <= u_r_g_nxt;
        cnt_rgb2yuv <= cnt_rgb2yuv + 1;
        busy_reg_2 <= 1;
        yuv_out_reg <= yuv_out_nxt;
    end
    else if (op_mode && in_en && cnt_rgb2yuv == 2'b11) begin
        cnt_rgb2yuv <= cnt_rgb2yuv + 1;
        busy_reg_2 <= 0;
        yuv_out_reg <= yuv_out_nxt;
    end
end

endmodule

module round_bound (x, out_x);
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
