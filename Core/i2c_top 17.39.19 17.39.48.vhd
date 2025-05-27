library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_top is
    port
    (
        -- system signals
        clk        : in  std_logic;
        reset      : in  std_logic;

        -- sbi interface
        sbi_cs     : in  std_logic;
        sbi_we     : in  std_logic;
        sbi_re     : in  std_logic;
        sbi_addr   : in  std_logic_vector(1 downto 0);
        sbi_wdata  : in  std_logic_vector(31 downto 0);
        sbi_rdata  : out std_logic_vector(31 downto 0);

        -- i2c interface
        sda        : inout std_logic;
        scl        : out std_logic
    );
end entity i2c_top;

architecture struct of i2c_top is

    -- components
    component i2c_registerbank is
        port 
        (
            clk           : in  std_logic;
            reset         : in  std_logic;

            sbi_cs        : in  std_logic;
            sbi_we        : in  std_logic;
            sbi_re        : in  std_logic;
            sbi_addr      : in  std_logic_vector(1 downto 0);
            sbi_wdata     : in  std_logic_vector(31 downto 0);
            sbi_rdata     : out std_logic_vector(31 downto 0);

            slave_address : out std_logic_vector(6 downto 0);
            data_in       : out std_logic_vector(7 downto 0);
            enable        : out std_logic;
            read_write    : out std_logic;
            stop_signal   : out std_logic;
            continue      : out std_logic;

            data_out      : in  std_logic_vector(7 downto 0);
            busy          : in  std_logic;
            ack_error     : in  std_logic;
            done          : in  std_logic;
            ready         : in  std_logic
        );
    end component;

    component i2c_master is
        generic 
        (
            SYS_CLK_FREQ_HZ : integer := 50_000_000;
            I2C_FREQ_HZ     : integer := 100_000
        );
        port 
        (
            clk           : in  std_logic;
            reset         : in  std_logic;

            slave_address : in  std_logic_vector(6 downto 0);
            data_in       : in  std_logic_vector(7 downto 0);
            data_out      : out std_logic_vector(7 downto 0);

            enable        : in  std_logic;
            read_write    : in  std_logic;
            stop_signal   : in  std_logic;
            continue      : in  std_logic;
            busy          : out std_logic;
            ack_error     : out std_logic;
            done          : out std_logic;
            ready         : out std_logic;

            scl           : out std_logic;
            sda           : inout std_logic
        );
    end component;

    -- internal signals
    signal slave_address : std_logic_vector(6 downto 0);
    signal data_in       : std_logic_vector(7 downto 0);
    signal data_out      : std_logic_vector(7 downto 0);

    signal enable        : std_logic;
    signal read_write    : std_logic;
    signal stop_signal   : std_logic;
    signal busy          : std_logic;
    signal ack_error     : std_logic;
    signal done          : std_logic;
    signal continue      : std_logic;
    signal ready         : std_logic;

begin

    -- registerbank instance
    reg_inst : i2c_registerbank
        port map 
        (
            clk           => clk,
            reset         => reset,
            sbi_cs        => sbi_cs,
            sbi_we        => sbi_we,
            sbi_re        => sbi_re,
            sbi_addr      => sbi_addr,
            sbi_wdata     => sbi_wdata,
            sbi_rdata     => sbi_rdata,
            slave_address => slave_address,
            data_in       => data_in,
            enable        => enable,
            read_write    => read_write,
            stop_signal   => stop_signal,
            data_out      => data_out,
            busy          => busy,
            ack_error     => ack_error,
            done          => done,
            ready         => ready,
            continue      => continue
        );

    -- i2c master instance
    master_inst : i2c_master
        generic map 
        (
            SYS_CLK_FREQ_HZ => 50_000_000,
            I2C_FREQ_HZ     => 100_000
        )
        port map 
        (
            clk           => clk,
            reset         => reset,
            slave_address => slave_address,
            data_in       => data_in,
            data_out      => data_out,
            enable        => enable,
            read_write    => read_write,
            stop_signal   => stop_signal,
            busy          => busy,
            ack_error     => ack_error,
            done          => done,
            ready         => ready,
            continue      => continue, 
            scl           => scl,
            sda           => sda
        );

end architecture struct;
