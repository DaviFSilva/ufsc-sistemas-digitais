--------------------------------------------------
-- Cálculo do endereço do bloco (parte do BO).
-- O multiplexador escolhe 0 (zi = 1) ou endereço + 1 (zi = 0).
-- O registrador só atualiza quando ci = 1.
-- menor fica em 1 enquanto o endereço guardado ainda não é o último.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sad_address is
	generic(
		ADDR_W : positive;
		LAST   : natural
	);
	port(
		clk     : in  std_logic;
		zi      : in  std_logic;
		ci      : in  std_logic;
		address : out std_logic_vector(ADDR_W - 1 downto 0);
		menor   : out std_logic
	);
end entity sad_address;

architecture structure of sad_address is
	signal addr_q    : unsigned(ADDR_W - 1 downto 0);
	signal addr_next : std_logic_vector(ADDR_W - 1 downto 0);
	signal addr_inc  : unsigned(ADDR_W downto 0);
	constant ZERO    : std_logic_vector(ADDR_W - 1 downto 0) := (others => '0');
	constant ONE     : unsigned(ADDR_W - 1 downto 0)         := to_unsigned(1, ADDR_W);
	constant LAST_U  : unsigned(ADDR_W - 1 downto 0)         := to_unsigned(LAST, ADDR_W);
begin
	inc : entity work.unsigned_adder
		generic map(
			N => ADDR_W
		)
		port map(
			input_a => addr_q,
			input_b => ONE,
			sum     => addr_inc
		);

	mux : entity work.mux_2to1
		generic map(
			N => ADDR_W
		)
		port map(
			sel  => zi,
			in_0 => std_logic_vector(addr_inc(ADDR_W - 1 downto 0)),
			in_1 => ZERO,
			y    => addr_next
		);

	reg : entity work.unsigned_register
		generic map(
			N => ADDR_W
		)
		port map(
			clk    => clk,
			enable => ci,
			d      => unsigned(addr_next),
			q      => addr_q
		);

	address <= std_logic_vector(addr_q);
	menor   <= '1' when addr_q < LAST_U else '0';
end architecture structure;
