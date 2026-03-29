`timescale 1ns / 1ps

module fpadder2c2(
input [15:0] fpa,
input [15:0] fpb,
input i1,
input ctrl,
output  [15:0] fpo);

//exponent: fpa[14:10]
//mantissa: fpa[9:0]
//sign fpa [15]


wire [4:0] diff; 
wire ma_lesthn_mb, ea_equal_eb,ea_lesthn_eb;
wire [15:0] big, smal;
wire [10:0] shifted_msmal;
wire sub;
wire [11:0] m_sumdiff;
reg [11:0] mr_sumdiff;
wire rl;
wire [4:0] shift_amount;
wire [11:0] normalized_m;


wire [11:0] mx11,mx10;
wire [6:0] mx21,mx20;
wire [11:0] dmuxout1, dmuxout0;
wire [11:0] mux1out;
wire [6:0] mux2out;
wire [11:0] data_out;
wire sel_big;
wire [10:0] comp2sout;
wire [11:0] lmuxout;

compare_diff dut1 (.a(fpa[14:10]), .b(fpb[14:10]), .abs_diff(diff), .less_than(ea_lesthn_eb), .equal(ea_equal_eb));

comp_mantissa dut1b (.a(fpa[9:0]), .b(fpb[9:0]), .less_than(ma_lesthn_mb));

assign sel_big = ea_lesthn_eb | (ma_lesthn_mb & ea_equal_eb);


mux16bit2to1 dut2 (.in0(fpa), .in1(fpb), .sel(sel_big), .muxout(big));
mux16bit2to1 dut3 (.in0(fpb), .in1(fpa), .sel(sel_big), .muxout(smal));


mux12bit2to1 dut4 (.in0(mr_sumdiff), .in1({1'b0,i1,smal[9:0]}), .sel(ctrl), .muxout(mux1out));

mux7bit2to1 dut5 (.in0({shift_amount,rl,1'b0}), .in1({diff,~(ea_equal_eb),i1}), .sel(ctrl), .muxout(mux2out));
barrelshifter dut6 (.rl(mux2out[1]), .shift_amt(mux2out[6:2]), .data_in(mux1out), .data_out(data_out));

demux12bit1to2 dut7 (.dmuxin(data_out), .sel(ctrl), .dmuxout0(dmuxout0), .dmuxout1(dmuxout1));

signlogic dut8 (.sbig(big[15]), .ssmal(smal[15]), .sub(sub));  
assign fpo[15] = big[15]; //result sign//RESULT SIGN

addsub dut9 (.sub(sub), .big({i1,big[9:0]}), .smal(dmuxout1[10:0]), .r_addsub(m_sumdiff));



complement2s dut9b (.a(m_sumdiff[10:0]), .y(comp2sout));
mux12bit2to1 dut9c (.in1(m_sumdiff), .in0({1'b0,comp2sout}), .sel((~sub) | (~m_sumdiff[11])), .muxout(lmuxout));

detectonezero dut10 (.din(mr_sumdiff), .rl(rl), .amount(shift_amount));

//barrelshifter2 dut8 (.i1(1'b0), .rl(rl), .shift_amt(shift_amount), .data_in(m_sumdiff), .data_out(normalized_m)); //m output
exp_inc_dec dut11 (.exp(big[14:10]), .amt(shift_amount[3:0]), .incdec(rl), .op_incdec(fpo[14:10]));  //RESULT EXPONENT

assign fpo[9:0] = dmuxout0[9:0]; //RESULT MANTISSA

always@(*)
begin
if (ctrl==1'b1)
mr_sumdiff <= lmuxout;
end


endmodule


// STRUCTURAL STYLE compare_diff4

module compare_diff (
    input wire [4:0] a,          // 5-bit input a
    input wire [4:0] b,          // 5-bit input b
    output wire less_than,       // Output 1 if a < b
    output wire equal,           // Output 1 if a = b
    output wire [4:0] abs_diff   // Absolute difference |a - b|
);

    wire [4:0] diff;             // 5-bit difference output
    wire [4:0] borrow;           // Borrow signals for each bit
    wire [4:0] diff_complement;  // 2's complement of diff

    // Instantiate 5 full subtractors to form the 5-bit subtractor
    full_subtractor fs0 (a[0], b[0], 1'b0, diff[0], borrow[0]);
    full_subtractor fs1 (a[1], b[1], borrow[0], diff[1], borrow[1]);
    full_subtractor fs2 (a[2], b[2], borrow[1], diff[2], borrow[2]);
    full_subtractor fs3 (a[3], b[3], borrow[2], diff[3], borrow[3]);
    full_subtractor fs4 (a[4], b[4], borrow[3], diff[4], borrow[4]);

    // Comparison logic
    assign less_than = borrow[4]; // a < b if the last borrow out is 1
    assign equal = ~(diff[0] | diff[1] | diff[2] | diff[3] | diff[4]); // a = b if all bits of diff are 0

    // 2's Complement Calculation for Absolute Difference
    wire [4:0] inverted_diff;  // Inverted bits of diff
    wire [4:0] carry;          // Ripple carry for 2's complement addition

    // Step 1: Invert the bits of diff
    assign inverted_diff = ~diff;

    // Step 2: Ripple-carry addition to add 1 to the inverted diff for 2's complement
    assign diff_complement[0] = inverted_diff[0] ^ 1'b1;
    assign carry[0] = inverted_diff[0] & 1'b1;

    assign diff_complement[1] = inverted_diff[1] ^ carry[0];
    assign carry[1] = inverted_diff[1] & carry[0];

    assign diff_complement[2] = inverted_diff[2] ^ carry[1];
    assign carry[2] = inverted_diff[2] & carry[1];

    assign diff_complement[3] = inverted_diff[3] ^ carry[2];
    assign carry[3] = inverted_diff[3] & carry[2];

    assign diff_complement[4] = inverted_diff[4] ^ carry[3];
    assign carry[4] = inverted_diff[4] & carry[3];

    // Step 3: Select abs_diff based on less_than
    assign abs_diff = less_than ? diff_complement : diff;

endmodule

// Full Subtractor Module (1-bit)
module full_subtractor (
    input wire a,      // Minuend bit
    input wire b,      // Subtrahend bit
    input wire bin,    // Borrow in
    output wire diff,  // Difference bit
    output wire bout   // Borrow out
);
    wire n1, n2, n3;

    // Full subtractor logic
    xor (n1, a, b);
    xor (diff, n1, bin);
    and (n2, ~a, b);
    and (n3, ~n1, bin);
    or (bout, n2, n3);
endmodule



module comp_mantissa (
    input wire [9:0] a,   // 10-bit input 'a'
    input wire [9:0] b,   // 10-bit input 'b'
    output wire less_than // Output 1 if a < b, else 0
);

    // Priority logic: a < b if any higher bit comparison confirms it; no need for equality checks
    assign less_than = 
        (~a[9] & b[9]) |
        (~a[8] & b[8] & (a[9] ~^ b[9])) |
        (~a[7] & b[7] & (a[9:8] == b[9:8])) |
        (~a[6] & b[6] & (a[9:7] == b[9:7])) |
        (~a[5] & b[5] & (a[9:6] == b[9:6])) |
        (~a[4] & b[4] & (a[9:5] == b[9:5])) |
        (~a[3] & b[3] & (a[9:4] == b[9:4])) |
        (~a[2] & b[2] & (a[9:3] == b[9:3])) |
        (~a[1] & b[1] & (a[9:2] == b[9:2])) |
        (~a[0] & b[0] & (a[9:1] == b[9:1]));

endmodule

module mux16bit2to1(
input [15:0] in0,in1,
input  sel,
output reg [15:0] muxout);


always@(*)
begin
if (sel==1'b1)
muxout<=in1;
else if (sel==1'b0)
muxout<=in0;
end

endmodule




module mux12bit2to1(
input [11:0] in0,in1,
input  sel,
output reg [11:0] muxout);


always@(*)
begin
if (sel==1'b1)
muxout<=in1;
else if (sel==1'b0)
muxout<=in0;
end

endmodule


module mux7bit2to1(
input [6:0] in0,in1,
input  sel,
output reg [6:0] muxout);


always@(*)
begin
if (sel==1'b1)
muxout<=in1;
else if (sel==1'b0)
muxout<=in0;
end

endmodule


module barrelshifter(
    //input i1,
    input rl,   //rl = 1 => right shift
    input [4:0] shift_amt,
    input [11:0] data_in,     
    output reg [11:0] data_out );


        always @(*) 
        begin
        if(rl == 1'b1)  //Right shift
        begin
        case (shift_amt)
            5'd0: data_out = data_in;                
            5'd1: data_out = {1'd0, data_in[11:1]};  
            5'd2: data_out = {2'd0, data_in[11:2]}; 
            5'd3: data_out = {3'd0, data_in[11:3]}; 
            5'd4: data_out = {4'd0, data_in[11:4]}; 
            5'd5: data_out = {5'd0, data_in[11:5]}; 
            5'd6: data_out = {6'd0, data_in[11:6]}; 
            5'd7: data_out = {7'd0, data_in[11:7]}; 
            //4'd8: data_out = {8'b00000000, data_in[31:8]}; 
            //4'd9: data_out = {9'b000000000, data_in[31:9]}; 
            //4'd10: data_out = {10'b0000000000, data_in[31:10]}; 
            default: data_out = 12'd0;             
        endcase
        end
        else if (rl ==1'b0)   //Left shift
        begin
        case (shift_amt)
            5'd0: data_out = data_in;                
            5'd1: data_out = {data_in[10:0], 1'd0};  
            5'd2: data_out = {data_in[9:0], 2'd0}; 
            5'd3: data_out = {data_in[8:0], 3'd0}; 
            5'd4: data_out = {data_in[7:0], 4'd0}; 
            5'd5: data_out = {data_in[6:0], 5'd0}; 
            5'd6: data_out = {data_in[5:0], 6'd0}; 
            5'd7: data_out = {data_in[4:0], 7'd0}; 
            //4'd8: data_out = {8'b00000000, data_in[31:8]}; 
            //4'd9: data_out = {9'b000000000, data_in[31:9]}; 
            //4'd10: data_out = {10'b0000000000, data_in[31:10]}; 
            default: data_out = 12'd0;             
        endcase
        end
    end

endmodule



module demux12bit1to2 (
    input wire [11:0] dmuxin,  // 12-bit input data
    input wire sel,             // Select signal
    output wire [11:0] dmuxout0,    // Output 0
    output wire [11:0] dmuxout1     // Output 1
);

    // Inverted select signal
    wire sel_n;
    not(sel_n, sel);

    // AND gates for each bit, connecting data_in to either out0 or out1 based on sel

    and (dmuxout0[0], dmuxin[0], sel_n);
    and (dmuxout0[1], dmuxin[1], sel_n);
    and (dmuxout0[2], dmuxin[2], sel_n);
    and (dmuxout0[3], dmuxin[3], sel_n);
    and (dmuxout0[4], dmuxin[4], sel_n);
    and (dmuxout0[5], dmuxin[5], sel_n);
    and (dmuxout0[6], dmuxin[6], sel_n);
    and (dmuxout0[7], dmuxin[7], sel_n);
    and (dmuxout0[8], dmuxin[8], sel_n);
    and (dmuxout0[9], dmuxin[9], sel_n);
    and (dmuxout0[10], dmuxin[10], sel_n);
    and (dmuxout0[11], dmuxin[11], sel_n);

    and (dmuxout1[0], dmuxin[0], sel);
    and (dmuxout1[1], dmuxin[1], sel);
    and (dmuxout1[2], dmuxin[2], sel);
    and (dmuxout1[3], dmuxin[3], sel);
    and (dmuxout1[4], dmuxin[4], sel);
    and (dmuxout1[5], dmuxin[5], sel);
    and (dmuxout1[6], dmuxin[6], sel);
    and (dmuxout1[7], dmuxin[7], sel);
    and (dmuxout1[8], dmuxin[8], sel);
    and (dmuxout1[9], dmuxin[9], sel);
    and (dmuxout1[10], dmuxin[10], sel);
    and (dmuxout1[11], dmuxin[11], sel);

endmodule



module signlogic(
input sbig, ssmal,
output sub);

assign sub = sbig^ssmal;
//assign sr = (sub & sbig)| sbig;



endmodule


module addsub(
//input i1,
input sub,
//ipnut [2:0] diff,
input [10:0] big,
input [10:0] smal,
output [11:0] r_addsub);

wire c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10;
//wire [11:0] r;


fulladder dut0 (.a(big[0]), .b(smal[0]^sub), .cin(1'b0 ^ sub), .sum(r_addsub[0]), .cout(c0));
fulladder dut1 (.a(big[1]), .b(smal[1]^sub), .cin(c0), .sum(r_addsub[1]), .cout(c1));

fulladder dut2 (.a(big[2]), .b(smal[2]^sub), .cin(c1), .sum(r_addsub[2]), .cout(c2));
fulladder dut3 (.a(big[3]), .b(smal[3]^sub), .cin(c2), .sum(r_addsub[3]), .cout(c3));
fulladder dut4 (.a(big[4]), .b(smal[4]^sub), .cin(c3), .sum(r_addsub[4]), .cout(c4));
fulladder dut5 (.a(big[5]), .b(smal[5]^sub), .cin(c4), .sum(r_addsub[5]), .cout(c5));
fulladder dut6 (.a(big[6]), .b(smal[6]^sub), .cin(c5), .sum(r_addsub[6]), .cout(c6));
fulladder dut7 (.a(big[7]), .b(smal[7]^sub), .cin(c6), .sum(r_addsub[7]), .cout(c7));
fulladder dut8 (.a(big[8]), .b(smal[8]^sub), .cin(c7), .sum(r_addsub[8]), .cout(c8));
fulladder dut9 (.a(big[9]), .b(smal[9]^sub), .cin(c8), .sum(r_addsub[9]), .cout(c9));
fulladder dut10 (.a(big[10]), .b(smal[10]^sub), .cin(c9), .sum(r_addsub[10]), .cout(c10));

assign r_addsub[11] = c10^sub; 


endmodule


module fulladder(
input a,
input b,
input cin,
output  sum,
output cout);


assign sum = a^b^cin;
assign cout = (a & b) | (cin & (a ^ b));

endmodule



module complement2s(
input [10:0] a,
//input cin,
output [10:0] y);

wire [10:0] inv;
wire and1,and2,and3,and4,and5,and6,and7,and8,and9,and10;

assign inv = ~a;

assign y[0] = inv[0] ^ 1'b1; 

assign and1 = inv[0] & 1'b1;
assign y[1] = inv[1] ^ and1;

assign and2 = inv[1] & and1;
assign y[2] = inv[2] ^ and2;

assign and3 = inv[2] & and2;
assign y[3] = inv[3] ^ and3;
  
assign and4 = inv[3] & and3;
assign and5 = inv[4] & and4;
assign and6 = inv[5] & and5;
assign and7 = inv[6] & and6;
assign and8 = inv[7] & and7;
assign and9 = inv[8] & and8;
assign and10 = inv[9] & and9;
//assign and11 = inv[10] & and10;

assign y[4] = inv[4] ^ and4;
assign y[5] = inv[5] ^ and5;
assign y[6] = inv[6] ^ and6;
assign y[7] = inv[7] ^ and7;
assign y[8] = inv[8] ^ and8;
assign y[9] = inv[9] ^ and9;
assign y[10] = inv[10] ^ and10;
//assign y[11] = inv[11] ^ and11;


endmodule


module detectonezero(
input [1:12] din,
output reg rl,
output reg [4:0] amount);

always@(*)
begin
if (din[1] == 1'b1)
begin
rl <= 1'b1;
amount <= 5'b00001;
end
else if (din[2] == 1'b1)
begin
rl <= 1'b1;
amount <= 5'b00000;
end
else if (din[3] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00001;
end
else if (din[4] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00010;
end
else if (din[5] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00011;
end
else if (din[6] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00100;
end
else if (din[7] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00101;
end
else if (din[8] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00110;
end
else if (din[9] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b00111;
end
else if (din[10] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b01000;
end
else if (din[11] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b01001;
end
else if (din[12] == 1'b1)
begin
rl <= 1'b0;
amount <= 5'b01010;
end
else
begin
rl <= 1'b0;
amount <= 5'b00000;
end
end
endmodule



module exp_inc_dec(
input [4:0] exp,
input [3:0] amt,
input incdec,
output reg [4:0] op_incdec );

always@(*)
if (incdec == 1'b1)
op_incdec <= exp + {1'b0,amt};
else if (incdec ==1'b0)
op_incdec <= exp - {1'b0,amt};
endmodule






