module psr_register(
	input clk,
	input rst,
	
	input wire [31:0] psr_in, //Write whole PSR
	input wire psr_wr,
	
	output reg [31:0] psr_out, //Output whole PSR
	
	//Input specific parts of the PSR
	input wire [3:0] icc_in, //icc
	input wire icc_wr,
	
	input wire [4:0] CWP_in, //cwp
	input wire CWP_wr,
	
	input wire [3:0] PIL_in,
	input wire PIL_wr,
	
	input wire S_set, //supervisor mode set
	input wire S_in,
	input wire PS_set, //Last mode set
	input wire PS_in,
	input wire ET_set, //trap enabled
	input wire ET_in,
	
	//Outputs for specific parts
	output wire [3:0] impl_out, //implementation bits
	output wire [3:0] ver_out, //version bits
	output wire EC_out, //Coprocessor enabled
	output wire EF_out, //FPU enabled
	output wire [3:0] PIL_out, //Interrupt level
	output wire S_out, //Supervisor mode
	output wire PS_out, //Last known mode
	output wire ET_out, //Traps enabled, if ET is 0, asynchronous traps are ignored, synchronous cause error mode
	output wire [4:0] CWP_out,
	output wire [3:0] icc_out
);
	
	always @(posedge clk or negedge rst) begin
		if(~rst) begin
			psr_out[31:28]<=4'd0; //impl (don't care)
			psr_out[27:24]<=4'd0; //ver (don't care)
			psr_out[23:20]<=4'd0; //icc
			psr_out[13]<=1'd0; //EC - no coprocessor
			psr_out[12]<=1'd0; //EF - no fpu 
			psr_out[11:8]<=4'd0; //PIL - start out at 0
			psr_out[7]<=1'd1; //S - always in supervisor mode
			psr_out[6]<=1'b1; //PS - always in supervisor mode
			psr_out[5]<=1'b1; //ET - Traps are always 1
			psr_out[4:0]<=4'b0; //CWP
		end
		else if(PIL_wr) begin
			psr_out[11:8]<=PIL_in[3:0];
		end
		else if(psr_wr) begin
			psr_out[23:0]<=psr_in[23:0];
		end
		else if(icc_wr) begin
			psr_out[23:20]<=icc_in[3:0];
		end
		else if(CWP_wr) begin
			psr_out[4:0]<=CWP_in[4:0];
		end
		else if(S_set) begin
			psr_out[7]<=S_in;
		end
		else if(PS_set) begin
			psr_out[6]<=PS_in;
		end
		else if(ET_set) begin
			psr_out[5]<=ET_in;
		end
	end
	
	assign impl_out[3:0]=psr_out[31:28];
	assign ver_out[3:0]=psr_out[27:24];
	assign icc_out[3:0]=psr_out[23:20];
	assign EC_out=psr_out[13];
	assign EF_out=psr_out[12];
	assign PIL_out[3:0]=psr_out[11:8];
	assign S_out=psr_out[7];
	assign PS_out=psr_out[6];
	assign ET_out=psr_out[5];
	assign CWP_out[4:0]=psr_out[4:0];

endmodule