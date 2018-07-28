library IEEE; use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;

entity reservation_station is -- reservation station for alu
  generic(num_rs: integer);
  port(clk, reset, new_item: in STD_LOGIC;
       memtoreg_in:          in STD_LOGIC;
       q_dst, qj, qk:        in STD_LOGIC_VECTOR(2 downto 0);  -- tags: these datas are coming from register status table
       vj_in, vk_in:         in STD_LOGIC_VECTOR(31 downto 0); -- these datas are coming from register file
       op_in:                in STD_LOGIC_VECTOR(2 downto 0);
       cdb_q:                in STD_LOGIC_VECTOR(2 downto 0);  -- common data bus signals
       cdb_data:             in STD_LOGIC_VECTOR(31 downto 0); -- common data bus signals
       q_dst_out, op_out:    out STD_LOGIC_VECTOR(2 downto 0); -- these datas are going to ALU
       vj_out, vk_out:       out STD_LOGIC_VECTOR(31 downto 0); -- these datas are going to ALU
       op_sent:              out STD_LOGIC;
       memtoreg_out:         out STD_LOGIC;
       counter:              buffer UNSIGNED(2 downto 0));
end;

architecture behave of reservation_station is
  type entry is
    record
      busy:          STD_LOGIC;
      memtoreg:      STD_LOGIC;
      op:            STD_LOGIC_VECTOR(2 downto 0);
      q_dst, qj, qk: STD_LOGIC_VECTOR(2 downto 0);
      vj, vk:        STD_LOGIC_VECTOR(31 downto 0);
    end record;

  type rs_array is array (num_rs - 1 downto 0) of entry;

  signal rs: rs_array;
  signal s_op_sent: STD_LOGIC := '0';  -- this is to control that we send only one op per time to ALU
  signal s_q_dst_sent: STD_LOGIC_VECTOR(2 downto 0) := (others => '1');
begin

  op_sent <= s_op_sent;

  process (clk)
  begin

    if (reset ='1') then
      l1: for i in 0 to num_rs - 1 loop
        rs(i).busy <= '0';
        rs(i).op <= (others => '0');
        rs(i).q_dst <= (others => '1');
        rs(i).qj <= (others => '1');  -- 111 represents an empty q
        rs(i).qk <= (others => '1');  -- 111 represents an empty q
        rs(i).vj <= (others => '0');
        rs(i).vk <= (others => '0');
        counter <= (others => '0');
        q_dst_out <= (others => '1');
        op_out <= (others => '0');
        vj_out <= (others => '0');
        vk_out <= (others => '0');
        memtoreg_out <= '0';
      end loop l1;
    elsif (clk'event and clk = '1') then

      -- add an instruction to an free rs
      l2: for i in 0 to num_rs - 1 loop
        if (rs(i).busy = '0' and new_item = '1') then
          rs(i).busy <= '1';
          rs(i).op <= op_in;
          rs(i).vj <= vj_in;
          rs(i).vk <= vk_in;
          rs(i).q_dst <= q_dst;
          rs(i).qj <= qj;
          rs(i).qk <= qk;
          rs(i).memtoreg <= memtoreg_in;
          counter <= counter + 1;
          exit;
        end if;

        --send data to ALU
        -- if all datas are ready and we don't have any data being calculated at FU
        if (rs(i).busy = '1' and rs(i).qj = "111" and rs(i).qk = "111" and s_op_sent = '0') then
          op_out <= rs(i).op;
          vj_out <= rs(i).vj;
          vk_out <= rs(i).vk;
          q_dst_out <= rs(i).q_dst;
          rs(i).busy <= '0';
          s_op_sent <= '1';
          s_q_dst_sent <= rs(i).q_dst;
          memtoreg_out <= rs(i).memtoreg;
          counter <= counter - 1;
        end if;
      end loop l2;

      -- clear op_sent if instruction already executed
      if (cdb_q = s_q_dst_sent and s_q_dst_sent /= "111") then
        s_q_dst_sent <= (others => '1');
        s_op_sent <= '0';
      end if;

    end if;

    l3: for i in 0 to num_rs - 1 loop
      -- snoop for cdb
      if (rs(i).busy = '1') then
        if (rs(i).qj = cdb_q and cdb_q /= "111") then  -- if there is a required data on cdb
          rs(i).vj <= cdb_data;
          rs(i).qj <= "111"; -- clear qj
        end if;
        if (rs(i).qk = cdb_q and cdb_q /= "111") then  -- if there is a required data on cdb
          rs(i).vk <= cdb_data;
          rs(i).qk <= "111"; -- clear qk
        end if;
      end if;
    end loop l3;
  end process;
end;
