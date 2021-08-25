//Top level IU, interfaces with memory and stuff

//Implementing fetch/decode here

module iu (
	input wire clk, //clock
	input wire bp_reset_in, //reset
	
	//Memory interface
	input wire MAE, //Memory exception for both read and write
	input wire busy, //Busy signal for ram
	input wire done, //Done signal for ram
	output reg [31:0] address, //Memory address
	output reg [7:0] ASI, //ASI  asserted to memory manager 
	
	input wire [31:0] load_data, //For reads, data in
	
	output reg write_enable, //Write indicator
	output reg [3:0] byte_mask, //For writes, tells which bytes out of the 4 should be written out, for storing bytes and halfwords
	output reg [31:0] store_data, //For writes, data out
	
	output reg pb_block_ldst_word, //Word is being read/written to addr
	output reg pb_block_ldst_byte, //Byte is being read/written to addr
	
	//Exception stuff
	input wire pb_error, //Indicates processor is in error mode
	input wire [3:0] bp_IRL, //Interrupt request, level is 1-15 in ascending priority, normally 0
	
	//FPU and Coprocessor
	//We're not worrying about most of these because we don't actually have coprocessors
	output reg bp_FPU_present, //Is FPU present? No
	input wire bp_FPU_exception, //FPU exception assert. But it's not gonna
	input wire [1:0] bp_FPU_cc, //Condition codes for FPU branch instructions, from FPU status reg
	
	
	output reg bp_CP_present, //Is Coprocessor present? No
	input wire bp_CP_exception, //CP exception assert. But it's not gonna
	input wire [1:0] bp_CP_cc //Condition codes for FPU branch instructions, from coprocessor status reg
	
);

/////////State Declarations/////////
parameter RESET_MODE=0;
parameter ERROR_MODE=1;
parameter FETCH_MODE=2;
parameter DECODE_MODE=3;
parameter EXECUTION_MODE=5;
parameter TRAP_MODE=6;
parameter MEMORY_ACCESS=7;
parameter REGISTER_WRITE=8;

/////////ASI Declarations/////////

//Going to memory map a few ASI's
parameter USER_INST = 'h8;
parameter SUPER_INST = 'h9;
parameter USER_DAT = 'hA;
parameter SUPER_DAT = 'hB;

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


/////////State and Trap Variables/////////
//Instruction annuller
reg current_annul=1'b0;

//Instruction input
reg [31:0] load_inst_data=32'd0;

//Portions of instruction declared and assigned
wire [1:0] inst_op;
assign inst_op=load_inst_data[31:30];
wire [2:0] inst_op2;
assign inst_op2=load_inst_data[24:22];
wire [5:0] inst_op3;
assign inst_op3=load_inst_data[24:19];
wire [8:0] inst_opf;
assign inst_opf=load_inst_data[13:5];
wire [8:0] inst_opc;
assign inst_opc=load_inst_data[13:5];
wire [7:0] inst_asi;
assign inst_asi=load_inst_data[12:5];
wire inst_i;
assign inst_i=load_inst_data[13];
wire [4:0] inst_rd;
assign inst_rd=load_inst_data[29:25];
wire inst_a;
assign inst_a=load_inst_data[29];
wire [3:0] inst_cond;
assign inst_cond=load_inst_data[28:25];
wire [4:0] inst_rs1;
assign inst_rs1=load_inst_data[18:14];
wire [4:0] inst_rs2;
assign inst_rs2=load_inst_data[4:0];
wire [12:0] inst_simm13;
assign inst_simm13=load_inst_data[12:0];
wire [4:0] inst_shcnt;
assign inst_shcnt=load_inst_data[4:0];
wire [29:0] inst_disp30;
assign inst_disp30=load_inst_data[29:0];
wire [21:0] inst_disp22;
assign inst_disp22=load_inst_data[21:0];
wire [6:0] inst_software_trap_num;
assign inst_software_trap_num=load_inst_data[6:0];


//alu stuff
reg [31:0] alu_rs1=32'd0; //reg1 value is pushed here
reg [31:0] alu_op2=32'd0; //For sign extension of imm



//Default state
reg [3:0] state = RESET_MODE;

//Trap
reg trap_asserted=1'b0;

//fpu and cp
//Note that both of these are 0;
initial bp_FPU_present=1'b0;
initial bp_CP_present=1'b0;



//Traps not in other modules
reg reset_trap=1'b0;
reg instruction_access_exception=1'b0;
reg fpu_disabled=1'b0;
reg cp_disabled=1'b0;

//Trap instruction stuff, used by trap handler
reg [7:0] next_tt=8'd0;
reg tt_wr=1'b0;
wire [31:0] current_tbr;
wire [7:0] current_tt;


/////////Internal Signals and Variables/////////

//Trap register signal, used by WRTBR
reg tbr_wr=1'b0;
reg [31:0] next_tbr=32'd0;

//PSR stuff
wire current_ET;
wire [3:0] current_PIL;
wire current_S;
reg [3:0] next_PIL;
wire current_EF; //Both of these should always be 0, but it doesn't matter, they're unimplemented
wire current_EC;

//PC/nPC stuff
wire [31:0] current_PC;
reg PC_inc=1'b0;


/////////Instances/////////
trap_base_register tbr(
	.clk(clk),
	.rst(bp_reset_in),
	.tbr_in(next_tbr),
	.tbr_out(current_tbr),
	.tt_out(current_tt),
	.tt_in(next_tt),
	.tt_wr(tt_wr),
	.tbr_wr(tbr_wr)
);


always @(posedge clk or negedge bp_reset_in) begin
	case(state)
	//This is where it gets weird, reset is considered a trap,
	//so it must go through the trap process, meaning going through the execute state,
	//setting the FSM to trap mode, and getting into trap mode
	//However, the trap mode does barely anything, 
	//because reset traps do not handle the reset signal
	RESET_MODE: begin 
		trap_asserted<=1'b1;
		state<=FETCH_MODE; //fetch mode handles our exceptions
		reset_trap<=1'b1;
	end
	ERROR_MODE: begin
		if(~bp_reset_in) state<=RESET_MODE;
	end
	FETCH_MODE: begin
		PC_inc<=1'b0; //Turn the PC increment off
		if(current_ET && (bp_IRL==4'b1111  || bp_IRL>current_PIL)) begin //Asynchronous interrupt trap state
			state<=TRAP_MODE;
			next_PIL<=bp_IRL;
		end
		else begin
			if(trap_asserted) begin //General trap state
				state<=TRAP_MODE;
			end
			else begin //Actual fetch and MAE handler
				if(~busy) begin //If not busy make changes, else just cycle
					ASI<=SUPER_INST;
					address<=current_PC;
					if(MAE & ~current_annul) begin //Memory access exceptions mean we get into trappin
						state<=TRAP_MODE;
						instruction_access_exception<=1'b1;
					end
					else begin
						if(done) begin //When done we get into decode mode
							if(~current_annul) begin
								load_inst_data<=load_data;
								state<=DECODE_MODE;
							end
							else begin
								current_annul<=1'b0; //turn the annuller off
								PC_inc<=1'b1; //increment pc
							end
						end
					end
				end
			end
		end
	end
	DECODE_MODE: begin
		
	end
	EXECUTION_MODE: begin
		
	end
	TRAP_MODE: begin
		
	end
	MEMORY_ACCESS: begin
		
	end
	REGISTER_WRITE: begin
		
	end
	
	//Better not be a default case
	endcase
end

endmodule