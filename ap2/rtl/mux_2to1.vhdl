--------------------------------------------------
--	Author:      Ismael Seidel (entidade)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Contém a descrição de uma entidade para um multiplexador
--               2:1 parametrizável para N bits. A saída `y` será igual a
--               `in_0` quando `sel = '0'`, e igual a `in_1` quando `sel = '1'`.
--               As entradas e saídas são vetores com N bits.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-- Multiplexador 2:1 com entradas e saída de N bits.
-- A seleção é feita com base no sinal `sel`.
-- Se sel = '0', então y = in_0; caso contrário, y = in_1.
entity mux_2to1 is
	generic(
		N : positive -- número de bits das entradas e da saída
	);
	port(
		sel        : in  std_logic;                        -- sinal de seleção
		in_0, in_1 : in  std_logic_vector(N - 1 downto 0); -- entradas do mux
		y          : out std_logic_vector(N - 1 downto 0)  -- saída do mux
	);
end mux_2to1;
-- Não altere a definição da entidade!
-- Ou seja, não modifique o nome da entidade, nome das portas e tipos/tamanhos das portas!

-- Não alterar o nome da arquitetura!
architecture behavior of mux_2to1 is
begin
	y <= in_0 when sel = '0' else in_1;
end architecture behavior;