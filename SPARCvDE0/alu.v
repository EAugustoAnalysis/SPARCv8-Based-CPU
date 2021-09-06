//My final ALU design for the SPARCv8 core
//a combination between a clocked production

module alu(
	
	//IO
	input wire [31:0] rs1,
	input wire [31:0] rs2, //Decode should sign extend the immul
	output reg [31:0] rd,
	
	//ICC
	input wire [3:0] icc_in, //NZVC
	output reg [3:0] icc_out,
	
	//Y
	input wire [31:0] Y_in,
	output reg [31:0] Y_out,
	
	//Instruction select
	input wire [5:0] alu_opcode,
	
	
	//Traps
	output reg division_by_zero,
	output reg tag_overflow
	
	
);

//Verilog doesn't have enums so we're using parameter declarations
//Note: We're not doing SETHI here, that's going in the decode

/////////Arithmetic Operation Declarations/////////
//Logic operations
parameter AND=6'h05;
parameter ANDcc=6'h15;
parameter OR=6'h02;
parameter ORcc=6'h12;
parameter ORN=6'h06;
parameter ORNcc=6'h16;
parameter XOR=6'h03;
parameter XORcc=6'h13;
parameter XNOR=6'h07;
parameter XNORcc=6'h17;
parameter ANDN=6'h05;
parameter ANDNcc=6'h15;

//Logical Shift
parameter SLL=6'h25;
parameter SRL=6'h26;

//Arithmetic Shift
parameter SRA=6'h27;

//Add and Tagged add
parameter ADD=6'h00;
parameter ADDcc=6'h10;
parameter ADDX=6'h08;
parameter ADDXcc=6'h18;
parameter TADDcc=6'h20;
parameter TADDccTV=6'h22;

//Sub and Tagged Sub
parameter SUB=6'h04;
parameter SUBcc=6'h14;
parameter SUBX=6'h0C;
parameter SUBXcc=6'h1C;
parameter TSUBcc=6'h21;
parameter TSUBccTV=6'h23;

//Multiply step
parameter MULScc=6'h24;

//Multiply and Divide Unsigned
parameter UMUL=6'h0A;
parameter UMULcc=6'h1A;
parameter UDIV=7'd29;
parameter UDIVcc=7'd30;

//Multiply and Divide Signed
parameter SMUL=6'h0B;
parameter SMULcc=6'h1B;
parameter SDIV=6'h0F;
parameter SDIVcc=6'h1F;

/////////Variables/////////
reg [31:0] temp_result=32'd0;
reg [63:0] temp_result_64=64'd0;
wire signed [63:0] temp_result_64_signed;

reg temp_V;
integer i,j;

assign temp_result_64_signed=temp_result_64;

//Signed inputs
wire signed [31:0] rs1_signed;
wire signed [31:0] rs2_signed;

assign rs1_signed=rs1;
assign rs2_signed=rs2;

//Multiply Step operands
wire [31:0] operand1;
wire [31:0] operand2;

assign operand1={(icc_in[3]^icc_in[1]),rs1[31:1]};
assign operand2=(~Y_in[0])? 32'd0 : rs2;

//Divide operands
wire [63:0] div1;
wire signed [63:0] div1_signed;

assign div1={Y_in,rs1};
assign div1_signed={Y_in,rs1};

