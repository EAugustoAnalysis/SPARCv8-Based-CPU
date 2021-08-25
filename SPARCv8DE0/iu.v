//Top level IU, interfaces with memory and stuff

//Implementing fetch/decode here
//This is unpipelined, currently a state machine
//However its stages are very similar to LEON2 XST's pipeline stages
//Some important differences and notes: 
// - instructions are not guarunteed to be valid at the end of a fetch, as decode does a bit of the work
// - It's not super imperative to this design whether call and branch are decided in decode but I will anyways
//   for later pipelining ease later
// - CBccc and FBccc instructions are not calculated at all
// - Execution mode handles setting all of the initial traps related to unimplemented instructions
// - Extra mode that turns off all write signals

//Note: Chosen memory model is TSO
// Impacts to this module:
// - Flush is an external signal
// - STBAR is 0
// - This module is actually a submodule of a top level module called by sparcv8de0.v

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
	input wire [1:0] bp_CP_cc, //Condition codes for FPU branch instructions, from coprocessor status reg
	
	output reg local_flush_asserted, //For integer flush
	
	//Debug stuff
	output wire [3:0] state_out //for reset led's
	
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
parameter TURN_OFF_SIGNALS=9;

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

/////////Instruction Types/////////
//Implemented
parameter UNIMP_INST = 0;
parameter LDSB_INST = 1;
parameter LDSH_INST = 2;
parameter LDUB_INST = 3;
parameter LDUH_INST = 4;
parameter LD_INST = 5;
parameter LDD_INST = 6;
parameter LDF_INST = 7; //Unused, fpu/cp
parameter LDDF_INST = 8; //Unused, fpu/cp
parameter LDFSR_INST = 9; //Unused, fpu/cp
parameter LDC_INST = 10; //Unused, fpu/cp
parameter LDDC_INST = 11; //Unused, fpu/cp
parameter LDCSR_INST = 12; //Unused, fpu/cp
parameter STB_INST = 13;
parameter STH_INST = 14;
parameter ST_INST = 15;
parameter STD_INST = 16;
parameter STF_INST = 17; //Unused, fpu/cp
parameter STDF_INST = 18; //Unused, fpu/cp
parameter STFSR_INST = 19; //Unused, fpu/cp
parameter STDFQ_INST = 20; //Unused, fpu/cp
parameter STC_INST = 21; //Unused, fpu/cp
parameter STDC_INST = 22; //Unused, fpu/cp
parameter STCSR_INST = 23; //Unused, fpu/cp
parameter STDCQ_INST = 24; //Unused, fpu/cp
parameter LDSTUB_INST = 25;
parameter SWAP_INST = 26;
parameter SETHI_INST = 27;
parameter NOP_INST = 28;
parameter AND_INST = 29;
parameter ANDN_INST = 30;
parameter OR_INST = 31;
parameter ORN_INST = 32;
parameter XOR_INST = 33;
parameter XNOR_INST = 34;
parameter SLL_INST = 35;
parameter SRL_INST = 36;
parameter SRA_INST = 37;
parameter ADD_INST = 38;
parameter ADDX_INST = 39;
parameter TADDcc_INST = 40;
parameter SUB_INST = 41;
parameter SUBX_INST = 42;
parameter TSUBcc_INST = 43;
parameter MULScc_INST = 44;
parameter UMUL_INST = 45;
parameter SMUL_INST = 46;
parameter UDIV_INST = 47;
parameter SDIV_INST = 48;
parameter SAVE_INST = 49;
parameter RESTORE_INST = 50;
parameter Bicc_INST = 51;
parameter FBfcc_INST = 52; //Unused, fpu/cp
parameter CBccc_INST = 53; //Unused, fpu/cp
parameter CALL_INST = 54;
parameter JMPL_INST = 55;
parameter RETT_INST = 56;
parameter Ticc_INST = 57;
parameter RDASR_INST = 58;
parameter RDY_INST = 59;
parameter RDPSR_INST = 60;
parameter RDWIM_INST = 61;
parameter RDTBR_INST = 62;
parameter WRASR_INST = 63;
parameter WRY_INST = 64;
parameter WRPSR_INST = 65;
parameter WRWIM_INST = 66;
parameter WRTBR_INST = 67;
parameter STBAR_INST = 68; //Unused, tso, write as nop
parameter FLUSH_INST = 69;
parameter FPop1_INST = 70; //Unused, fpu/cp
parameter FPop2_INST = 71; //Unused, fpu/cp
parameter CPop1_INST = 72; //Unused, fpu/cp
parameter CPop2_INST = 73; //Unused, fpu/cp
parameter LDA_INST=74; //Atomic
parameter ADDcc_INST=75;
parameter ANDcc_INST=76;
parameter ORcc_INST=77;
parameter TADDccTV_INST=78;
parameter XORcc_INST=79;
parameter TSUBccTV_INST=80;
parameter SUBcc_INST=81;
parameter ANDNcc_INST=82;
parameter ORNcc_INST=83;
parameter XNORcc_INST=84;
parameter ANDXcc_INST=85;
parameter UMULcc_INST=86;
parameter SMULcc_INST=87;
parameter SUBXcc_INST=88;
parameter UDIVcc_INST=89;
parameter SDIVcc_INST=90;
parameter ADDXcc_INST=91;
parameter LDUBA_INST=92; //Atomic
parameter LDUHA_INST=93; //Atomic
parameter LDDA_INST=94; //Atomic
parameter STA_INST=95; //Atomic
parameter STBA_INST=96; //Atomic
parameter STHA_INST=97; //Atomic
parameter STDA_INST=98; //Atomic
parameter LDSBA_INST=99; //Atomic
parameter LDSHA_INST=100; //Atomic
parameter LDSTUBA_INST=101; //Atomic
parameter SWAPA_INST=102; //Atomic

