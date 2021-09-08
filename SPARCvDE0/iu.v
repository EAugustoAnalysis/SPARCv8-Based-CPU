//Top level IU, interfaces with memory and stuff

//I'm following the LEON 2 XST integer unit model, but unpipelined and cacheless for now
// - FE - fetch instruction from memory. Instruction will be latched by the end, may not be implemented
// - DE - decode instruction, latch operands into place, calculate call and branch
// - EX - Perform ALU, logical, shift ops, calculate address of jump, rett, ld, st
// - ME - Read and store data. Data read is not written to the register yet, data stored is.
// - WR - write operations to register file

//Note: Chosen memory model is TSO
// Impacts to this module:
// - Flushing is not currently needed, we have a uniprocessor system with no cache, this will change
// - STBAR is NOP
// - This module is actually a submodule of a top level module called by tso.v

module iu (
	input wire clk, //clock
	input wire bp_reset_in, //reset
	
	input wire locked, //pll locked, reset signal is not complete until pll locked
	
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
	output wire pb_error, //Indicates processor is in error mode
	input wire [3:0] bp_IRL, //Interrupt request, level is 1-15 in ascending priority, normally 0
	
	//FPU and Coprocessor
	//We're not worrying about most of these because we don't actually have coprocessors
	output reg bp_FPU_present, //Is FPU present? No
	input wire bp_FPU_exception, //FPU exception assert. But it's not gonna
	input wire [1:0] bp_FPU_cc, //Condition codes for FPU branch instructions, from FPU status reg
	
	
	output reg bp_CP_present, //Is Coprocessor present? No
	input wire bp_CP_exception, //CP exception assert. But it's not gonna
	input wire [1:0] bp_CP_cc, //Condition codes for FPU branch instructions, from coprocessor status reg
	
	output wire reset_debug
);

/////////State Declarations/////////
parameter FETCH_MODE=0; //We turn off signals in fetch mode
parameter DECODE_MODE=1;
parameter EXECUTION_MODE=2;
parameter MEMORY_ACCESS_MODE=3;
parameter REGISTER_WRITE_MODE=4;

/////////ASI Declarations/////////

//Going to memory map a few ASI's
parameter USER_INST = 'h8;
parameter SUPER_INST = 'h9;
parameter USER_DAT = 'hA;
parameter SUPER_DAT = 'hB;

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
parameter LDSTUB_INST = 25; //Atomic
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
parameter RETT_INST = 56; //Privileged
parameter Ticc_INST = 57;
parameter RDASR_INST = 58;
parameter RDY_INST = 59;
parameter RDPSR_INST = 60;
parameter RDWIM_INST = 61;
parameter RDTBR_INST = 62;
parameter WRASR_INST = 63;
parameter WRY_INST = 64;
parameter WRPSR_INST = 65; //Privileged
parameter WRWIM_INST = 66; //Privileged
parameter WRTBR_INST = 67; //Privileged
parameter STBAR_INST = 68; //Unused, tso, write as nop
parameter FLUSH_INST = 69; //Unimplemented, we're using unimplemented_FLUSH
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
parameter LDUBA_INST=92; //Privileged
parameter LDUHA_INST=93; //Privileged
parameter LDDA_INST=94; //Privileged
parameter STA_INST=95; //Privileged
parameter STBA_INST=96; //Privileged
parameter STHA_INST=97; //Privileged
parameter STDA_INST=98; //Privileged
parameter LDSBA_INST=99; //Privileged
parameter LDSHA_INST=100; //Privileged
parameter LDSTUBA_INST=101; //Atomic, privileged
parameter SWAPA_INST=102; //Privileged

/////////Conditions/////////
//Not going to put definitions here, read the code or read B.21, they're universal
parameter C_A=4'b1000;
parameter C_N=4'b0000;
parameter C_NE=4'b1001;
parameter C_E=4'b0001; 
parameter C_G=4'b1010; 
parameter C_LE=4'b0010;
parameter C_GE=4'b1011;
parameter C_L=4'b0011;
parameter C_GU=4'b1100;
parameter C_LEU=4'b0100;
parameter C_CC=4'b1101;
parameter C_CS=4'b0101;
parameter C_POS=4'b1110;
parameter C_NEG=4'b0110;
parameter C_VC=4'b1111;
parameter C_VS=4'b0111;

/////////Instruction and Trap Variables/////////
//state
reg [3:0] state = FETCH_MODE;

//Mode
reg reset_mode=1'b1;
assign reset_debug=reset_mode;
reg error_mode=1'b0;
assign pb_error=error_mode; //Our PB error assertion
reg trap_mode=1'b0;
reg execute_mode=1'b0;

//Instruction type
reg [7:0] curr_inst_type=UNIMP_INST;

//Instruction annuller
reg annul=1'b0;

