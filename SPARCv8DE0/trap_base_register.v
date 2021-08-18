module trap_base_register(
	input wire clk,
	input wire rst,
	
	input wire [31:0] tbr_in, //TBA, trap base address, only field writable by WRTBR
	input wire tbr_wr,
	
	input wire [7:0] tt_in, //Trap type, written at trap time, can't be written by WRTBR
	input wire tt_wr,
	
	output reg [31:0] tbr_out, //Whole register out for RDTBR
	
	output wire [19:0] tba_out,
	output wire [7:0] tt_out
);

always @(posedge clk or negedge rst) begin
	if(~rst) begin
		tbr_out[31:0]<=32'd0; //Every field gets set to 0 on reset, reset traps to addr 0, bottom 4 bits are 0's
	end
	
	//Trap Type field cannot be modified until next trap
	else if (tt_in) tbr_out[11:4]<=tt_in[7:0];
	
	//WRTBR is weird because it only actually writes TBA
	else if (tbr_wr) tbr_out[31:12]<=tbr_in[31:12];
end

assign tba_out[19:0]=tbr_out[31:12];
assign tt_out[7:0]=tbr_out[11:4];

endmodule