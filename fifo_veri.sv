`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2025 15:54:00
// Design Name: 
// Module Name: FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FIFO(input clk, rst, wr, rd,
            input [7:0] din, output reg [7:0] dout,
            output empty, full);
  
  reg [3:0] wptr = 0, rptr = 0;
  reg [4:0] cnt = 0;
  reg [7:0] mem [15:0];

  always @(posedge clk) begin
    if (rst == 1'b1) begin
      wptr <= 0;
      rptr <= 0;
      cnt  <= 0;
    end
    else if (wr && !full) begin
      mem[wptr] <= din;
      wptr      <= wptr + 1;
      cnt       <= cnt + 1;
    end
    else if (rd && !empty) begin
      dout <= mem[rptr];
      rptr <= rptr + 1;
      cnt  <= cnt - 1;
    end
  end

  assign empty = (cnt == 0);
  assign full  = (cnt == 16);

endmodule

interface fifo_if;

  logic clock, rd, wr;
  logic full, empty;
  logic [7:0] data_in;
  logic [7:0] data_out;
  logic rst;

endinterface

