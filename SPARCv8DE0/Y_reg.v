module Y_reg(
input wire clk,
input wire rst,
input wire [31:0] Y_in,
input wire Y_wr,

output reg [31:0] Y_out
);

always @(posedge clk or negedge rst) begin
	if(~rst) Y_out<=32'd0;
	else if(Y_wr) Y_out<=Y_in;
end

endmodule