/////////Branch Conditions/////////
//Not going to put definitions here, read the code or read B.21
parameter BA=4'b1000;
parameter BN=4'b0000;
parameter BNE=4'b1001;
parameter BE=4'b0001; 
parameter BG=4'b1010; 
parameter BLE=4'b0010;
parameter BGE=4'b1011;
parameter BL=4'b0011;
parameter BGU=4'b1100;
parameter BLEU=4'b0100;
parameter BCC=4'b1101;
parameter BCS=4'b0101;
parameter BPOS=4'b1110;
parameter BNEG=4'b0110;
parameter BVC=4'b1111;
parameter BVS=4'b0111;

/////////Integer Trap Conditions/////////
//Not going to put definitions here, read the code or read B.21, same conditions
parameter TA=4'b1000;
parameter TN=4'b0000;
parameter TNE=4'b1001;
parameter TE=4'b0001; 
parameter TG=4'b1010; 
parameter TLE=4'b0010;
parameter TGE=4'b1011;
parameter TL=4'b0011;
parameter TGU=4'b1100;
parameter TLEU=4'b0100;
parameter TCC=4'b1101;
parameter TCS=4'b0101;
parameter TPOS=4'b1110;
parameter TNEG=4'b0110;
parameter TVC=4'b1111;
parameter TVS=4'b0111;

/////////State and Trap Variables/////////
//Instruction type
reg [7:0] curr_INST_type=UNIMP_INST;

//Instruction annuller
reg current_annul=1'b0;

//Instruction input
reg [31:0] load_INST_data=32'd0;