//Instruction input
reg [31:0] instruction_holder=32'd0;

//Portions of instruction declared and assigned
wire [1:0] inst_op;
assign inst_op=instruction_holder[31:30];
wire [2:0] inst_op2;
assign inst_op2=instruction_holder[24:22];
wire [5:0] inst_op3;
assign inst_op3=instruction_holder[24:19];
wire [8:0] inst_opf;
assign inst_opf=instruction_holder[13:5];
wire [8:0] inst_opc;
assign inst_opc=instruction_holder[13:5];
wire [7:0] inst_asi;
assign inst_asi=instruction_holder[12:5];
wire inst_i;
assign inst_i=instruction_holder[13];
wire [4:0] inst_rd;
assign inst_rd=instruction_holder[29:25];
wire inst_a;
assign inst_a=instruction_holder[29];
wire [3:0] inst_cond;
assign inst_cond=instruction_holder[28:25];
wire [4:0] inst_rs1;
assign inst_rs1=instruction_holder[18:14];
wire [4:0] inst_rs2;
assign inst_rs2=instruction_holder[4:0];
wire [12:0] inst_simm13;
assign inst_simm13=instruction_holder[12:0];
wire [4:0] inst_shcnt;
assign inst_shcnt=instruction_holder[4:0];
wire [29:0] inst_disp30;
assign inst_disp30=instruction_holder[29:0];
wire [21:0] inst_disp22;
assign inst_disp22=instruction_holder[21:0];
wire [21:0] inst_imm22;
assign inst_imm22=instruction_holder[21:0];
wire [6:0] inst_software_trap_num;
assign inst_software_trap_num=instruction_holder[6:0];

//fpu and cp
//Note that both of these are 0, this should not change
initial bp_FPU_present=1'b0;
initial bp_CP_present=1'b0;

//Traps
reg reset_trap=1'b0;
reg data_store_error=1'b0;
reg instruction_access_error=1'b0;
reg privileged_instruction=1'b0;
reg illegal_instruction=1'b0;
reg unimplemented_FLUSH=1'b0;
reg window_overflow=1'b0; //handled by module
reg window_underflow=1'b0; //handled by module
reg r_register_access_error=1'b0;
reg instruction_access_exception=1'b0;
reg fp_disabled=1'b0;
reg cp_disabled=1'b0;
reg fp_exception=1'b0;
reg cp_exception=1'b0;
reg mem_address_not_aligned=1'b0;
reg data_access_error=1'b0;
reg data_access_exception=1'b0;
wire tag_overflow_asserted;
wire division_by_zero_asserted;
reg tag_overflow=1'b0; //handled by module
reg division_by_zero=1'b0; //handled by module
reg trap_instruction=1'b0;

reg [3:0] interrupt_level = 4'd0;
reg trap=1'b0; //Not a type, handles the assertion of a trap

///////////////Regs///////////////

//ASR Registers
// - All required to be 32 bit regs
// - Can use some as clocks, timers, etc.
parameter NUMREGS=31; //Here so I can easily change the number of asr registers
reg [31:0] asr_regs[NUMREGS-1:0]; //The ASR registers, we have to initialize these on reset due to len

//Trap Base Register
reg [31:0] tbr=32'd0;
wire [7:0] tt;
wire [19:0] tba;
assign tba=tbr[31:12]; //Only field writable by wrtbr
assign tt=tbr[11:4];

//Y Register
reg [31:0] Y_reg=32'd0;

//PSR Register
reg [31:0] psr = {4'd0,4'd0,4'd0,1'd0,1'd0,4'd0,1'd1,1'd1,1'd0,4'd0};
wire [3:0] impl;
wire [3:0] ver;
wire [3:0] icc;
wire icc_N;
wire icc_Z;
wire icc_V;
wire icc_C;
wire EC;
wire EF;
wire [3:0] PIL;
wire S;
wire PS;
wire ET;
wire [3:0] CWP;
assign impl=psr[31:28];
assign ver=psr[27:24];
assign icc=psr[23:20];
assign icc_N=psr[23];
assign icc_Z=psr[22];
assign icc_V=psr[21];
assign icc_C=psr[20];
assign EC=psr[13];
assign EF=psr[12];
assign PIL=psr[11:8];
assign S=psr[7]; //Supervisor mode is on by default
assign PS=psr[6];
assign ET=psr[5]; //Traps are currently disabled for testing
assign CWP=psr[4:0];

//PC and nPC
reg [31:0] PC=31'd0;
reg [31:0] nPC=31'd0;

//Register window
parameter NWINDOWS=5'd3;
reg [31:0] WIM; //This is THE wim, it will be initialized properly on reset
wire [31:0] rs1;
wire [31:0] rs2;
reg [4:0] rd_sel=5'd0;
reg [31:0] next_rd=32'd0;
reg rd_wr=1'b0;



