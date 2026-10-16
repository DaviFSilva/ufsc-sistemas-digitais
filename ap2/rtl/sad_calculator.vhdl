--------------------------------------------------
-- Cálculo do valor da SAD (parte do BO).
-- Para cada amostra em paralelo calcula |A - B|, soma essas diferenças e
-- acumula o resultado. zs = 1 carrega 0; zs = 0 carrega o acumulador + diff.
-- O registrador só atualiza quando cs = 1.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sad_pack.all;

entity sad_calculator is
	generic(
		SAMPLE_W : positive;
		SAD_W    : positive;
		PARALLEL : positive
	);
	port(
		clk        : in  std_logic;
		zs         : in  std_logic;
		cs         : in  std_logic;
		sample_ori : in  std_logic_vector(SAMPLE_W * PARALLEL - 1 downto 0);
		sample_can : in  std_logic_vector(SAMPLE_W * PARALLEL - 1 downto 0);
		sad_value  : out std_logic_vector(SAD_W - 1 downto 0)
	);
end entity sad_calculator;

architecture structure of sad_calculator is
	signal diffs      : parallel_samples_vector_t(0 to PARALLEL - 1)(SAMPLE_W - 1 downto 0);
	signal partial    : unsigned(SAD_W - 1 downto 0);
	signal sad_q      : unsigned(SAD_W - 1 downto 0);
	signal sad_sum    : unsigned(SAD_W downto 0);
	signal sad_next   : std_logic_vector(SAD_W - 1 downto 0);
	constant ZERO_SAD : std_logic_vector(SAD_W - 1 downto 0) := (others => '0');
begin
	gen_diff : for i in 0 to PARALLEL - 1 generate
		signal a_i : unsigned(SAMPLE_W - 1 downto 0);
		signal b_i : unsigned(SAMPLE_W - 1 downto 0);
	begin
		a_i <= unsigned(sample_ori((i + 1) * SAMPLE_W - 1 downto i * SAMPLE_W));
		b_i <= unsigned(sample_can((i + 1) * SAMPLE_W - 1 downto i * SAMPLE_W));

		abs_i : entity work.absolute_difference
			generic map(
				N => SAMPLE_W
			)
			port map(
				input_a  => a_i,
				input_b  => b_i,
				abs_diff => diffs(i)
			);
	end generate gen_diff;

	-- Soma das diferenças das amostras lidas no mesmo ciclo (árvore reduz a um valor).
	sum_partial : process (diffs)
		variable acc : unsigned(SAD_W - 1 downto 0);
	begin
		acc := (others => '0');
		for i in diffs'range loop
			acc := acc + resize(diffs(i), SAD_W);
		end loop;
		partial <= acc;
	end process sum_partial;

	acc_add : entity work.unsigned_adder
		generic map(
			N => SAD_W
		)
		port map(
			input_a => sad_q,
			input_b => partial,
			sum     => sad_sum
		);

	mux : entity work.mux_2to1
		generic map(
			N => SAD_W
		)
		port map(
			sel  => zs,
			in_0 => std_logic_vector(sad_sum(SAD_W - 1 downto 0)),
			in_1 => ZERO_SAD,
			y    => sad_next
		);

	reg : entity work.unsigned_register
		generic map(
			N => SAD_W
		)
		port map(
			clk    => clk,
			enable => cs,
			d      => unsigned(sad_next),
			q      => sad_q
		);

	sad_value <= std_logic_vector(sad_q);
end architecture structure;