//Portions of instruction declared and assigned
wire [1:0] inst_op;
assign inst_op=load_INST_data[31:30];
wire [2:0] inst_op2;
assign inst_op2=load_INST_data[24:22];
wire [5:0] inst_op3;
assign inst_op3=load_INST_data[24:19];
wire [8:0] inst_opf;
assign inst_opf=load_INST_data[13:5];
wire [8:0] inst_opc;
assign inst_opc=load_INST_data[13:5];
wire [7:0] inst_asi;
assign inst_asi=load_INST_data[12:5];
wire inst_i;
assign inst_i=load_INST_data[13];
wire [4:0] inst_rd;
assign inst_rd=load_INST_data[29:25];
wire inst_a;
assign inst_a=load_INST_data[29];
wire [3:0] inst_cond;
assign inst_cond=load_INST_data[28:25];
wire [4:0] inst_rs1;
assign inst_rs1=load_INST_data[18:14];
wire [4:0] inst_rs2;
assign inst_rs2=load_INST_data[4:0];
wire [12:0] inst_simm13;
assign inst_simm13=load_INST_data[12:0];
wire [4:0] inst_shcnt;
assign inst_shcnt=load_INST_data[4:0];
wire [29:0] inst_disp30;
assign inst_disp30=load_INST_data[29:0];
wire [21:0] inst_disp22;
assign inst_disp22=load_INST_data[21:0];
wire [21:0] inst_imm22;
assign inst_imm22=load_INST_data[21:0];
wire [6:0] inst_software_trap_num;
assign inst_software_trap_num=load_INST_data[6:0];


//alu stuff
reg [31:0] alu_rs1=32'd0; //reg1 value is pushed here
reg [31:0] alu_op2=32'd0; //For sign extension of imm



//Default state
reg [3:0] state = RESET_MODE;
assign state_out=state;

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
reg illegal_instruction=1'b0;

//Trap instruction stuff, used by trap handler
reg [7:0] next_tt=8'd0;
reg tt_wr=1'b0;
wire [31:0] current_tbr;
wire [7:0] current_tt;


/////////Internal Signals and Variables/////////

//Conditional signal
wire cond_sat;

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

wire current_N; //ICC
wire current_Z;
wire current_V;
wire current_C;

