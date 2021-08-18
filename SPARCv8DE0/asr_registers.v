// ASR Registers

// This implementation is technically not legally a sparc implementation,
// But I still want to get pretty close
// 1-15 are reserved
// All must be 32 bit registers
// The rest are implementation dependent, I think maybe a timer, watchdog timers, user LED's, and uart  are good uses
// But for now I'm going to make them normal registers as well

module asr_registers(
	input clk,
	input rst,
	
	input wire asr_wr, //write signal
	input wire [4:0] asr_sel, //select
	input wire [31:0] asr_in,
	output reg [31:0] asr_out
);

integer i;

parameter NUMREGS=31; //Here so I can easily change the number of normal registers

//The ASR registers
reg [31:0] asr_regs[NUMREGS-1:0]; 

//Select ASR register for output
always @* begin
	asr_out=asr_regs[asr_sel-5'd1];
end


always @(posedge clk or negedge rst) begin
	if(~rst) begin //Reset registers
		for(i=0; i<NUMREGS; i=i+1) begin
			asr_regs[i]=32'd0;
		end
	end
	else if (asr_wr) begin //Write registers
		asr_regs[asr_sel-5'd1]<=asr_in;
	end
end

endmodule