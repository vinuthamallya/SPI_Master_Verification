class transaction;
  rand bit newd;
  rand bit [11:0] din;
  bit cs ;
  bit mosi;
  
  
  function void display(input string tag);
    $display("[%s] : newd = %0b , din = %0b , cs = %0b , mosi = %0b",tag,newd,din,cs,mosi);
  endfunction
  
  function transaction copy();
    copy = new();
    copy.newd = this.newd;
    copy.din = this.din;
    copy.cs = this.cs;
    copy.mosi = this.mosi;
  endfunction
  
endclass


class generator;
  mailbox #(transaction) gen_drv;
  transaction t_h;
  
  event next ;
  event done;
  event drvnext;
  
  int count ;
  
  function new(mailbox #(transaction) gen_drv);
    this.gen_drv = gen_drv ;
    t_h = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(t_h.randomize());
       gen_drv.put(t_h.copy);
      t_h.display("GEN");
    $display("Data sent to driver");
      @(drvnext);
      @(next);
      end
    -> done;
  endtask
  
endclass


class driver ;
  
  virtual spi_masif vif;
  mailbox #(transaction) gen_drv;//common mbx to recieve t_h from GEN to DRV 
  mailbox #(bit [11:0]) mbx_drvs;//mbx to send data to sb when newd=1 for comparison  
  transaction t_h;
  bit [11:0] din;
  event drvnext;
  
  function new(mailbox #(transaction) gen_drv , mailbox #(bit [11:0]) mbx_drvs);
    this.gen_drv = gen_drv;
    this.mbx_drvs = mbx_drvs;
  endfunction
  
  task reset();
    vif.rst <= 1;
    vif.newd <= 0;
    vif.din <= 0;
    vif.cs <= 1;
    vif.mosi <= 0;
    repeat(10) @(posedge vif.clk);
    vif.rst <= 0;
    repeat(5) @(posedge vif.clk);
    $display("[DRV] : Reset Done ");
    $display("--------------------------");
  endtask
  
  task run();
    forever begin
      gen_drv.get(t_h);
      @(posedge vif.sclk);
      vif.newd <= 1 ;
      vif.din <= t_h.din;
      mbx_drvs.put(t_h.din);
      @(posedge vif.sclk);
      vif.newd <= 0;
      wait(vif.cs == 1)
      $display("[DRV] : Data sent to DAC %0b",t_h.din);
      -> drvnext;
    end
  endtask
  
endclass

class monitor;
  
  virtual spi_masif vif;
  mailbox #(bit [11:0]) mbx; // sending the scoreboard only the collected output from miso pin
  bit [11:0] srx; // collecting the bits from miso pin and clubbing them together in srx
  
  function new(mailbox #(bit [11:0]) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
    forever begin
      @(posedge vif.sclk)
      wait(vif.cs==0);
      
      for(int i=0 ; i<12 ; i++) begin
          @(posedge vif.sclk)
          srx[i] = vif.mosi;
      end
      wait(vif.cs==1);
      $display("[MON] : Data sent %0b",srx);
      
      mbx.put(srx);
    end
  endtask
  
endclass

class scoreboard;
  
  mailbox #(bit [11:0]) mbx_drvs;
  mailbox #(bit [11:0]) mbx;
  
  bit [11:0] ds; // data from driver (din) ;
  bit [11:0] ms ; // data from monitor (mosi)
  
  event next;
  
  function new(mailbox #(bit [11:0]) mbx_drvs ,mailbox #(bit [11:0]) mbx);
    this.mbx_drvs = mbx_drvs;
    this.mbx = mbx;
  endfunction
  
  task run();
    mbx_drvs.get(ds);
    mbx.get(ms);
    $display("[SCO] : recieved data from DRV : %0b and MON : %0b " , ds ,ms);
    
    if(ds == ms)
      $display("[SCO] :  Data Matched ");
    
    else 
      $display("[SCO] :  Data Mismatched ");
    
    $display("-------------------------------");
    -> next;
  endtask
  
endclass

class environment;
  
  virtual spi_masif mif;
  
  mailbox #(transaction) gen_drv;
  mailbox #(bit[11:0]) mbx_drvs;
  mailbox #(bit [11:0]) mbx;
  
  generator gen_h;
  driver drv_h;
  monitor mon_h;
  scoreboard sb_h;
  
  event next;
  event drv_next;
  
  function new(virtual spi_masif mif);
    gen_drv = new();
    mbx_drvs = new();
    mbx = new();
    
    gen_h = new(gen_drv);
    drv_h = new(gen_drv , mbx_drvs);
    mon_h = new(mbx);
    sb_h = new(mbx_drvs , mbx);
    
    this.mif = mif;
    
    drv_h.vif = this.mif ;
    mon_h.vif = this.mif ;
    
    gen_h.drvnext = drv_next;
    drv_h.drvnext = drv_next;
    gen_h.next = next ;
    sb_h.next = next;
    
  endfunction
  
  task pre_test();
    drv_h.reset();
    $display("[DRV] : RESET done ! ");
  endtask
  
  task test();
    fork
      gen_h.run();
      drv_h.run();
      mon_h.run();
      sb_h.run();
    join_any
  endtask
  
  task post_test();
    wait(gen_h.done.triggered);
    $finish;
  endtask
  
  task run;
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  spi_masif mif();
  
  spi dut (mif.clk , mif.newd , mif.rst , mif.din , mif.sclk , mif.cs , mif.mosi );
  
  initial mif.clk <= 0;
    
   always #5 mif.clk <= ~ mif.clk;
    
    environment env_h;
  
    initial begin
      env_h = new(mif);
      env_h.gen_h.count = 30;
      env_h.run();
    end
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars();
    end
    
    endmodule
