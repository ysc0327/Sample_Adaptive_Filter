`timescale 1 ns/1 ps
module SAO ( clk, reset, in_en, din, sao_type, sao_band_pos, sao_eo_class, sao_offset, lcu_x, lcu_y, lcu_size, busy, finish);
input   clk;
input   reset;
input   in_en;
input   [7:0]  din;
input   [1:0]  sao_type;
input   [4:0]  sao_band_pos;
input          sao_eo_class;
input   [15:0] sao_offset;
input   [2:0]  lcu_x;
input   [2:0]  lcu_y;
input   [1:0]  lcu_size;
output  reg busy;
output  finish;


//parameter

reg [1:0]  sao_type_r;
reg [4:0]  sao_band_pos_r;
reg        sao_eo_class_r;
reg [15:0] sao_offset_r;
reg [1:0]  lcu_size_r;
reg [13:0] sao_counter;	
reg [13:0] sram_addr;
wire work_enable;
reg [3:0] p_state, n_state;
wire lcu_16_start;
wire lcu_32_start;
wire lcu_64_start;


localparam S_IDLE = 4'd0,
		   S_OFF  = 4'd1,
		   S_BO   = 4'd2,
		   S_EO   = 4'd3,
		   S_FINISH = 4'd4;
		   

always @(posedge clk, posedge reset) begin
	if(reset)
		p_state <= S_IDLE;
	else	
		p_state <= n_state;
end

always @(*) begin	
	n_state = p_state;
	case(p_state)
		S_IDLE : begin
			if(in_en && sao_type == 0 && !busy)
				n_state = S_OFF;
			else if(in_en && sao_type == 1 && !busy)
				n_state = S_BO;
			else if(in_en && sao_type == 2 && !busy)
				n_state = S_EO;
		end
		
		S_OFF : begin
			if(sram_addr == 16383) 
				n_state = S_FINISH;
			else if(in_en && sao_type == 0 && !busy)
				n_state = S_OFF;
			else if(in_en && sao_type == 1 && !busy)
				n_state = S_BO;
			else if(in_en && sao_type == 2 && !busy)
				n_state = S_EO;
			
		end
		
		S_BO : begin
			if(sram_addr == 16383) 
				n_state = S_FINISH;
			else if(in_en && sao_type == 0 && !busy)
				n_state = S_OFF;
			else if(in_en && sao_type == 1 && !busy)
				n_state = S_BO;
			else if(in_en && sao_type == 2 && !busy)
				n_state = S_EO;
		end
		
		S_EO : begin
			if(sram_addr == 16383) 
				n_state = S_FINISH;
			else if(in_en && sao_type == 0 && !busy)
				n_state = S_OFF;
			else if(in_en && sao_type == 1 && !busy) 
				n_state = S_BO;
			else if(in_en && sao_type == 2 && !busy)
				n_state = S_EO;			
			
		end
				
		S_FINISH : begin
			//n_state = S_IDLE;
		end

	endcase
end

	
always @(posedge clk, posedge reset) begin
	if(reset) begin
		sao_type_r       <= 0;
		sao_band_pos_r   <= 0;
		sao_eo_class_r   <= 0;
		sao_offset_r     <= 0;
  		lcu_size_r       <= 0;
	end 
	else begin if((work_enable || in_en) && !busy) begin //care
		sao_type_r       <= sao_type;
		sao_band_pos_r   <= sao_band_pos;
		sao_eo_class_r   <= sao_eo_class;
		sao_offset_r     <= sao_offset;
  		lcu_size_r       <= lcu_size;
	     end
	end
	
end

reg [6:0] eo_counter;
reg busy_d;

reg [7:0] busy_cnt;
always @(posedge clk, posedge reset) begin	
	if(reset)
		eo_counter <= 0;
	else if(!busy && busy_d) ////////////care
		eo_counter <= 0;
	else if(p_state == S_EO)
		eo_counter <= eo_counter + 1;
	else 
		eo_counter <= 0;
end

always @(posedge clk, posedge reset) begin
	if(reset)
		busy_cnt <= 0;
	else if(busy)
		busy_cnt <= busy_cnt + 1;
	else 
		busy_cnt <= 0;
end
 
always @(posedge clk, posedge reset) begin	
	if(reset)
		busy_d <= 0;
	else
		busy_d <= busy;
end

reg eo_ready;
always @(posedge clk, posedge reset) begin
	if(reset)
		eo_ready <= 0;
	else if(!busy && busy_d) // this can let eo_ready remain until its operation complete
		eo_ready <= 0;
	else if(sao_eo_class_r && lcu_size_r == 0 && (eo_counter[3:0] == 4'hf))
		eo_ready <= 1;
	else if(sao_eo_class_r && lcu_size_r == 1 && (eo_counter[4:0] == 5'h1f))
		eo_ready <= 1;
	else if(sao_eo_class_r && lcu_size_r == 2 && (eo_counter[5:0] == 6'h3f))
		eo_ready <= 1;
	else if(!sao_eo_class_r && eo_counter == 1)
		eo_ready <= 1;
end
		
always @(posedge clk, posedge reset) begin
	if(reset)
		busy <= 0;

	else if((p_state == S_EO) && (sao_eo_class_r == 1) && (lcu_size_r == 0) && (sao_counter[7:0] == 8'b11101110))
		busy <= 1;		
        else if(p_state == S_EO && !sao_eo_class_r && lcu_size_r == 0 && sao_counter[7:0] == 8'b11111100)
		busy <= 1;

	else if((p_state == S_EO) && (sao_eo_class_r == 1) && (lcu_size_r == 1) && (sao_counter[9:0] == 10'b1111011110))
		busy <= 1;
	else if(p_state == S_EO && !sao_eo_class_r && lcu_size_r == 1 && sao_counter[9:0] == 10'b1111111100)
		busy <= 1;

	else if((p_state == S_EO) && (sao_eo_class_r == 1) && (lcu_size_r == 2) && (sao_counter[11:0] == 12'b111110111110))
		busy <= 1;
	else if(p_state == S_EO && !sao_eo_class_r && lcu_size_r == 2 && sao_counter[11:0] == 12'b111111111100)
		busy <= 1;

	else if(lcu_size_r == 0 && busy_cnt == 4'hf)
		busy <= 0;
	else if(lcu_size_r == 1 && busy_cnt == 5'h1f)
		busy <= 0;
	else if(lcu_size_r == 2 && busy_cnt == 6'h3f)
		busy <= 0;
	else if(!sao_eo_class_r && busy_cnt == 4'h1)
		busy <= 0;


end


assign work_enable = (p_state == S_OFF) || (p_state == S_BO) || (p_state == S_EO && eo_ready);

reg [7:0] din_r [0:128];
always @(posedge clk, posedge reset) begin
	if(reset)
		din_r[0] <= 0;
	else if(in_en)
		din_r[0] <= din;
end

genvar i;
generate 
for(i = 1; i < 129 ; i = i + 1) begin : shift_data
	always @(posedge clk, posedge reset) begin
		if(reset)
			din_r[i] <= 0;
		else	
			din_r[i] <= din_r[i-1];
	end
end
endgenerate

always @(posedge clk, posedge reset) begin
	if(reset)
		sao_counter <= 0;
	else if(work_enable)
		sao_counter <= sao_counter + 1;
end

//BO OPERATION
wire [7:0] din_shift;
wire bo_band_0;
wire bo_band_1;
wire bo_band_2;
wire bo_band_3;

wire [7:0] din_bo;
wire [3:0] bo_offset;

assign din_shift = din_r[0] >> 3;
assign bo_band_0 = (din_shift == sao_band_pos_r);
assign bo_band_1 = (din_shift == sao_band_pos_r + 1);
assign bo_band_2 = (din_shift == sao_band_pos_r + 2);
assign bo_band_3 = (din_shift == sao_band_pos_r + 3);

assign bo_offset = bo_band_0 ? sao_offset_r[15:12] : 
				   bo_band_1 ? sao_offset_r[11:8]  :
				   bo_band_2 ? sao_offset_r[7:4]   :
				   bo_band_3 ? sao_offset_r[3:0]   : 0;


assign din_bo = din_r[0] + {{4{bo_offset[3]}},bo_offset};



//EO OPERATION
reg ver_eo_keep;

wire [7:0] din_eo;
wire [7:0] ver_din_1;
wire [7:0] ver_din_2;
wire signed [8:0] ver_sub_1;
wire signed [8:0] ver_sub_2;
wire ver_category_1;
wire ver_category_2; 
wire ver_category_3; 
wire ver_category_4;
wire [7:0] din_ver;
 
// c position
assign ver_din_1 = (lcu_size_r == 0) ? din_r[16] :
				   (lcu_size_r == 1) ? din_r[32] :
				   (lcu_size_r == 2) ? din_r[64] : 0;
// a position
assign ver_din_2 = (lcu_size_r == 0) ? din_r[32] :
				   (lcu_size_r == 1) ? din_r[64] :
				   (lcu_size_r == 2) ? din_r[128] : 0;

assign ver_sub_1 = ver_din_1 - ver_din_2; // c - a  din_r[16] - din_r[32]
assign ver_sub_2 = ver_din_1 - din_r[0];  // c - b  din_r[16] - din_r[0]

assign ver_category_1 = ver_sub_1[8] && ver_sub_2[8];
assign ver_category_2 = (ver_sub_1[8] && (ver_sub_2 == 0)) || (ver_sub_2[8] && (ver_sub_1 == 0));
assign ver_category_3 = ((ver_sub_1 > 0) && (ver_sub_2 == 0)) || ((ver_sub_2 > 0) && (ver_sub_1 == 0));
assign ver_category_4 = (ver_sub_1 > 0) && (ver_sub_2 > 0);

wire [3:0] ver_eo_offset;
assign ver_eo_offset = ver_category_1 ? sao_offset_r[15:12] :
					   ver_category_2 ? sao_offset_r[11:8]  :
					   ver_category_3 ? sao_offset_r[7:4]   :
					   ver_category_4 ? sao_offset_r[3:0]   : 0;

					   
/////////////ver_eo_keep  care
always @(posedge clk, posedge reset) begin	
	if(reset)
		ver_eo_keep <= 0;
	
	//16x16
	else if(lcu_size_r == 0 && (lcu_16_start || ((sram_addr[10:8] == 3'b111 && sram_addr[3:0] == 4'b1110))))
		ver_eo_keep <= 1;
	else if(lcu_size_r == 0 && sram_addr[3:0] == 4'b1110)
		ver_eo_keep <= 0;
		
	//32x32
	else if(lcu_size_r == 1 && (lcu_32_start || (sram_addr[11:8] == 4'b1111 && sram_addr[4:0] == 5'b11110)))
		ver_eo_keep <= 1;
	else if(lcu_size_r == 1 && sram_addr[4:0] == 5'b11110)
		ver_eo_keep <= 0;
		
	
	//64x64		
	else if(lcu_size_r == 2 && (lcu_64_start || ((sram_addr[12:7] == 6'b111110 && sram_addr[5:0] == 6'b111110))))
		ver_eo_keep <= 1;
	else if(lcu_size_r == 2 && sram_addr[5:0] == 6'b111110)
		ver_eo_keep <= 0;
	
end
					   				   
assign din_ver = ver_eo_keep ? ver_din_1 : (ver_din_1 + {{4{ver_eo_offset[3]}}, ver_eo_offset});
					   
//
reg hor_eo_keep;					   
wire signed [8:0] hor_sub_1;
wire signed [8:0] hor_sub_2;
wire hor_category_1;
wire hor_category_2; 
wire hor_category_3; 
wire hor_category_4;
wire [7:0] din_hor;

assign hor_sub_1 = din_r[2] - din_r[1]; // c - b  din_r[2] - din_r[1]
assign hor_sub_2 = din_r[2] - din_r[3]; // c - a  din_r[2] - din_r[3]

assign hor_category_1 = hor_sub_1[8] && hor_sub_2[8];
assign hor_category_2 = (hor_sub_1[8] && (hor_sub_2 == 0)) || (hor_sub_2[8] && (hor_sub_1 == 0));
assign hor_category_3 = ((hor_sub_1 > 0) && (hor_sub_2 == 0)) || ((hor_sub_2 > 0) && (hor_sub_1 == 0));
assign hor_category_4 = (hor_sub_1 > 0) && (hor_sub_2 > 0);

wire [3:0] hor_eo_offset;
assign hor_eo_offset = hor_category_1 ? sao_offset_r[15:12] :
					   hor_category_2 ? sao_offset_r[11:8]  :
					   hor_category_3 ? sao_offset_r[7:4]   :
					   hor_category_4 ? sao_offset_r[3:0]   : 0;


always @(posedge clk, posedge reset) begin
	if(reset) 
		hor_eo_keep <= 0;
	//else if(lcu_size == 0 && (lcu_16_start && !work_enable) || sram_addr[3:0] == 4'hf)
	//	hor_eo_keep <= 0;
	else if(lcu_size == 0 && ((lcu_16_start && !work_enable) || sram_addr[3:0] == 4'he || sram_addr[3:0] == 4'hd))
		hor_eo_keep <= 1;
	else if(lcu_size == 1 && ((lcu_32_start && !work_enable) || sram_addr[4:0] == 5'h1e || sram_addr[4:0] == 5'h1d))
		hor_eo_keep <= 1;
	else if(lcu_size == 2 && ((lcu_64_start && !work_enable) || sram_addr[5:0] == 6'h3e || sram_addr[5:0] == 6'h3d))
		hor_eo_keep <= 1;
	else
		hor_eo_keep <= 0;

end

assign din_hor = hor_eo_keep ? din_r[2] : (din_r[2] + {{4{hor_eo_offset[3]}}, hor_eo_offset}); //!!!!!!!!!!
					   
assign din_eo = sao_eo_class_r ? din_ver : din_hor;


//lcu_start_flag

assign lcu_16_start = in_en && (lcu_size == 0) && (sao_counter[7:0] == 0) ;
assign lcu_32_start = in_en && (lcu_size == 1) && (sao_counter[9:0] == 0);
assign lcu_64_start = in_en && (lcu_size == 2) && (sao_counter[11:0] == 0);					   
					   
always @(posedge clk, posedge reset) begin
	if(reset)
		sram_addr <= 0;
	else if(lcu_16_start)
		sram_addr <= (lcu_x << 4) + (lcu_y << 11);
	else if(lcu_32_start)
		sram_addr <= (lcu_x << 5) + (lcu_y << 12);
	else if(lcu_64_start)
		sram_addr <= (lcu_x << 6) + (lcu_y << 13);
	else if(lcu_size_r == 0 && (sao_counter[3:0] == 4'd0)) // 15 in  sao_counter == 16 == 4'b0000 so next +113 when posedge clk trigger   16x16 sample one edge so [3:0] == 0
		sram_addr <= sram_addr + 113;
	else if(lcu_size_r == 1 && (sao_counter[4:0] == 5'd0))
		sram_addr <= sram_addr + 97;
	else if(lcu_size_r == 2 && (sao_counter[5:0] == 6'd0))
		sram_addr <= sram_addr + 65;
	else if(work_enable)	
		sram_addr <= sram_addr + 1;
end

reg cen;
reg wen;
always @(posedge clk, posedge reset) begin
	if(reset) begin
		cen <= 1;
		wen <= 1;
	end 
	else if(work_enable) begin
		cen <= 0;
		wen <= 0;
	end
	else begin
		cen <= 1;
		wen <= 1;
	end
end
		
reg [7:0] sram_data_in;
always @(posedge clk, posedge reset) begin
	if(reset)
		sram_data_in <= 0;
	else if(work_enable && p_state == S_OFF)
		sram_data_in <= din_r[0];
	else if(work_enable && p_state == S_BO)
		sram_data_in <= din_bo;
	else if(work_enable && p_state == S_EO)
		sram_data_in <= din_eo;
end

assign finish = (p_state == S_FINISH);

sram_16384x8 golden_sram (.Q( ), .CLK(clk), .CEN(cen), .WEN(wen), .A(sram_addr), .D(sram_data_in)); 

endmodule
