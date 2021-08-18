//Describes PC and nPC
module pc_registers(
input wire clk, //Clocks
input wire rst,

input wire [31:0] PC_in, //Write signals
input wire PC_wr,
input wire [31:0] nPC_in, //More frequently gets written by branches
input wire nPC_wr,

input wire PCs_inc, //Normal increment

output reg [31:0] PC_out, //To address bus and to read commands
output reg [31:0] nPC_out //Only goes to read commands
);

always @(posedge clk or negedge rst) begin
	if(~rst) begin
		PC_out<=32'd0;
		nPC_out<=32'd4;
	end
	else if(nPC_wr) nPC_out<=nPC_in;
	else if(PC_wr) PC_out<=PC_in;
	else if(PCs_inc) begin
		PC_out<=nPC_out;
		nPC_out<=nPC_out+4;
	end
end


endmodule