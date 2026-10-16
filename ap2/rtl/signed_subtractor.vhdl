--------------------------------------------------
--	Author:      Ismael Seidel (entidade)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Contém a descrição de uma entidade para subtração entre
--               dois valores com sinal de N bits. A saída `difference` será
--               o resultado de input_a - input_b. 
--               Todas as portas utilizam o tipo `signed`.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Subtrator com sinal (signed) parametrizável para N bits.
-- Calcula a diferença entre input_a e input_b.
-- A saída `difference` representa input_a - input_b.
entity signed_subtractor is
	generic(
		N : positive := 8 -- número de bits das entradas e da saída
	);
	port(
		input_a    : in  signed(N - 1 downto 0); -- entrada A com N bits com sinal
		input_b    : in  signed(N - 1 downto 0); -- entrada B com N bits com sinal
		difference : out signed(N - 1 downto 0)  -- saída da subtração
	);
end signed_subtractor;
-- Não altere a definição da entidade!
-- Ou seja, não modifique o nome da entidade, nome das portas e tipos/tamanhos das portas!

-- Não alterar o nome da arquitetura!
architecture arch of signed_subtractor is
begin
	difference <= input_a - input_b;
end architecture arch;