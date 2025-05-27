library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity i2c_registerbank is
    port (
        -- system signals
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- sbi interface
        sbi_cs      : in  std_logic;
        sbi_we      : in  std_logic;
        sbi_re      : in  std_logic;
        sbi_addr    : in  std_logic_vector(1 downto 0);  
        sbi_wdata   : in  std_logic_vector(31 downto 0);
        sbi_rdata   : out std_logic_vector(31 downto 0);

        -- master control 
        slave_address : out std_logic_vector(6 downto 0);
        data_in       : out std_logic_vector(7 downto 0);
        enable        : out std_logic;
        read_write    : out std_logic;
        stop_signal   : out std_logic;
        continue      : out std_logic;

        -- master status 
        data_out    : in  std_logic_vector(7 downto 0);
        busy        : in  std_logic;
        ack_error   : in  std_logic;
        done        : in  std_logic;
        ready       : in  std_logic
    );
end i2c_registerbank;

architecture rtl of i2c_registerbank is
    
    -- Note: Not all internal signals are strictly necessary; they are included for clarity and code readability. 
    -- The design could be minimized by removing some of them if desired.

    -- internal registers
    signal control_register : std_logic_vector(3 downto 0);  -- 0x00  (continue - rw - stop - enable)
    signal write_register   : std_logic_vector(14 downto 0); -- 0x04  (slaveaddress[6:0] & datain[7:0])
    signal status_register  : std_logic_vector(3 downto 0);  -- 0x08  (ready - ack_error - busy - done)
    signal read_register    : std_logic_vector(7 downto 0);  -- 0x0C  (dataout)

    -- internal control signals 
    signal enable_internal, stop_internal, readwrite_internal, continue_internal : std_logic;

    -- internal write signals
    signal slave_address_internal     : std_logic_vector(6 downto 0);
    signal datain_internal            : std_logic_vector(7 downto 0);

    -- internal read signals 
    signal dataout_internal           : std_logic_vector(7 downto 0);


begin 

    -- enable    
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                enable_internal <= '0';
            elsif (sbi_cs = '1' and sbi_we = '1' and sbi_addr = "00") then
                enable_internal <= sbi_wdata(0);
            else
                enable_internal <= '0';
            end if;
        end if;
    end process;
    control_register(0) <= enable_internal;
    enable <= control_register(0);

    -- stop 
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                stop_internal <= '0';
            elsif (sbi_cs = '1' and sbi_we = '1' and sbi_addr = "00") then
                stop_internal <= sbi_wdata(1);
            else 
                stop_internal <= '0';
            end if;
        end if;
    end process;
    control_register(1) <= stop_internal;
    stop_signal <= control_register(1);

    -- read/write 
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                readwrite_internal <= '0';
            elsif (sbi_cs = '1' and sbi_we = '1' and sbi_addr = "00") then
                readwrite_internal <= sbi_wdata(2);
            end if;
        end if;
    end process;
    control_register(2) <= readwrite_internal;
    read_write <= control_register(2);

    -- continue 
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                continue_internal <= '0';
            elsif (sbi_cs = '1' and sbi_we = '1' and sbi_addr = "00") then
                continue_internal <= sbi_wdata(3);
            else 
                continue_internal <= '0';
            end if;
        end if;
    end process;
    control_register(3) <= continue_internal;
    continue <= control_register(3);

    --write process 
    process(clk)
    begin 
        if rising_edge(clk) then
            if (reset = '1') then
                slave_address_internal <= (others => '0');
                datain_internal <= (others => '0');

            elsif (sbi_cs = '1' and sbi_we = '1' and sbi_addr = "01") then
                slave_address_internal <= sbi_wdata(14 downto 8);
                datain_internal <= sbi_wdata(7 downto 0);
            end if ;
        end if ;
    end process;
    write_register(14 downto 8) <= slave_address_internal;
    write_register(7 downto 0)  <= datain_internal;

    slave_address <= write_register(14 downto 8);
    data_in       <= write_register(7 downto 0);

    -- status register 
    process(ready, ack_error, busy, done)
    begin 
        status_register(3) <= ready;
        status_register(2) <= ack_error;
        status_register(1) <= busy;
        status_register(0) <= done;
    end process;

    -- reading register 
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset='1') then
                dataout_internal <= (others=>'0');

            elsif (done='1') then              
                dataout_internal <= data_out;
            end if;
        end if;
    end process;
    read_register <= dataout_internal;

    
    -- reading process
    process(sbi_cs, sbi_re, sbi_addr, control_register, write_register, status_register, read_register)
    begin
        if (sbi_cs = '1' and sbi_re = '1') then
            case sbi_addr is
                when "00" =>
                    sbi_rdata <= (31 downto 4 => '0') & control_register;
            
                when "01" =>
                    sbi_rdata <= (31 downto 15 => '0') & write_register;
            
                when "10" =>
                    sbi_rdata <= (31 downto 4 => '0') & status_register;
            
                when "11" =>
                    sbi_rdata <= (31 downto 8 => '0') & read_register;
            
                when others =>
                    sbi_rdata <= (others => '0');
            end case;
        else
            sbi_rdata <= (others => '0');

        end if;
    end process;
end architecture;