//Instructions
always @(*) begin
	case(alu_opcode)
		//Logic operations
		AND: begin
			rd<=rs1&rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ANDcc: begin
			temp_result=rs1&rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31]; //N
			icc_out[2]<= (temp_result==32'd0)? 1: 0; //Z
			icc_out[1:0]=2'd0; //VC (always 0)
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ANDN: begin
			rd<=~(rs1&rs2);
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ANDNcc: begin
			temp_result=~(rs1&rs2);
			rd<=temp_result;
			icc_out[3]<=temp_result[31]; //N
			icc_out[2]<= (temp_result==32'd0)? 1: 0; //Z
			icc_out[1:0]=2'd0; //VC (always 0)
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		OR: begin
			rd<=rs1|rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ORcc: begin
			temp_result<=rs1|rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ORN: begin
			rd<=~(rs1|rs2);
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ORNcc: begin
			temp_result=~(rs1|rs2);
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		XOR: begin
			rd<=rs1^rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		XORcc: begin
			temp_result=rs1^rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		XNOR: begin
			rd<=~(rs1^rs2);
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		XNORcc: begin
			temp_result=~(rs1^rs2);
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		
		//Logical shift
		SLL: begin
			rd<=rs1<<rs2[4:0];
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SRL: begin
			rd<=rs1>>rs2[4:0];
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		
		//Arithmetic shift
		SRA: begin
			rd<=rs1_signed>>>rs2_signed[4:0];
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		
		//Add and Tagged add
		ADD: begin
			rd<=rs1+rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ADDcc: begin
			temp_result=rs1+rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=((rs1[31]&&rs2[31])&&(!temp_result[31]))||(((!rs1[31])&&(!rs2[31]))&&temp_result[31]); //In Appendix C
			icc_out[0]<=(rs1[31]&&rs2[31])||((!temp_result[31])&&(rs1[31]||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ADDX: begin
			rd<=rs1+rs2+icc_in[0]; //+C
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		ADDXcc: begin
			temp_result=rs1+rs2+icc_in[0]; //+C
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=((rs1[31]&&rs2[31])&&(!temp_result[31]))||(((!rs1[31])&&(!rs2[31]))&&temp_result[31]);
			icc_out[0]<=(rs1[31]&&rs2[31])||((!temp_result[31])&&(rs1[31]||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		TADDcc: begin
			temp_result=rs1+rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=(((rs1[31]&&rs2[31])&&(!temp_result[31]))||(((!rs1[31])&&(!rs2[31]))&&temp_result[31]))||(rs1[1:0] || rs2[1:0]);
			icc_out[0]<=(rs1[31]&&rs2[31])||((!temp_result[31])&&(rs1[31]||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		TADDccTV: begin
			temp_result=rs1+rs2;
			temp_V=(((rs1[31]&&rs2[31])&&(!temp_result[31]))||(((!rs1[31])&&(!rs2[31]))&&temp_result[31]))||(rs1[1:0] || rs2[1:0]);
			if(temp_V) begin //Tag overflow
				tag_overflow<=1'b1;
			end
			else begin //No overflow
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=temp_V;
				icc_out[0]<=(rs1[31]&&rs2[31])||((!temp_result[31])&&(rs1[31]||rs2[31]));
				rd<=temp_result;
				tag_overflow<=1'b0;
			end
			division_by_zero<=1'b0;
		end
		
		//Sub and Tagged Sub
		SUB: begin
			rd<=rs1-rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SUBcc: begin
			temp_result=rs1-rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=((rs1[31]&&(!rs2[31]))&&(!temp_result[31]))||(((!rs1[31])&&rs2[31])&&temp_result[31]);
			icc_out[0]<=((!rs1[31])&&rs2[31])||(temp_result[31]&&((!rs1[31])||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SUBX: begin
			rd<=rs1-rs2-icc_in[0];
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SUBXcc: begin
			temp_result=rs1-rs2-icc_in[0];
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=((rs1[31]&&(!rs2[31]))&&(!temp_result[31]))||(((!rs1[31])&&rs2[31])&&temp_result[31]);
			icc_out[0]<=((!rs1[31])&&rs2[31])||(temp_result[31]&&((!rs1[31])||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		TSUBcc: begin
			temp_result=rs1-rs2;
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=(((rs1[31]&&(!rs2[31]))&&(!temp_result[31]))||(((!rs1[31])&&rs2[31])&&temp_result[31]))||(rs1[1:0] || rs2[1:0]);
			icc_out[0]<=((!rs1[31])&&rs2[31])||(temp_result[31]&&((!rs1[31])||rs2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		TSUBccTV: begin
			temp_result=rs1-rs2;
			temp_V=(((rs1[31]&&(!rs2[31]))&&(!temp_result[31]))||(((!rs1[31])&&rs2[31])&&temp_result[31]))||(rs1[1:0] || rs2[1:0]);
			if(temp_V) begin
				tag_overflow<=1'b1;
			end
			else begin
				icc_out[3]<=temp_result[31];
				icc_out[2]<=(temp_result)? 1: 0;
				icc_out[1]<=temp_V;
				icc_out[0]<=((!rs1[31])&&rs2[31])||(temp_result[31]&&((!rs1[31])||rs2[31]));
				rd<=temp_result;
				tag_overflow<=1'b0;
			end
			division_by_zero<=1'b0;
		end
		
		//Multiply step
		MULScc: begin
			temp_result=operand1+operand2;
			Y_out<={rs1[0],Y_in[31:1]};
			rd<=temp_result;
			icc_out[3]<=temp_result[31];
			icc_out[2]<=(temp_result)? 1: 0;
			icc_out[1]<=((operand1[31]&&operand2[31])&&(!temp_result[31]))||(((!operand1[31])&&(!operand2[31]))&&temp_result[31]);
			icc_out[0]<=(operand1[31]&&operand2[31])||((!temp_result[31])&&(operand1[31]||operand2[31]));
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		
		//Multiply and divide unsigned
		UMUL: begin
			{Y_out,rd}<=rs1*rs2;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		UMULcc: begin
			temp_result_64<=rs1*rs2;
			{Y_out,rd}<=temp_result_64;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		UDIV: begin
			if(!rs2) begin
				division_by_zero<=1'b1;
			end
			else begin
				temp_result_64=div1/rs2;
				temp_V=(temp_result_64[63:32])? 1 : 0;
				if(temp_V) begin
					rd<=((2^^32)-1);
				end
				else begin
					rd<=temp_result_64[31:0];
				end
				icc_out<=4'd0;
				division_by_zero<=1'b0;
			end
			tag_overflow<=1'b0;
		end
		UDIVcc: begin
			if(!rs2) begin
				division_by_zero<=1'b1;
			end
			else begin
				temp_result_64=div1/rs2;
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
				division_by_zero<=1'b0;
			end
			tag_overflow<=1'b0;
		end	
	
		//Multiply and divide signed
		SMUL: begin
			{Y_out,rd}<=rs1_signed*rs2_signed;
			icc_out<=4'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SMULcc: begin
			temp_result_64<=rs1_signed*rs2_signed;
			{Y_out,rd}<=temp_result_64;
			icc_out[3]<=temp_result[31];
			icc_out[2]<= (temp_result==32'd0)? 1: 0;
			icc_out[1:0]=2'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
		SDIV: begin
			if(!rs2) begin
				division_by_zero<=1'b1;
			end
			else begin
				temp_result_64=div1_signed/rs2_signed;
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
				division_by_zero<=1'b0;
			end
			tag_overflow<=1'b0;
		end
		SDIVcc: begin
			if(!rs2) begin
				division_by_zero<=1'b1;
			end
			else begin
				temp_result_64=div1_signed/rs2_signed;
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
				division_by_zero<=1'b0;
			end
			tag_overflow<=1'b0;
		end	
		
		//Default is basically nothing happening
		default: begin
			icc_out<=4'd0;
			rd<=32'd0;
			division_by_zero<=1'b0;
			tag_overflow<=1'b0;
		end
	endcase
end

endmodule