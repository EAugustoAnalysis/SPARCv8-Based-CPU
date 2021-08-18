module alu(
	input clk,
	input rst,
	
	//IO
	input wire [31:0] r1,
	input wire [31:0] r2, //Decode should sign extend the immul
	output reg [31:0] rd,
	
	//ICC
	input wire [3:0] icc_in, //NZVC
	output reg [3:0] icc_out,
	
	//Y
	input wire [31:0] Y_in,
	output reg [31:0] Y_out,
	
	//Instruction select
	input wire [6:0] instruction,
	input wire operate,
	
	
	//Traps
	output reg divide_by_zero,
	output reg tag_overflow
	
);

//Verilog doesn't have enums so we're using parameter declarations
//Note: We're not doing SETHI here, that's going in the decode

/////////Arithmetic Operation Declarations/////////
//Logic operations
parameter AND=1;
parameter ANDcc=2;
parameter OR=3;
parameter ORcc=4;
parameter ORN=5;
parameter ORNcc=6;
parameter XOR=7;
parameter XORcc=8;
parameter XNOR=9;
parameter XNORcc=10;

//Logical Shift
parameter SLL=11;
parameter SRL=12;

//Arithmetic Shift
parameter SRA=13;

//Add and Tagged add
parameter ADD=14;
parameter ADDcc=15;
parameter ADDX=16;
parameter ADDXcc=17;
parameter TADDcc=18;
parameter TADDccTV=19;

//Sub and Tagged Sub
parameter SUB=20;
parameter SUBcc=21;
parameter SUBX=22;
parameter SUBXcc=23;
parameter TSUBcc=24;
parameter TSUBccTV=25;

//Multiply step
parameter MULScc=26;

//Multiply and Divide Unsigned
parameter UMUL=27;
parameter UMULcc=28;
parameter UDIV=29;
parameter UDIVcc=30;

//Multiply and Divide Signed
parameter SMUL=31;
parameter SMULcc=32;
parameter SDIV=33;
parameter SDIVcc=34;

//Trap handlers
parameter DBZ_HANDLE=35;
parameter TOF_HANDLE=36;

/////////Variables/////////
reg [31:0] temp_result=32'd0;
reg [63:0] temp_result_64=64'd0;
wire signed [63:0] temp_result_64_signed;

reg temp_V;
integer i,j;

assign temp_result_64_signed=temp_result_64;

//Signed inputs
wire signed [31:0] r1_signed;
wire signed [31:0] r2_signed;

assign r1_signed=r1;
assign r2_signed=r2;

//Multiply Step operands
wire [31:0] operand1;
wire [31:0] operand2;

assign operand1={(icc_in[3]^icc_in[1]),r1[31:1]};
assign operand2=(~Y_in[0])? 32'd0 : r2;

//Divide operands
wire [63:0] div1;
wire signed [63:0] div1_signed;

assign div1={Y_in,r1};
assign div1_signed={Y_in,r1};

