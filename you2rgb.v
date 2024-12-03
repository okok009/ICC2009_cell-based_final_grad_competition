module YUV_TO_RGB (
                 output_Red,
                 output_Green,
                 output_Blue,
                 input_Luminance_Y,
                 input_Chrominance_U,
                 input_Chrominance_V
);

    output  [7: 0] output_Red;
    output  [7:0] output_Green;
    output  [7:0] output_Blue;

    input   [7:0] input_Luminance_Y;
    input   [7:0] input_Chrominance_U;
    input   [7:0] input_Chrominance_V;

    wire    [0:0] positive_negative_Luminance_Y;
    wire    [0:0] positive_negative_Chrominance_U;
    wire    [0:0] positive_negative_Chrominance_V;

    wire    [7:0] signed_input_Luminance_Y;
    wire    [7:0] signed_input_Chrominance_U;
    wire    [7:0] signed_input_Chrominance_V;

    wire    [0:0] positive_negative_Y_to_Red;
    wire    [0:0] positive_negative_U_to_Red;
    wire    [0:0] positive_negative_V_to_Red;
    wire    [7:0] extended_V_to_Red; //1.625

    wire    [0:0] positive_negative_Y_to_Green;
    wire    [0:0] positive_negative_U_to_Green;
    wire    [0:0] positive_negative_V_to_Green;
    wire    [7:0] extended_U_to_Green; //-0.25
    wire    [7:0] extended_V_to_Green; //-0.78

    wire    [0:0] positive_negative_Y_to_Blue;
    wire    [0:0] positive_negative_U_to_Blue;
    wire    [0:0] positive_negative_V_to_Blue;
    wire    [7:0] extended_U_to_Blue; //2

    wire    [19:0] result_Y_to_Red;
    wire    [19:0] result_U_to_Red;
    wire    [19:0] result_V_to_Red;
    wire    [19:0] weighted_result_V_to_Red;
    wire    [19:0] final_result_Red;

    wire    [19:0] result_Y_to_Green;
    wire    [19:0] result_U_to_Green;
    wire    [19:0] weighted_result_U_to_Green;
    wire    [19:0] result_V_to_Green;
    wire    [19:0] weighted_result_V_to_Green;
    wire    [19:0] final_result_Green;

    wire    [19:0] result_Y_to_Blue;
    wire    [19:0] result_U_to_Blue;
    wire    [19:0] weighted_result_U_to_Blue;
    wire    [19:0] result_V_to_Blue;
    wire    [19:0] final_result_Blue;

    // Check Positive or Negative, if Negative, reverse it to Positive and mark the sign bit
    // Luminance_Y sign extension
    assign positive_negative_Luminance_Y [0:0] = 1'b0;
    assign signed_input_Luminance_Y[7:0] = input_Luminance_Y[7:0];
        
    // Chrominance_U sign extension
    assign positive_negative_Chrominance_U [0:0] = input_Chrominance_U[7:7];  
    assign signed_input_Chrominance_U[7:0] = ( positive_negative_Chrominance_U ==1'b0 ) ? input_Chrominance_U[7:0] : 8'hff - input_Chrominance_U + 8'h01 ; 
    
    // Chrominance_V sign extension
    assign positive_negative_Chrominance_V [0:0] = input_Chrominance_V[7:7];  
    assign signed_input_Chrominance_V[7:0] = ( positive_negative_Chrominance_V ==1'b0 ) ? input_Chrominance_V[7:0] : 8'hff - input_Chrominance_V + 8'h01 ; 

    // V_to_Red = 0 => 8'h 1.a
    assign positive_negative_V_to_Red[0:0] = 1'b0;
    assign extended_V_to_Red [7:4] = 4'h1;
    assign extended_V_to_Red [3:0] = 4'ha;
    
    // U_to_Green = -0.25 => 8'h 0.4
    assign positive_negative_U_to_Green[0:0] = 1'b1;
    assign extended_U_to_Green [7:4] = 4'h0;
    assign extended_U_to_Green [3:0] = 4'h4;

    // V_to_Green = -0.75 => 8'h 0.c
    assign positive_negative_V_to_Green[0:0] = 1'b1;
    assign extended_V_to_Green [7:4] = 4'h0;
    assign extended_V_to_Green [3:0] = 4'hc;

    // U_to_Blue = 2 => 8'h 2.0
    assign positive_negative_U_to_Blue[0:0] = 1'b0;
    assign extended_U_to_Blue [7:4] = 4'h2;
    assign extended_U_to_Blue [3:0] = 4'h0;


    // Y_to_Red Calculation
    assign result_Y_to_Red[19:12] = 8'h00;
    assign result_Y_to_Red[11:4] = input_Luminance_Y[7 : 0 ];
    assign result_Y_to_Red[3:0] = 4'h0;

    // U_to_Red Calculation
    assign result_U_to_Red[19:0] = 20'h00000;

    // V_to_Red Calculation
    assign weighted_result_V_to_Red = (  extended_V_to_Red*signed_input_Chrominance_V );
    assign result_V_to_Red   = ( (positive_negative_Chrominance_V^positive_negative_V_to_Red) == 1'b0 )? weighted_result_V_to_Red : (20'hfffff - weighted_result_V_to_Red + 20'h00001);

    assign final_result_Red     = ( result_Y_to_Red + result_U_to_Red + result_V_to_Red );

    assign output_Red      = ( final_result_Red[19] == 1'b0 && final_result_Red[19:4] >= 16'h00ff ) ? 8'hff                  :
                    ( final_result_Red[19] == 1'b0 && final_result_Red[3:3] == 1'b1     ) ? final_result_Red[11:4] + 8'h01 :
                    ( final_result_Red[19] == 1'b1                              ) ? 8'h00                  : final_result_Red[11:4];

    // Y_to_Green Calculation
    assign result_Y_to_Green[19:12] = 8'h00;
    assign result_Y_to_Green[11:4] = input_Luminance_Y[7:0];
    assign result_Y_to_Green[3:0] = 4'h0;

    // U_to_Green Calculation
    assign weighted_result_U_to_Green = (  extended_U_to_Green*signed_input_Chrominance_U );
    assign result_U_to_Green   = ( (positive_negative_Chrominance_U^positive_negative_U_to_Green) == 1'b0 )? weighted_result_U_to_Green : (20'hfffff - weighted_result_U_to_Green + 20'h00001);

    // V_to_Green Calculation
    assign weighted_result_V_to_Green = (  extended_V_to_Green*signed_input_Chrominance_V );
    assign result_V_to_Green   = ( (positive_negative_Chrominance_V^positive_negative_V_to_Green) == 1'b0 )? weighted_result_V_to_Green : (20'hfffff - weighted_result_V_to_Green + 20'h00001);

    assign final_result_Green     = ( result_Y_to_Green + result_U_to_Green + result_V_to_Green );

    // Green
    assign output_Green = ( final_result_Green[19] == 1'b0 && final_result_Green[19:4] >= 16'h00ff ) ? 8'hff                   :
                           ( final_result_Green[19] == 1'b0 && final_result_Green[3:3] == 1'b1     ) ? final_result_Green[11:4] + 8'h01 :
                           ( final_result_Green[19] == 1'b1                                    ) ? 8'h00                   : final_result_Green[11:4];

    // Y_to_Blue Calculation
    assign result_Y_to_Blue[19:12] = 8'h00;
    assign result_Y_to_Blue[11:4]  = input_Luminance_Y[7:0];
    assign result_Y_to_Blue[3:0]   = 4'h0;

    // U_to_Blue Calculation
    assign weighted_result_U_to_Blue = (extended_U_to_Blue * signed_input_Chrominance_U);
    assign result_U_to_Blue = ((positive_negative_Chrominance_U ^ positive_negative_U_to_Blue) == 1'b0) ? weighted_result_U_to_Blue : (20'hfffff - weighted_result_U_to_Blue + 20'h00001);

    // V_to_Blue Calculation
    assign result_V_to_Blue[19:0] = 20'h00000; // No effect from V to Blue in this case

    assign final_result_Blue = (result_Y_to_Blue + result_U_to_Blue + result_V_to_Blue);

    assign output_Blue = (final_result_Blue[19] == 1'b0 && final_result_Blue[19:4] >= 20'h00ff) ? 8'hff                   :
                         (final_result_Blue[19] == 1'b0 && final_result_Blue[3:3] == 1'b1     ) ? final_result_Blue[11:4] + 8'h01 :
                         (final_result_Blue[19] == 1'b1                                    ) ? 8'h00                   : final_result_Blue[11:4];

endmodule