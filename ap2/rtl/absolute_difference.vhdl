--------------------------------------------------
--	Author:      Ismael Seidel (entity)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Contém a descrição de uma entidade para o cálculo da
--               diferença absoluta entre dois valores de N bits sem sinal.
--               A saída também é um valor de N bits sem sinal. 
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Calcula a diferença absoluta entre dois valores, similar ao Exercício 2.
-- Note que agora nosso circuito será parametrizável para N bits e as entradas
-- e saídas são unsigned (no Exercício 2 eram std_logic_vector pois tratava-se do
-- top-level). 
-- A saída abs_diff deve ser o resultado de |input_a - input_b|, onde | | é a operação
-- de valor absoluto.
entity absolute_difference IS
	generic(
		N : positive := 8
	);
	port(
		input_a  : in  unsigned(N - 1 downto 0);
		input_b  : in  unsigned(N - 1 downto 0);
		abs_diff : out unsigned(N - 1 downto 0)
	);
end entity;
-- Não altere a definição da entidade!
-- Ou seja, não modifique o nome da entidade, nome das portas e tipos/tamanhos das portas!

-- Não alterar o nome da arquitetura!
architecture structure OF absolute_difference IS
	-- Unsigned de N bits cabe em signed de N+1 bits (bit de sinal = 0).
	signal a_signed : signed(N downto 0);
	signal b_signed : signed(N downto 0);
	signal diff_ab  : signed(N downto 0);
	signal diff_ba  : signed(N downto 0);
	signal y_mux    : std_logic_vector(N downto 0);
begin
	a_signed <= signed('0' & std_logic_vector(input_a));
	b_signed <= signed('0' & std_logic_vector(input_b));

	sub_ab : entity work.signed_subtractor
		generic map(
			N => N + 1
		)
		port map(
			input_a    => a_signed,
			input_b    => b_signed,
			difference => diff_ab
		);

	sub_ba : entity work.signed_subtractor
		generic map(
			N => N + 1
		)
		port map(
			input_a    => b_signed,
			input_b    => a_signed,
			difference => diff_ba
		);

	-- diff_ab < 0 escolhe b - a; caso contrário, a - b. O resultado positivo cabe em N bits.
	mux : entity work.mux_2to1
		generic map(
			N => N + 1
		)
		port map(
			sel  => diff_ab(diff_ab'left),
			in_0 => std_logic_vector(diff_ab),
			in_1 => std_logic_vector(diff_ba),
			y    => y_mux
		);

	abs_diff <= unsigned(y_mux(N - 1 downto 0));
end architecture structure;