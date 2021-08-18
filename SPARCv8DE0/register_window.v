module register_window(
	input wire clk,
	input wire rst,
	
	input wire SAVE, //save instruction
	input wire RESTORE_RETT, //restore and rett instructions
	
	/*Note: CWP and WIM live here, PSR CWP draws from here
	 * CWP and WIM should never be written to in the same clock cycle as the registers
	 * Neither should SAVE/RESTORE instructions take place in the same clock cycle as the registers
	*/
	
	input wire [4:0] CWP_in, //CWP, current window pointer
	input wire CWP_wr, //Indicates CWP write request
	output reg [4:0] CWP_out,
	
	input wire [31:0] WIM_in, //win invalid mask, for interfacing with window
	input wire WIM_wr, //Indicates WIM write request. Note that only the implemented bits of WIM can be written
	output reg [31:0] WIM_out,
	
	//We're using the recommended schema of an r1, r2, and rd interface
	input wire [4:0] r1_sel,
	input wire [4:0] r2_sel,
	input wire [4:0] rd_sel,
	
	input wire [31:0]rd_in,
	input wire [31:0] rd_wr,
	
	output reg [31:0] r1_out,
	output reg [31:0] r2_out,
	
	//traps
	input wire windows_overflow_handled,
	input wire windows_underflow_handled,
	
	output reg windows_overflow,
	output reg windows_underflow
);
	parameter NWINDOWS=3;

	//Registers
	reg [31:0] globals[7:0]; //globals
	reg [31:0] win_regs[NWINDOWS-1:0][23:0]; //windows
	reg [4:0] CWP_plus;
	reg [4:0] CWP_minus;
	
	//integers
	integer i,j,k,l,m;

	always @* begin
		globals[0]<=32'd0;
	end
	
	//Ouput register handling
	always @* begin
		if(r1_sel<4'd8) begin //Is reg pointing to globals
			r1_out=globals[r1_sel];
		end
		else begin //No, then point it towards windows
			r1_out=win_regs[CWP_out][r1_sel-5'd8];
		end
	end
	
	always @* begin
		if(r2_sel<4'd8) begin //Is register select pointing to globals
			r2_out=globals[r2_sel];
		end
		else begin //No, then point it towards windows
			r2_out=win_regs[CWP_out][r2_sel-5'd8];
		end
	end
	
	//Combinational logic for 
	
	//Clocked reg write and instruction handling
	always @(posedge clk or negedge rst) begin
		//Always handle reset first
		if(~rst) begin
			CWP_out<=5'd0; //Reset cwp
			
			for(i=0; i<32; i=i+1) begin //reset wim to it's initial value
				if(i<NWINDOWS) WIM_out[i]<=1'b1;
				else WIM_out[i]<=1'b1;
			end
			
			for(k=0; k<NWINDOWS; k=k+1) begin //reset windows
				for(l=0; l<24; l=l+1) begin
					win_regs[k][l]=32'd0;
				end
			end
			windows_overflow<=1'b0;
			windows_underflow<=1'b0;
		end
		
		//Trap stuff
		else if(windows_overflow_handled) windows_overflow<=1'b0;
		else if(windows_underflow_handled) windows_underflow<=1'b0;
		
		//Register writes
		else if(WIM_wr | CWP_wr) begin
			if(WIM_wr) begin //WIM write
				for(j=0; j<32; j=j+1) begin //set valid bits of WIM to requested value
					if(i<NWINDOWS) WIM_out[j]<=WIM_in[j];
				end
			end
			if(CWP_wr) begin //CWP write
				CWP_out<=CWP_in;
			end
		end
		
		else if(rd_wr) begin //rd write request
			if(rd_sel<4'd8) begin //Is reg pointing to globals
				globals[rd_sel]<=rd_in;
			end
			else begin //No, then point it towards windows
				win_regs[CWP_out][rd_sel-5'd8]<=rd_in;
			end
		end
		
		//Register window inc/dec
		//Notes:
		// - CWP is incremented by RESTORE/RETT, decremented by SAVE
		// - if after the SAVE operation, WIM[CWP]=1 then we have an overflow, assert trap
		// - if after the RESTORE operation, WIM[CWP]=1 then we have an underflow, assert trap
		// - if there's an underflow trap, we don't attempt to save. Same with overflow and restore
		else if(SAVE & ~windows_overflow) begin
			if(WIM_out[CWP_minus]) windows_overflow=1'b1; //check for overflow
			else begin //No overflow, do operation
				//Set up CWP locals
				if (CWP_out-5'd1) CWP_out<=CWP_minus;
				CWP_plus<=CWP_out;
				if(CWP_minus<=5'd0) CWP_minus<=CWP_minus-5'd1;
				else CWP_minus<=NWINDOWS-1'd1;
				
				//Do cycling
				//Note: We assume cycling is only a forwards operation
				for(m=7; m>=0; m=m-1) begin
					win_regs[CWP_minus][m+16]<=win_regs[CWP_out][m];
				end
			end
		end
		else if(RESTORE_RETT & ~windows_underflow) begin
			if(WIM_out[CWP_plus]) begin
				windows_underflow<=1'b1; //check for underflow
			end
			else begin //No underflow, do operation
				//Set up CWP locals
				CWP_out<=CWP_plus;
				CWP_minus<=CWP_out;
				if(CWP_plus<=(NWINDOWS-1'd1)) CWP_plus<=CWP_plus+5'd1;
				else CWP_plus<=5'd0;
				
				//Do cycling
				//Note: We assume cycling is only a forwards operation
				for(m=7; m>=0; m=m-1) begin
					win_regs[CWP_plus][m]<=win_regs[CWP_out][m+16];
				end
			end
		end
		
		//NOTE
		//Currently trap handling code isn't in here
		
	end
endmodule