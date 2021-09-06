module register_window(
	input wire rst,
	input wire [4:0] CWP_in, //CWP, current window pointer
	
	//We're using the recommended schema of an r1, r2, and rd interface
	input wire [4:0] r1_sel,
	input wire [4:0] r2_sel,
	input wire [4:0] rd_sel,
	
	input wire [31:0]rd_in,
	input wire rd_wr,
	
	output reg [31:0] r1_out,
	output reg [31:0] r2_out
);
	parameter NWINDOWS=5'd3;

	//Registers
	reg [31:0] globals[7:0]; //globals
	initial globals[0]=32'd0;
	reg [31:0] win_regs[NWINDOWS-1:0][23:0]; //windows
	
	//integers
	integer i,j,k,l,m;
	
	//Ouput register handling
	always @* begin
		if(r1_sel<4'd8) begin //Is reg pointing to globals
			r1_out=globals[r1_sel];
		end
		else begin //No, then point it towards windows
			r1_out=win_regs[CWP_in][r1_sel-5'd8];
		end
	end
	
	always @* begin
		if(r2_sel<4'd8) begin //Is register select pointing to globals
			r2_out=globals[r2_sel];
		end
		else begin //No, then point it towards windows
			r2_out=win_regs[CWP_in][r2_sel-5'd8];
		end
	end
	
	//Combinational logic for 
	
	//Clocked reg write and instruction handling
	always @(posedge rd_wr) begin //Synchronous reset
		//Always handle reset first
		if(~rst) begin
			for(k=0; k<NWINDOWS; k=k+1) begin //reset windows
				for(l=0; l<24; l=l+1) begin
					win_regs[k][l]=32'd0;
				end
			end
		end
		
		//Register writes
		
		else if(rd_wr) begin //rd write request
			if(rd_sel<4'd8) begin //Is reg pointing to globals
				globals[rd_sel]<=rd_in;
			end
			else begin //No, then point it towards windows
				win_regs[CWP_in][rd_sel-5'd8]<=rd_in;
			end
		end
		
	end
endmodule