///////////////Variables///////////////
//ALU
wire [31:0] Y_result;
wire [3:0] icc_result;
wire [31:0] rd_result;
reg  [5:0] next_alu_opcode;


//Call/branch/jump/rett addresses
reg [31:0] branch_addr=32'd0; //Next call/branch address, written to nPC eventually

//General rs1 and rs2 for format 3 instructions
reg [31:0] rs_operand1;
reg [31:0] rs_operand2;

//Calculated address for format 3 instructions
reg [31:0] calculated_addr;


//Ticc stuff
reg [31:0] trap_num_extended;
reg [6:0] ticc_trap_type=7'd0;

//CWP stuff
reg [4:0] new_cwp;
	
///////////////Instances///////////////
alu alu(
	.rs1(rs_operand1),
	.rs2(rs_operand2),
	.rd(rd_result),
	.icc_in(icc),
	.icc_out(icc_result),
	.Y_in(Y_reg),
	.Y_out(Y_result),
	.alu_opcode(next_alu_opcode),
	.division_by_zero(division_by_zero_asserted),
	.tag_overflow(tag_overflow_asserted)
);

register_window rwin( //We handle save and restore here now
	.rst(bp_reset_in), //We'll leave the reset in for now, may remove
	
	.CWP_in(CWP),
	
	//This selection is kinda sus but technically works due to bit space coverage, we just discard result if not needed
	.r1_sel(inst_rs1),
	.r2_sel(inst_rs2),
	.rd_sel(rd_sel),
	
	.rd_in(next_rd),
	.rd_wr(rd_wr),
	
	.r1_out(rs1),
	.r2_out(rs2)
	
);