//Instructions
always @(posedge clk or negedge rst) begin
	if (~rst) begin
		rd<=32'd0;
		icc_out<=4'd0;
		Y_out<=32'd0;
		divide_by_zero<=1'b0;
		tag_overflow<=1'b0;
	end
	else if (operate) begin
		case(instruction)
			//Logic operations
			AND: begin
				rd<=r1&r2;
				icc_out<=4'd0;
			end
			ANDcc: begin
				temp_result=r1&r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31]; //N
				icc_out[2]<= (temp_result)? 1: 0; //Z
				icc_out[1:0]=2'd0; //VC (always 0)
			end
			OR: begin
				rd<=r1|r2;
				icc_out<=4'd0;
			end
			ORcc: begin
				temp_result<=r1|r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			ORN: begin
				rd<=~(r1|r2);
				icc_out<=4'd0;
			end
			ORNcc: begin
				temp_result=~(r1|r2);
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			XOR: begin
				rd<=r1^r2;
				icc_out<=4'd0;
			end
			XORcc: begin
				temp_result=r1^r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			XNOR: begin
				rd<=~(r1^r2);
				icc_out<=4'd0;
			end
			XNORcc: begin
				temp_result=~(r1^r2);
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			
			//Logical shift
			SLL: begin
				rd<=r1<<r2;
				icc_out<=4'd0;
			end
			SRL: begin
				rd<=r1>>r2;
				icc_out<=4'd0;
			end
			
			//Arithmetic shift
			SRA: begin
				rd<=r1_signed>>>r2_signed;
				icc_out<=4'd0;
			end
			
			//Add and Tagged add
			ADD: begin
				rd<=r1+r2;
				icc_out<=4'd0;
			end
			ADDcc: begin
				temp_result=r1+r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=((r1[31]&r2[31])&(~temp_result[31]))|(((~r1[31])&(~r2[31]))&temp_result[31]); //In Appendix C
				icc_out[0]<=(r1[31]&r2[31])|((~temp_result[31])&(r1[31]|r2[31]));
			end
			ADDX: begin
				rd<=r1+r2+icc_in[0]; //+C
				icc_out<=4'd0;
			end
			ADDXcc: begin
				temp_result=r1+r2+icc_in[0]; //+C
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=((r1[31]&r2[31])&(~temp_result[31]))|(((~r1[31])&(~r2[31]))&temp_result[31]);
				icc_out[0]<=(r1[31]&r2[31])|((~temp_result[31])&(r1[31]|r2[31]));
			end
			TADDcc: begin
				temp_result=r1+r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=(((r1[31]&r2[31])&(~temp_result[31]))|(((~r1[31])&(~r2[31]))&temp_result[31]))|(r1[1:0] | r2[1:0]);
				icc_out[0]<=(r1[31]&r2[31])|((~temp_result[31])&(r1[31]|r2[31]));
			end
			TADDccTV: begin
				temp_result=r1+r2;
				temp_V=(((r1[31]&r2[31])&(~temp_result[31]))|(((~r1[31])&(~r2[31]))&temp_result[31]))|(r1[1:0] | r2[1:0]);
				if(temp_V) begin //Tag overflow
					tag_overflow<=1'b1;
				end
				else begin //No overflow
					icc_out[3]<=temp_result[31];
					icc_out[2]<=(temp_result)? 1: 0;
					icc_out[1]<=temp_V;
					icc_out[0]<=(r1[31]&r2[31])|((~temp_result[31])&(r1[31]|r2[31]));
					rd<=temp_result;
				end
			end
			
			//Sub and Tagged Sub
			SUB: begin
				rd<=r1-r2;
				icc_out<=4'd0;
			end
			SUBcc: begin
				temp_result=r1-r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=((r1[31]&(~r2[31]))&(~temp_result[31]))|(((~r1[31])&r2[31])&temp_result[31]);
				icc_out[0]<=((~r1[31])&r2[31])|(temp_result[31]&((~r1[31])|r2[31]));
			end
			SUBX: begin
				rd<=r1-r2-icc_in[0];
				icc_out<=4'd0;
			end
			SUBXcc: begin
				temp_result=r1-r2-icc_in[0];
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=((r1[31]&(~r2[31]))&(~temp_result[31]))|(((~r1[31])&r2[31])&temp_result[31]);
				icc_out[0]<=((~r1[31])&r2[31])|(temp_result[31]&((~r1[31])|r2[31]));
			end
			TSUBcc: begin
				temp_result=r1-r2;
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=(((r1[31]&(~r2[31]))&(~temp_result[31]))|(((~r1[31])&r2[31])&temp_result[31]))|(r1[1:0] | r2[1:0]);
				icc_out[0]<=((~r1[31])&r2[31])|(temp_result[31]&((~r1[31])|r2[31]));
			end
			TSUBccTV: begin
				temp_result=r1-r2;
				temp_V=(((r1[31]&(~r2[31]))&(~temp_result[31]))|(((~r1[31])&r2[31])&temp_result[31]))|(r1[1:0] | r2[1:0]);
				if(temp_V) begin
					tag_overflow<=1'b1;
				end
				else begin
					icc_out[3]<=temp_result[31];
					icc_out[2]<=(temp_result)? 1: 0;
					icc_out[1]<=temp_V;
					icc_out[0]<=((~r1[31])&r2[31])|(temp_result[31]&((~r1[31])|r2[31]));
					rd<=temp_result;
				end
			end
			
			//Multiply step
			MULScc: begin
				temp_result=operand1+operand2;
				Y_out<={r1[0],Y_in[31:1]};
				rd<=temp_result;
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=((operand1[31]&operand2[31])&(~temp_result[31]))|(((~operand1[31])&(~operand2[31]))&temp_result[31]);
				icc_out[0]<=(operand1[31]&operand2[31])|((~temp_result[31])&(operand1[31]|operand2[31]));
			end
			
			//Multiply and divide unsigned
			UMUL: begin
				{Y_out,rd}<=r1*r2;
				icc_out<=4'd0;
			end
			UMULcc: begin
				temp_result_64<=r1*r2;
				{Y_out,rd}<=temp_result_64;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			UDIV: begin
				if(~r2) begin
					divide_by_zero<=1'b1;
				end
				else begin
					temp_result_64=div1/r2;
					temp_V=(temp_result_64[63:32])? 1 : 0;
					if(temp_V) begin
						rd<=((2^^32)-1);
					end
					else begin
						rd<=temp_result_64[31:0];
					end
					icc_out<=4'd0;
				end
			end
			UDIVcc: begin
				if(~r2) begin
					divide_by_zero<=1'b1;
				end
				else begin
					temp_result_64=div1/r2;
					temp_V=(temp_result_64[63:32])? 1 : 0;
					if(temp_V) begin
						rd<=((2^^32)-1);
					end
					else begin
						rd<=temp_result_64[31:0];
					end
					icc_out[3]<=temp_result_64[31];
					icc_out[2]<= (temp_result_64[31:0])? 1: 0;
					icc_out[1]<=temp_V;
					icc_out[0]<=1'b0;
				end
			end	
		
			//Multiply and divide signed
			SMUL: begin
				{Y_out,rd}<=r1_signed*r2_signed;
				icc_out<=4'd0;
			end
			SMULcc: begin
				temp_result_64<=r1_signed*r2_signed;
				{Y_out,rd}<=temp_result_64;
				icc_out[3]<=temp_result[31];
				icc_out[2]<= (temp_result)? 1: 0;
				icc_out[1:0]=2'd0;
			end
			SDIV: begin
				if(~r2) begin
					divide_by_zero<=1'b1;
				end
				else begin
					temp_result_64=div1_signed/r2_signed;
					//Using binary operators here instead of bitwise
					temp_V=(!temp_result_64[63:31])||(temp_result_64[63:31]==((2^^33)-1))? 0 : 1;
					if(temp_V) begin
						if(temp_result_64_signed>0) begin
							rd<=((2^^31)-1);
						end
						else begin
							rd<=-(2^^31);
						end
					end
					else begin
						rd<=temp_result_64[31:0];
					end
					icc_out<=4'd0;
				end
			end
			SDIVcc: begin
				if(~r2) begin
					divide_by_zero<=1'b1;
				end
				else begin
					temp_result_64=div1_signed/r2_signed;
					//Using binary operators here instead of bitwise
					temp_V=(!temp_result_64[63:31])||(temp_result_64[63:31]==((2^^33)-1))? 0 : 1;
					if(temp_V) begin
						if(temp_result_64_signed>0) begin
							rd<=((2^^31)-1);
						end
						else begin
							rd<=-(2^^31);
						end
					end
					else begin
						rd<=temp_result_64[31:0];
					end
					icc_out[3]<=temp_result_64[31];
					icc_out[2]<= (temp_result_64[31:0])? 1: 0;
					icc_out[1]<=temp_V;
					icc_out[0]<=1'b0;
				end
			end	
			
			//Trap handlers
			DBZ_HANDLE: begin
				divide_by_zero<=1'b0;
				icc_out<=4'd0;
			end
			TOF_HANDLE: begin
				tag_overflow<=1'b0;
				icc_out<=4'd0;
			end
			
			//Default is basically nothing happening
			default: begin
				icc_out<=4'd0;
				rd<=32'd0;
			end
		endcase
	end
end

endmodule