//PC/nPC stuff
wire [31:0] current_PC;
reg next_nPC;
reg nPC_wr;
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
	if(~bp_reset_in) begin //Our legally mandated asynchronous reset
		state<=RESET_MODE;
	end
	else begin
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
									load_INST_data<=load_data;
									state<=DECODE_MODE;
								end
								else begin
									current_annul<=1'b0; //turn the annuller off
									PC_inc<=1'b1; //increment pc
									//Will not leave fetch mode until a non-annulled instruction is executed
								end
							end
						end
					end
				end
			end
		end
		DECODE_MODE: begin
			//CALL Handler
			//Calculates NPC but does not write yet, might be abandoned (will not, no pipeline)
			//Note that r15 has to be set to the current PC later, in the write out
			if(inst_op==2'b01) begin
				curr_INST_type<=CALL_INST;
				next_nPC<=current_PC+{inst_disp30,2'b00}; //Pretty sure this is what they mean
				//Documentation is pretty weird here
			end
			
			//Conditional branch type
			//My method saves logic but increases prop delay
			if(inst_op==2'b00) begin
				case(inst_op)
				2'd0: curr_INST_type<=UNIMP_INST;
				2'd2: begin
					//This is the only one where we care about calculation
					curr_INST_type<=Bicc_INST;
					if(inst_a) begin //Annuller
							current_annul<=1'b1;
							state<=FETCH_MODE;
					end
					else begin
						if((inst_cond==BNE && !current_Z) 
						|| (inst_cond==BE && current_Z)  
						|| (inst_cond==BG && !(current_Z || (current_N ^ current_V)))
						|| (inst_cond==BLE && (current_Z || (current_N ^ current_V)))
						|| (inst_cond==BGE && !(current_N ^ current_V))
						|| (inst_cond==BL && (current_N ^ current_V))
						|| (inst_cond==BGU && (!current_C && !current_Z))
						|| (inst_cond==BLEU && (current_C || current_Z))
						|| (inst_cond==BCC && !current_C)
						|| (inst_cond==BCS && current_C)
						|| (inst_cond==BPOS && !current_N)
						|| (inst_cond==BNEG && current_N)
						|| (inst_cond==BVC && !current_V)
						|| (inst_cond==BVS && current_V)
						|| (inst_cond==BA)
						|| (inst_cond!=BN)
						) begin 
							next_nPC<=current_PC+{inst_disp30,2'b00};
						end
					end
				end
				2'd4: curr_INST_type<=(!inst_imm22 && !inst_rd)? NOP_INST : SETHI_INST; //Nop is sethi with everything zero
				2'd6: curr_INST_type<=FBfcc_INST;
				2'd7: curr_INST_type<=CBccc_INST;
				endcase
			end
			
			//Arithmetic, logical, shifts, special register reads, CP/FP ops
			else if (inst_op==2'b10) begin
				case(inst_op3)
					6'h00: curr_INST_type<=ADD_INST;
					6'h10: curr_INST_type<=ADDcc_INST;
					6'h20: curr_INST_type<=TADDcc_INST;
					6'h30: curr_INST_type<=(inst_rd)? WRASR_INST : WRY_INST;
					6'h01: curr_INST_type<=AND_INST;
					6'h11: curr_INST_type<=ANDcc_INST;
					6'h21: curr_INST_type<=TSUBcc_INST;
					6'h31: curr_INST_type<=WRPSR_INST;
					6'h02: curr_INST_type<=OR_INST;
					6'h12: curr_INST_type<=ORcc_INST;
					6'h22: curr_INST_type<=TADDccTV_INST;
					6'h32: curr_INST_type<=WRWIM_INST;
					6'h03: curr_INST_type<=XOR_INST;
					6'h13: curr_INST_type<=XORcc_INST;
					6'h23: curr_INST_type<=TSUBccTV_INST;
					6'h33: curr_INST_type<=WRTBR_INST;
					6'h04: curr_INST_type<=SUB_INST;
					6'h14: curr_INST_type<=SUBcc_INST;
					6'h24: curr_INST_type<=MULScc_INST;
					6'h34: curr_INST_type<=FPop1_INST; //For both FPop1 and FPop2 this is the extent of our decoding here, no FPU implemented, see trap
					6'h05: curr_INST_type<=ANDN_INST;
					6'h15: curr_INST_type<=ANDNcc_INST;
					6'h25: curr_INST_type<=SLL_INST;
					6'h35: curr_INST_type<=FPop2_INST;
					6'h06: curr_INST_type<=ORN_INST;
					6'h16: curr_INST_type<=ORNcc_INST;
					6'h26: curr_INST_type<=SRL_INST;
					6'h36: curr_INST_type<=CPop1_INST;
					6'h07: curr_INST_type<=XNOR_INST;
					6'h17: curr_INST_type<=XNORcc_INST;
					6'h27: curr_INST_type<=SRA_INST;
					6'h37: curr_INST_type<=CPop2_INST;
					6'h08: curr_INST_type<=ADDX_INST;
					6'h18: curr_INST_type<=ADDXcc_INST;
					6'h28: begin
						if(inst_rs1!=5'd0 && inst_rs1!=5'd15) curr_INST_type<=RDASR_INST;
						else if(!inst_rs1) curr_INST_type<=RDY_INST;
						else if(inst_rs1==5'd15 && !inst_rd) curr_INST_type<=STBAR_INST;
						else curr_INST_type<=UNIMP_INST;
					end
					6'h38: curr_INST_type<=JMPL_INST;
					6'h09: curr_INST_type<=UNIMP_INST;
					6'h19: curr_INST_type<=UNIMP_INST;
					6'h29: curr_INST_type<=RDPSR_INST;
					6'h39: curr_INST_type<=RETT_INST;
					6'h0A: curr_INST_type<=UMUL_INST;
					6'h1A: curr_INST_type<=UMULcc_INST;
					6'h2A: curr_INST_type<=RDWIM_INST;
					6'h3A: curr_INST_type<=Ticc_INST;
					6'h0B: curr_INST_type<=SMUL_INST;
					6'h1B: curr_INST_type<=SMULcc_INST;
					6'h2B: curr_INST_type<=RDTBR_INST;
					6'h3B: curr_INST_type<=FLUSH_INST;
					6'h0C: curr_INST_type<=SUBX_INST;
					6'h1C: curr_INST_type<=SUBXcc_INST;
					6'h2C: curr_INST_type<=UNIMP_INST;
					6'h3C: curr_INST_type<=SAVE_INST;
					6'h0D: curr_INST_type<=UNIMP_INST;
					6'h1D: curr_INST_type<=UNIMP_INST;
					6'h2D: curr_INST_type<=UNIMP_INST;
					6'h3D: curr_INST_type<=RESTORE_INST;
					6'h0E: curr_INST_type<=UDIV_INST;
					6'h1E: curr_INST_type<=UDIVcc_INST;
					6'h2E: curr_INST_type<=UNIMP_INST;
					6'h3E: curr_INST_type<=UNIMP_INST;
					6'h0F: curr_INST_type<=SDIV_INST;
					6'h1F: curr_INST_type<=SDIVcc_INST;
					6'h2F: curr_INST_type<=UNIMP_INST;
					6'h3F: curr_INST_type<=UNIMP_INST;
					default: curr_INST_type<=UNIMP_INST;
				endcase
			end
			
			//Memory read/write, Atomic load store, swap
			else if(inst_op==2'b11) begin
				case(inst_op3)
					6'h00: curr_INST_type<=LD_INST;
					6'h10: curr_INST_type<=LDA_INST;
					6'h20: curr_INST_type<=LDF_INST;
					6'h30: curr_INST_type<=LDC_INST;
					6'h01: curr_INST_type<=LDUB_INST;
					6'h11: curr_INST_type<=LDUBA_INST;
					6'h21: curr_INST_type<=LDFSR_INST;
					6'h31: curr_INST_type<=LDCSR_INST;
					6'h02: curr_INST_type<=LDUH_INST;
					6'h12: curr_INST_type<=LDUHA_INST;
					6'h22: curr_INST_type<=UNIMP_INST;
					6'h32: curr_INST_type<=UNIMP_INST;
					6'h03: curr_INST_type<=LDD_INST;
					6'h13: curr_INST_type<=LDDA_INST;
					6'h23: curr_INST_type<=LDDF_INST;
					6'h33: curr_INST_type<=LDDC_INST;
					6'h04: curr_INST_type<=ST_INST;
					6'h14: curr_INST_type<=STA_INST;
					6'h24: curr_INST_type<=STF_INST;
					6'h34: curr_INST_type<=STC_INST;
					6'h05: curr_INST_type<=STB_INST;
					6'h15: curr_INST_type<=STBA_INST;
					6'h25: curr_INST_type<=STFSR_INST;
					6'h35: curr_INST_type<=STCSR_INST;
					6'h06: curr_INST_type<=STH_INST;
					6'h16: curr_INST_type<=STHA_INST;
					6'h26: curr_INST_type<=STDFQ_INST;
					6'h36: curr_INST_type<=STDCQ_INST;
					6'h07: curr_INST_type<=STD_INST;
					6'h17: curr_INST_type<=STDA_INST;
					6'h27: curr_INST_type<=STDF_INST;
					6'h37: curr_INST_type<=STDC_INST;
					6'h08: curr_INST_type<=UNIMP_INST;
					6'h18: curr_INST_type<=UNIMP_INST;
					6'h28: curr_INST_type<=UNIMP_INST;
					6'h38: curr_INST_type<=UNIMP_INST;
					6'h09: curr_INST_type<=LDSB_INST;
					6'h19: curr_INST_type<=LDSBA_INST;
					6'h29: curr_INST_type<=UNIMP_INST;
					6'h39: curr_INST_type<=UNIMP_INST;
					6'h0A: curr_INST_type<=LDSH_INST;
					6'h1A: curr_INST_type<=LDSHA_INST;
					6'h2A: curr_INST_type<=UNIMP_INST;
					6'h3A: curr_INST_type<=UNIMP_INST;
					6'h0B: curr_INST_type<=UNIMP_INST;
					6'h1B: curr_INST_type<=UNIMP_INST;
					6'h2B: curr_INST_type<=UNIMP_INST;
					6'h3B: curr_INST_type<=UNIMP_INST;
					6'h0C: curr_INST_type<=UNIMP_INST;
					6'h1C: curr_INST_type<=UNIMP_INST;
					6'h2C: curr_INST_type<=UNIMP_INST;
					6'h3C: curr_INST_type<=UNIMP_INST;
					6'h0D: curr_INST_type<=LDSTUB_INST;
					6'h1D: curr_INST_type<=LDSTUBA_INST;
					6'h2D: curr_INST_type<=UNIMP_INST;
					6'h3D: curr_INST_type<=UNIMP_INST;
					6'h0E: curr_INST_type<=UNIMP_INST;
					6'h1E: curr_INST_type<=UNIMP_INST;
					6'h2E: curr_INST_type<=UNIMP_INST;
					6'h3E: curr_INST_type<=UNIMP_INST;
					6'h0F: curr_INST_type<=SWAP_INST;
					6'h1F: curr_INST_type<=SWAPA_INST;
					6'h2F: curr_INST_type<=UNIMP_INST;
					6'h3F: curr_INST_type<=UNIMP_INST;
					default: curr_INST_type<=UNIMP_INST;
				endcase
			end
			
			//Unimplemented instructions
			else if (inst_op==2'b00 && inst_op2==3'b000) begin
				curr_INST_type<=UNIMP_INST;
			end
			else begin //Note that this is for all unassigned instructions
				curr_INST_type<=UNIMP_INST;
				//Teeeechnically, this isn't an "unimplemented instruction", it's "illegal"
				//But I'm handling it the same
			end
			
			//Execution mode handles all traps related to instruction type
			//If annuller is on, we go back to fetch
			if(~current_annul) state<=EXECUTION_MODE;
		end
		EXECUTION_MODE: begin
			//Not even going to bother to check if they're enabled
			//I don't want them enabling/disabling CP/FPU via WRPSR
			//Going to cause issues since they don't exist.
			
			//FPU instructions
			if(curr_INST_type==LDF_INST 
			|| curr_INST_type==LDDF_INST
			|| curr_INST_type==LDFSR_INST
			|| curr_INST_type==STF_INST
			|| curr_INST_type==STDF_INST
			|| curr_INST_type==STFSR_INST
			|| curr_INST_type==STDFQ_INST
			) begin //Load store
				state<=TRAP_MODE;
				fpu_disabled<=1'b1;
			end
			else if(curr_INST_type==FBfcc_INST) begin //branch
				state<=TRAP_MODE;
				fpu_disabled<=1'b1;
			end
			else if(curr_INST_type==FPop1_INST 
			|| curr_INST_type==FPop2_INST
			) begin //Math
				state<=TRAP_MODE;
				fpu_disabled<=1'b1;
			end
			
			//CP instructions
			if(curr_INST_type==LDC_INST 
			|| curr_INST_type==LDDC_INST
			|| curr_INST_type==LDCSR_INST
			|| curr_INST_type==STC_INST
			|| curr_INST_type==STDC_INST
			|| curr_INST_type==STCSR_INST
			|| curr_INST_type==STDCQ_INST
			) begin //Load/store
				state<=TRAP_MODE;
				cp_disabled<=1'b1;
			end
			else if(curr_INST_type==CBccc_INST) begin //Branch
				state<=TRAP_MODE;
				cp_disabled<=1'b1;
			end
			else if(curr_INST_type==CPop1_INST
			|| curr_INST_type==CPop2_INST
			) begin //Math
				state<=TRAP_MODE;
				cp_disabled<=1'b1;
			end
			
			//Illegal instructions
			else if(curr_INST_type==UNIMP_INST) begin
				illegal_instruction<=1'b1;
				state<=TRAP_MODE;
			end
		end
		
		MEMORY_ACCESS: begin
			
		end
		REGISTER_WRITE: begin
		//This is where we put the "if instruction not CALL, RETT, JMPL, BiCC, TiCC" thing.
		//We don't care about FBfcc or CBccc because fpu doesn't exist
		
		end
		
		TURN_OFF_SIGNALS: begin
		//This is where we turn off all register write signals
			
		end
		
		TRAP_MODE: begin
			
		end
		
		//Better not be a default case
		endcase
	end
end

endmodule