always @(posedge clk) begin //synchronous reset
	if(reset_mode) begin
		if(bp_reset_in) begin //Once the button clicky is over
			reset_mode<=1'b0;
			execute_mode<=1'b1;
			state<=FETCH_MODE;
			//Reset trap
			trap<=1'b1;
			reset_trap<=1'b1;
		end
	end
	else if(error_mode) begin
		if(~bp_reset_in) begin //Wait for them to clicky the button
			reset_mode<=1'b1;
			error_mode<=1'b0;
		end
	end
	else if(execute_mode) begin
		if(~bp_reset_in) begin //Wait for them to clicky the button
			reset_mode<=1'b1;
			error_mode<=1'b0;
			execute_mode<=1'b0;
		end
		else if((ET && bp_IRL==4'hFF) || (bp_IRL>PIL)) begin //Asynchronous resets
			trap<=1'b1;
			interrupt_level<=bp_IRL;
		end
		else if(trap) begin //It takes a clock cycle to assert a trap
			trap_mode<=1'b1;
			execute_mode<=1'b0;
		end
		else begin
			case(state)
				FETCH_MODE: begin //Actual fetch and MAE handler
					rd_wr<=1'b0; //Turn off register write
					if(~busy) begin
						if(S) ASI<=SUPER_INST;
						else ASI<=USER_INST;
						address<=PC;
						if(MAE & ~annul) begin //Memory access exceptions mean we get into trappin
							trap<=1'b1;
							instruction_access_exception<=1'b1;
						end
						else begin
							if(done) begin //When done we get into decode mode
								if(~annul) begin
									instruction_holder<=load_data;
									state<=DECODE_MODE;
								end
								else begin
									annul<=1'b0; //turn the annuller off
									PC<=nPC; //increment pc
									nPC<=32'd4+nPC;
									//Will not leave fetch mode until a non-annulled instruction is executed
								end
							end
						end
					end
				end
				DECODE_MODE: begin
					//Format 1 and 2 instructions
					//if call or branch, calc addr
					if(inst_op==2'b01 || (inst_op==2'b00 && inst_op2==3'd2)) begin
						if(inst_op==2'b01) curr_inst_type<=CALL_INST;
						else if(inst_op==2'b00 && inst_op2==3'd2) curr_inst_type<=Bicc_INST;
						branch_addr<=PC+{inst_disp30,2'b00};
					end
					
					//More format 2 instructions
					//Conditional branch type
					//My method saves logic but increases prop delay
					else if(inst_op==2'b00) begin
						case(inst_op2)
						3'd0: curr_inst_type<=UNIMP_INST;
						3'd4: curr_inst_type<=(!inst_imm22 && !inst_rd)? NOP_INST : SETHI_INST; //Nop is sethi with everything zero
						3'd6: curr_inst_type<=FBfcc_INST;
						3'd7: curr_inst_type<=CBccc_INST;
						endcase
					end
					
					
					
					//Now we get into format 3 instructions
					//In theory, since our register window is combinational, by the decode cycle,
					//all registers used should be selected automatically
					//We need to change this when we pipeline unless we load the instructions
					//through some kind of shift register.
					//Arithmetic, logical, shifts, special register reads, CP/FP ops
					else if(inst_op==2'b10 || inst_op==2'b11) begin
						rs_operand1<=rs1;
						//We don't care about the shift count case
						//If shift count is active we only take the last 5 bits anyways
						rs_operand2<=(inst_i)? {inst_simm13[12],19'd0,inst_simm13[11:0]} : rs2;
						
						if (inst_op==2'b10) begin
							case(inst_op3)
								6'h00: curr_inst_type<=ADD_INST;
								6'h10: curr_inst_type<=ADDcc_INST;
								6'h20: curr_inst_type<=TADDcc_INST;
								6'h30: curr_inst_type<=(inst_rd)? WRASR_INST : WRY_INST;
								6'h01: curr_inst_type<=AND_INST;
								6'h11: curr_inst_type<=ANDcc_INST;
								6'h21: curr_inst_type<=TSUBcc_INST;
								6'h31: curr_inst_type<=WRPSR_INST;
								6'h02: curr_inst_type<=OR_INST;
								6'h12: curr_inst_type<=ORcc_INST;
								6'h22: curr_inst_type<=TADDccTV_INST;
								6'h32: curr_inst_type<=WRWIM_INST;
								6'h03: curr_inst_type<=XOR_INST;
								6'h13: curr_inst_type<=XORcc_INST;
								6'h23: curr_inst_type<=TSUBccTV_INST;
								6'h33: curr_inst_type<=WRTBR_INST;
								6'h04: curr_inst_type<=SUB_INST;
								6'h14: curr_inst_type<=SUBcc_INST;
								6'h24: curr_inst_type<=MULScc_INST;
								6'h34: curr_inst_type<=FPop1_INST; //For both FPop1 and FPop2 this is the extent of our decoding here, no FPU implemented, see trap
								6'h05: curr_inst_type<=ANDN_INST;
								6'h15: curr_inst_type<=ANDNcc_INST;
								6'h25: curr_inst_type<=SLL_INST;
								6'h35: curr_inst_type<=FPop2_INST;
								6'h06: curr_inst_type<=ORN_INST;
								6'h16: curr_inst_type<=ORNcc_INST;
								6'h26: curr_inst_type<=SRL_INST;
								6'h36: curr_inst_type<=CPop1_INST;
								6'h07: curr_inst_type<=XNOR_INST;
								6'h17: curr_inst_type<=XNORcc_INST;
								6'h27: curr_inst_type<=SRA_INST;
								6'h37: curr_inst_type<=CPop2_INST;
								6'h08: curr_inst_type<=ADDX_INST;
								6'h18: curr_inst_type<=ADDXcc_INST;
								6'h28: begin
									if(inst_rs1!=5'd0 && inst_rs1!=5'd15) curr_inst_type<=RDASR_INST;
									else if(!inst_rs1) curr_inst_type<=RDY_INST;
									else if(inst_rs1==5'd15 && !inst_rd) curr_inst_type<=STBAR_INST;
									else curr_inst_type<=UNIMP_INST;
								end
								6'h38: curr_inst_type<=JMPL_INST;
								6'h09: curr_inst_type<=UNIMP_INST;
								6'h19: curr_inst_type<=UNIMP_INST;
								6'h29: curr_inst_type<=RDPSR_INST;
								6'h39: curr_inst_type<=RETT_INST;
								6'h0A: curr_inst_type<=UMUL_INST;
								6'h1A: curr_inst_type<=UMULcc_INST;
								6'h2A: curr_inst_type<=RDWIM_INST;
								6'h3A: begin //Ticc
									curr_inst_type<=Ticc_INST;
									trap_num_extended<=(inst_i)? {inst_software_trap_num[6],25'd0,inst_software_trap_num[5:0]} : rs2;
								end
								6'h0B: curr_inst_type<=SMUL_INST;
								6'h1B: curr_inst_type<=SMULcc_INST;
								6'h2B: curr_inst_type<=RDTBR_INST;
								6'h3B: curr_inst_type<=FLUSH_INST;
								6'h0C: curr_inst_type<=SUBX_INST;
								6'h1C: curr_inst_type<=SUBXcc_INST;
								6'h2C: curr_inst_type<=UNIMP_INST;
								6'h3C: curr_inst_type<=SAVE_INST;
								6'h0D: curr_inst_type<=UNIMP_INST;
								6'h1D: curr_inst_type<=UNIMP_INST;
								6'h2D: curr_inst_type<=UNIMP_INST;
								6'h3D: curr_inst_type<=RESTORE_INST;
								6'h0E: curr_inst_type<=UDIV_INST;
								6'h1E: curr_inst_type<=UDIVcc_INST;
								6'h2E: curr_inst_type<=UNIMP_INST;
								6'h3E: curr_inst_type<=UNIMP_INST;
								6'h0F: curr_inst_type<=SDIV_INST;
								6'h1F: curr_inst_type<=SDIVcc_INST;
								6'h2F: curr_inst_type<=UNIMP_INST;
								6'h3F: curr_inst_type<=UNIMP_INST;
								default: curr_inst_type<=UNIMP_INST;
							endcase
						end
						//Memory read/write, Atomic load store, swap
						else if(inst_op==2'b11) begin
							case(inst_op3)
								6'h00: curr_inst_type<=LD_INST;
								6'h10: curr_inst_type<=LDA_INST;
								6'h20: curr_inst_type<=LDF_INST;
								6'h30: curr_inst_type<=LDC_INST;
								6'h01: curr_inst_type<=LDUB_INST;
								6'h11: curr_inst_type<=LDUBA_INST;
								6'h21: curr_inst_type<=LDFSR_INST;
								6'h31: curr_inst_type<=LDCSR_INST;
								6'h02: curr_inst_type<=LDUH_INST;
								6'h12: curr_inst_type<=LDUHA_INST;
								6'h22: curr_inst_type<=UNIMP_INST;
								6'h32: curr_inst_type<=UNIMP_INST;
								6'h03: curr_inst_type<=LDD_INST;
								6'h13: curr_inst_type<=LDDA_INST;
								6'h23: curr_inst_type<=LDDF_INST;
								6'h33: curr_inst_type<=LDDC_INST;
								6'h04: curr_inst_type<=ST_INST;
								6'h14: curr_inst_type<=STA_INST;
								6'h24: curr_inst_type<=STF_INST;
								6'h34: curr_inst_type<=STC_INST;
								6'h05: curr_inst_type<=STB_INST;
								6'h15: curr_inst_type<=STBA_INST;
								6'h25: curr_inst_type<=STFSR_INST;
								6'h35: curr_inst_type<=STCSR_INST;
								6'h06: curr_inst_type<=STH_INST;
								6'h16: curr_inst_type<=STHA_INST;
								6'h26: curr_inst_type<=STDFQ_INST;
								6'h36: curr_inst_type<=STDCQ_INST;
								6'h07: curr_inst_type<=STD_INST;
								6'h17: curr_inst_type<=STDA_INST;
								6'h27: curr_inst_type<=STDF_INST;
								6'h37: curr_inst_type<=STDC_INST;
								6'h08: curr_inst_type<=UNIMP_INST;
								6'h18: curr_inst_type<=UNIMP_INST;
								6'h28: curr_inst_type<=UNIMP_INST;
								6'h38: curr_inst_type<=UNIMP_INST;
								6'h09: curr_inst_type<=LDSB_INST;
								6'h19: curr_inst_type<=LDSBA_INST;
								6'h29: curr_inst_type<=UNIMP_INST;
								6'h39: curr_inst_type<=UNIMP_INST;
								6'h0A: curr_inst_type<=LDSH_INST;
								6'h1A: curr_inst_type<=LDSHA_INST;
								6'h2A: curr_inst_type<=UNIMP_INST;
								6'h3A: curr_inst_type<=UNIMP_INST;
								6'h0B: curr_inst_type<=UNIMP_INST;
								6'h1B: curr_inst_type<=UNIMP_INST;
								6'h2B: curr_inst_type<=UNIMP_INST;
								6'h3B: curr_inst_type<=UNIMP_INST;
								6'h0C: curr_inst_type<=UNIMP_INST;
								6'h1C: curr_inst_type<=UNIMP_INST;
								6'h2C: curr_inst_type<=UNIMP_INST;
								6'h3C: curr_inst_type<=UNIMP_INST;
								6'h0D: curr_inst_type<=LDSTUB_INST;
								6'h1D: curr_inst_type<=LDSTUBA_INST;
								6'h2D: curr_inst_type<=UNIMP_INST;
								6'h3D: curr_inst_type<=UNIMP_INST;
								6'h0E: curr_inst_type<=UNIMP_INST;
								6'h1E: curr_inst_type<=UNIMP_INST;
								6'h2E: curr_inst_type<=UNIMP_INST;
								6'h3E: curr_inst_type<=UNIMP_INST;
								6'h0F: curr_inst_type<=SWAP_INST;
								6'h1F: curr_inst_type<=SWAPA_INST;
								6'h2F: curr_inst_type<=UNIMP_INST;
								6'h3F: curr_inst_type<=UNIMP_INST;
								default: curr_inst_type<=UNIMP_INST;
							endcase
						end
					end
					//Unimplemented instructions
					else if (inst_op==2'b00 && inst_op2==3'b000) begin
						curr_inst_type<=UNIMP_INST;
					end
					else begin //Note that this is for all unassigned instructions
						curr_inst_type<=UNIMP_INST;
						//Teeeechnically, this isn't an "unimplemented instruction", it's "illegal"
						//But I'm handling it the same
					end
					state<=EXECUTION_MODE;
				end
				EXECUTION_MODE: begin
					//Note: Not even going to bother to check if they're enabled
					//I don't want them enabling/disabling CP/FPU via WRPSR
					//Going to cause issues since they don't exist.
					
					//FPU instructions
					if(curr_inst_type==LDF_INST 
					|| curr_inst_type==LDDF_INST
					|| curr_inst_type==LDFSR_INST
					|| curr_inst_type==STF_INST
					|| curr_inst_type==STDF_INST
					|| curr_inst_type==STFSR_INST
					) begin //Load store
						trap<=1'b1;
						fp_disabled<=1'b1;
					end
					else if(curr_inst_type==STDFQ_INST) begin
						if(!S) begin
							trap<=1'b1;
							privileged_instruction<=1'b1;
						end
						else begin
							trap<=1'b1;
							fp_disabled<=1'b1;
						end
					end
					else if(curr_inst_type==FBfcc_INST) begin //branch
						trap<=1'b1;
						fp_disabled<=1'b1;
					end
					else if(curr_inst_type==FPop1_INST 
					|| curr_inst_type==FPop2_INST
					) begin //Math
						trap<=1'b1;
						fp_disabled<=1'b1;
					end
					
					//CP instructions
					else if(curr_inst_type==LDC_INST 
					|| curr_inst_type==LDDC_INST
					|| curr_inst_type==LDCSR_INST
					|| curr_inst_type==STC_INST
					|| curr_inst_type==STDC_INST
					|| curr_inst_type==STCSR_INST
					) begin //Load/store
						trap<=1'b1;
						cp_disabled<=1'b1;
					end
					else if(curr_inst_type==STDCQ_INST) begin
						if(!S) begin
							trap<=1'b1;
							privileged_instruction<=1'b1;
						end
						else begin
							trap<=1'b1;
							cp_disabled<=1'b1;
						end
					end
					else if(curr_inst_type==CBccc_INST) begin //Branch
						trap<=1'b1;
						cp_disabled<=1'b1;
					end
					else if(curr_inst_type==CPop1_INST
					|| curr_inst_type==CPop2_INST
					) begin //Math
						trap<=1'b1;
						cp_disabled<=1'b1;
					end
					
					//Illegal instructions
					else if(curr_inst_type==UNIMP_INST) begin
						illegal_instruction<=1'b1;
						trap<=1'b1;
					end
					
					//Now, some instructions that are legal and implemented
					//Note: This is where we take care of all the error and precalculation stuff for 
					//load, store, swap, and atomic load/store
					else if( curr_inst_type== LDSH_INST
					|| curr_inst_type== LDUB_INST
					|| curr_inst_type== LDUH_INST 
					|| curr_inst_type== LD_INST
					|| curr_inst_type== LDD_INST
					|| curr_inst_type== LDUBA_INST
					|| curr_inst_type== LDUHA_INST
					|| curr_inst_type== LDDA_INST
					|| curr_inst_type== STA_INST
					|| curr_inst_type== STBA_INST
					|| curr_inst_type== STHA_INST
					|| curr_inst_type== STDA_INST
					|| curr_inst_type== LDSBA_INST
					|| curr_inst_type== LDSHA_INST
					|| curr_inst_type== LDSTUBA_INST
					|| curr_inst_type== SWAP_INST
					|| curr_inst_type== SWAPA_INST
					|| curr_inst_type== STB_INST
					|| curr_inst_type== STH_INST
					|| curr_inst_type== ST_INST
					|| curr_inst_type== STD_INST
					|| curr_inst_type== RETT_INST
					|| curr_inst_type== JMPL_INST
					) begin
						calculated_addr <= rs_operand1 + rs_operand2;
					end
					
					//Ticc
					else if (curr_inst_type==Ticc_INST) begin
						if(((inst_cond==C_NE && !icc_Z) 
						|| (inst_cond==C_E && icc_Z)  
						|| (inst_cond==C_G && !(icc_Z || (icc_N ^ icc_V)))
						|| (inst_cond==C_LE && (icc_Z || (icc_N ^ icc_V)))
						|| (inst_cond==C_GE && !(icc_N ^ icc_V))
						|| (inst_cond==C_L && (icc_N ^ icc_V))
						|| (inst_cond==C_GU && (!icc_C && !icc_Z))
						|| (inst_cond==C_LEU && (icc_C || icc_Z))
						|| (inst_cond==C_CC && !icc_C)
						|| (inst_cond==C_CS && icc_C)
						|| (inst_cond==C_POS && !icc_N)
						|| (inst_cond==C_NEG && icc_N)
						|| (inst_cond==C_VC && !icc_V)
						|| (inst_cond==C_VS && icc_V)
						|| (inst_cond==C_A))
						&& (inst_cond!=C_N)
						) begin 
							trap<=1'b1;
							trap_instruction<=1'b1;
							ticc_trap_type<=trap_num_extended[6:0];
						end
					end
					
					//SAVE/RESTORE
					else if(curr_inst_type==SAVE_INST) begin
						new_cwp=(CWP-5'b1)%NWINDOWS;
						if((WIM & 2^^new_cwp) !=32'b0) begin
							trap<=1'b1;
							window_overflow<=1'b1;
						end
						else psr[4:0]<=new_cwp;
					end
					else if(curr_inst_type==RESTORE_INST) begin
						new_cwp=(CWP+5'b1)%NWINDOWS;
						if((WIM & 2^^new_cwp) !=32'b0) begin
							trap<=1'b1;
							window_underflow<=1'b1;
						end
						else psr[4:0]<=new_cwp;
					end
					
					
					//ALU/Shift/Logic
					//Not going to bother filtering this
					//Note that I realize that I'm kind of inconsistent with what I choose to store
					//and not store between stages.
					//I'd say for future implementations, an assumption that's fine to make
					//is that any pipeline stages when the design is pipelined will store
					//the current_inst_type and instruction_holder, and that these will be a vector later
					next_alu_opcode<=inst_op3;
					
					/* Some instructions that are legal but have no actions taken here
					 * + CALL & Bicc
					 * + NOP and (for this implementation) STBAR
					 * + SETHI
					 * + FLUSH (the unimplemented flush trap is not set)
					 */
					 
					/* Some instructions have their addresses calculated here (but nothing else)
					 * - SWAP
					 * - LD
					 * - ST
					 * - LDST (Atomic)
					 * + RETT
					 * + JMPL
					 */
					 
					/* Write Out Only
					 * + All ALU Ops need to be written out
					 * + Save/Restore needs to be written out
					 */
					state<=MEMORY_ACCESS_MODE;
				end
				MEMORY_ACCESS_MODE: begin
				
				
					state<=REGISTER_WRITE_MODE;
				end
				REGISTER_WRITE_MODE: begin
					//CALL
					if(curr_inst_type==CALL_INST) begin
						rd_sel<=5'd15;
						next_rd<=PC;
						rd_wr<=1'b1;
						PC<=nPC;
						nPC<=branch_addr;
					end
					
					//Bicc
					else if(curr_inst_type==Bicc_INST) begin
						PC<=nPC;
						if(((inst_cond==C_NE && !icc_Z) 
						|| (inst_cond==C_E && icc_Z)  
						|| (inst_cond==C_G && !(icc_Z || (icc_N ^ icc_V)))
						|| (inst_cond==C_LE && (icc_Z || (icc_N ^ icc_V)))
						|| (inst_cond==C_GE && !(icc_N ^ icc_V))
						|| (inst_cond==C_L && (icc_N ^ icc_V))
						|| (inst_cond==C_GU && (!icc_C && !icc_Z))
						|| (inst_cond==C_LEU && (icc_C || icc_Z))
						|| (inst_cond==C_CC && !icc_C)
						|| (inst_cond==C_CS && icc_C)
						|| (inst_cond==C_POS && !icc_N)
						|| (inst_cond==C_NEG && icc_N)
						|| (inst_cond==C_VC && !icc_V)
						|| (inst_cond==C_VS && icc_V)
						|| (inst_cond==C_A))
						&& (inst_cond!=C_N)
						) begin 
							nPC<=branch_addr;
							if(inst_cond==C_A && inst_a) annul<=1'b1;
						end
						else begin
							nPC<=nPC+32'd4;
							if(inst_a) annul<=1'b1;
						end
					end
					
					//FLUSH
					else if(curr_inst_type==FLUSH_INST) begin
						trap<=1'b1;
						unimplemented_FLUSH<=1'b1;
					end
					
					//SETHI
					else if(curr_inst_type==SETHI_INST) begin
						rd_sel<=inst_rd;
						next_rd<={inst_imm22,10'd0};
					end
					
					//RETT
					else if(curr_inst_type==RETT_INST) begin
						new_cwp=(CWP+5'b1)%NWINDOWS;
						if(ET) begin
							trap<=1'b1;
							if(!S) privileged_instruction<=1'b1;
							else illegal_instruction<=1'b1;
						end
						else begin
							if(!S) begin
								trap<=1'b1;
								privileged_instruction<=1'b1;
								execute_mode<=1'b0;
								error_mode<=1'b1;
								tbr[11:4]<=8'b00000011; //Privileged execution tt code
							end
							//We can't return from a trap and immediately trap again
							//According to the specs we have to error out no matter what
							else if((WIM & 2^^new_cwp) !=32'b0) begin
								execute_mode<=1'b0;
								error_mode<=1'b1;
								tbr[11:4]<=8'b00000110; //Window underflow tt code
								window_underflow<=1'b1;
							end
							else if(calculated_addr[1:0]!=0) begin
								execute_mode<=1'b0;
								error_mode<=1'b1;
								tbr[11:4]<=8'b00000111; //Address misalignment tt code
								mem_address_not_aligned<=1'b1;
							end
							else begin
								psr[5]<=1'b1; //ET<=1
								psr[7]<=PS; //S<=PS;
								nPC<=calculated_addr;
								PC<=nPC;
								psr[4:0]<=new_cwp;
							end
						end
					end
					
					else if(curr_inst_type==JMPL_INST) begin
						if(calculated_addr[1:0]!=0) begin
							trap<=1'b1;
							mem_address_not_aligned=1'b1;
						end
						else begin
							rd_sel<=inst_rd;
							if(inst_rd!=0) begin
								next_rd<=PC;
								rd_wr<=1'b1;
							end
							nPC<=calculated_addr;
							PC<=nPC;
						end
					end
					
					//SAVE/RESTORE write out
					else if(curr_inst_type==SAVE_INST) begin
						rd_sel<=inst_rd;
						next_rd<=rs_operand1+rs_operand2;
						rd_wr<=1'b1;
					end
					else if(curr_inst_type==RESTORE_INST) begin
						rd_sel<=inst_rd;
						next_rd<=rs_operand1+rs_operand2;
						rd_wr<=1'b1;
					end
					
					//Logical/Arithmetic/Divide instructions
					else if(curr_inst_type==AND_INST
					||curr_inst_type==ANDN_INST
					||curr_inst_type==OR_INST
					||curr_inst_type==ORN_INST
					||curr_inst_type==XOR_INST
					||curr_inst_type==XNOR_INST
					||curr_inst_type==SLL_INST
					||curr_inst_type==SRL_INST
					||curr_inst_type==SRA_INST
					||curr_inst_type==ADD_INST
					||curr_inst_type==ADDX_INST
					||curr_inst_type==SUB_INST
					||curr_inst_type==SUBX_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						rd_wr<=1'b1;
					end
					
					//Logical/Arithmetic/Divide instructions with icc
					else if(curr_inst_type==ADDcc_INST
					||curr_inst_type==ANDcc_INST
					||curr_inst_type==ORcc_INST
					||curr_inst_type==XORcc_INST
					||curr_inst_type==SUBcc_INST
					||curr_inst_type==ANDNcc_INST
					||curr_inst_type==ORNcc_INST
					||curr_inst_type==XNORcc_INST
					||curr_inst_type==ANDXcc_INST
					||curr_inst_type==TADDcc_INST
					||curr_inst_type==TSUBcc_INST
					||curr_inst_type==SUBXcc_INST
					||curr_inst_type==UDIVcc_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						psr[23:20]<=icc_result;
						rd_wr<=1'b1;
					end
					
					//Tag overflow instructions with icc
					else if(curr_inst_type==TSUBccTV_INST
					||curr_inst_type==TADDccTV_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						psr[23:20]<=icc_result;
						rd_wr<=1'b1;
						tag_overflow<=tag_overflow_asserted;
					end
					
					//Division
					else if(curr_inst_type==UDIV_INST
					||curr_inst_type==SDIV_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						rd_wr<=1'b1;
						division_by_zero<=division_by_zero_asserted;
					end
					
					//Division with icc
					else if(curr_inst_type==UDIVcc_INST
					||curr_inst_type==SDIVcc_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						psr[23:20]<=icc_result;
						rd_wr<=1'b1;
						division_by_zero<=division_by_zero_asserted;
					end
					
					//Multiply instructions
					else if(curr_inst_type==UMUL_INST
					||curr_inst_type==SMUL_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						rd_wr<=1'b1;
						Y_reg<=Y_result;
					end
					
					//Multiply instructions with icc
					else if(curr_inst_type==MULScc_INST
					||curr_inst_type==UMULcc_INST
					||curr_inst_type==SMULcc_INST
					) begin
						rd_sel<=inst_rd;
						next_rd<=rd_result;
						psr[23:20]<=icc_result;
						rd_wr<=1'b1;
						Y_reg<=Y_result;
					end
					
					//All other unspecified instructions
					//Note: We're removing FBfcc, CBccc,
					//and Ticc from this because I didn't give
					//em their own incrementations.
					
					//This kinda covers STBAR and NOP too
					//so we don't care about giving them their own.
					if (curr_inst_type!=CALL_INST
					&& curr_inst_type!=RETT_INST
					&& curr_inst_type!=JMPL_INST
					&& curr_inst_type!=Bicc_INST
					)begin
						PC<=nPC;
						nPC<=nPC+32'd4;
					end
					
					
					state<=FETCH_MODE;
				end
			endcase
		end
	end
end

endmodule