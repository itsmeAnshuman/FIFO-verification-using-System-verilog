`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2025 15:57:14
// Design Name: 
// Module Name: tb
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


// ---------------- Transaction ----------------
class transaction;
  rand bit oper;
  bit rd, wr;
  bit [7:0] data_in;
  bit full, empty;
  bit [7:0] data_out;

  constraint oper_ctrl {
    oper dist {1 :/ 50 , 0 :/ 50};
  }
endclass

// ---------------- Generator ----------------
class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  int count = 0, i = 0;
  event next, done;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction

  task run();
    repeat (count) begin
      assert(tr.randomize) else $error("Randomization failed");
      i++;
      mbx.put(tr);
      $display("[GEN] : Oper : %0d iteration : %0d", tr.oper, i);
      @(next);
    end
    -> done;
  endtask
endclass

// ---------------- Driver ----------------
class driver;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction datac;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task reset();
    fif.rst <= 1;
    fif.rd <= 0;
    fif.wr <= 0;
    fif.data_in <= 0;
    repeat (5) @(posedge fif.clock);
    fif.rst <= 0;
    $display("[DRV] : DUT Reset Done");
    $display("------------------------------------------");
  endtask

  task write_till_full();
    while (!fif.full) begin
      @(posedge fif.clock);
      fif.wr <= 1;
      fif.rd <= 0;
      fif.data_in <= $urandom_range(1, 10);
      @(posedge fif.clock);
      fif.wr <= 0;
      $display("[DRV] : DATA WRITE, data : %0d", fif.data_in);
      @(posedge fif.clock);
    end
    $display("[DRV] : FIFO FULL, stopping writes.");
  endtask

  task read_till_empty();
    while (!fif.empty) begin
      @(posedge fif.clock);
      fif.wr <= 0;
      fif.rd <= 1;
      @(posedge fif.clock);
      fif.rd <= 0;
      $display("[DRV] : DATA READ");
      @(posedge fif.clock);
    end
    $display("[DRV] : FIFO EMPTY, stopping reads.");
  endtask

  task run();
    forever begin
      write_till_full();
      read_till_empty();
    end
  endtask
endclass

// ---------------- Monitor ----------------
class monitor;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction tr;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    tr = new();
    forever begin
      repeat (2) @(posedge fif.clock);
      tr.wr = fif.wr;
      tr.rd = fif.rd;
      tr.data_in = fif.data_in;
      tr.full = fif.full;
      tr.empty = fif.empty;
      @(posedge fif.clock);
      tr.data_out = fif.data_out;
      mbx.put(tr);
      $display("[MON] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d",
               tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
    end
  endtask
endclass

// ---------------- Scoreboard ----------------
class scoreboard;
  mailbox #(transaction) mbx;
  transaction tr;
  event next;
  bit [7:0] din[$];
  bit [7:0] temp;
  int err = 0;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    forever begin
      mbx.get(tr);
      $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d",
               tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);

      if (tr.wr && !tr.full) begin
        din.push_front(tr.data_in);
        $display("[SCO] : DATA STORED IN QUEUE :%0d", tr.data_in);
      end else if (tr.wr) begin
        $display("[SCO] : FIFO is full");
      end

      if (tr.rd && !tr.empty) begin
        temp = din.pop_back();
        if (tr.data_out == temp)
          $display("[SCO] : DATA MATCH");
        else begin
          $error("[SCO] : DATA MISMATCH");
          err++;
        end
      end else if (tr.rd) begin
        $display("[SCO] : FIFO IS EMPTY");
      end

      $display("--------------------------------------");
      -> next;
    end
  endtask
endclass

// ---------------- Environment ----------------
class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  event nextgs;
  virtual fifo_if fif;

  function new(virtual fifo_if fif);
    gdmbx = new();
    msmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    mon = new(msmbx);
    sco = new(msmbx);
    this.fif = fif;
    drv.fif = this.fif;
    mon.fif = this.fif;
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction

  task pre_test();
    drv.reset();
  endtask

  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask

  task post_test();
    wait(gen.done.triggered);
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.err);
    $display("---------------------------------------------");
    $finish();
  endtask

  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

// ---------------- Testbench ----------------
module tb;
  fifo_if fif();
  FIFO dut (fif.clock, fif.rst, fif.wr, fif.rd, fif.data_in, fif.data_out, fif.empty, fif.full);

  environment env;

  initial begin
    fif.clock <= 0;
  end

  always #10 fif.clock <= ~fif.clock;

  initial begin
    env = new(fif);
    env.gen.count = 30;
    env.run();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule

