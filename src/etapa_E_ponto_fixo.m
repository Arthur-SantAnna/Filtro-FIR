function resultado_E = etapa_E_ponto_fixo()
% ETAPA_E_PONTO_FIXO Exemplo numerico de precisao aritmetica em ponto fixo Q1.7 e analise de overflow.
%
%   Proposito:
%       Implementar integralmente a Etapa E (conceitual e breve) da Pratica 3:
%       1. Reproduzir um exemplo numerico didatico de multiplicacao de dois
%          operandos exatos em formato Q1.7 (8 bits com sinal, 7 bits fracionarios)
%          cujo produto completo exato em Q2.14 (16 bits com sinal, 14 bits
%          fracionarios) apresenta parte fracionaria descartada >= 0,5 LSB de Q1.7,
%          evidenciando a diferenca entre arredondamento (round) e truncamento em
%          complemento de 2 (floor) ao retornar para Q1.7.
%       2. Identificar e quantificar os erros absolutos e em unidades de LSB de Q1.7
%          em relacao ao produto completo de 16 bits.
%       3. Carregar os coeficientes h do filtro FIR projetado na Etapa A
%          (data/coeficientes_FIR.mat) e calcular a soma dos modulos dos
%          coeficientes (norma L1 = sum(abs(h))) como limite superior BIBO da
%          amplitude de saida para entrada limitada |x[n]| <= 1, determinando
%          tambem os bits de guarda (guard bits) necessarios no acumulador MAC.
%       4. Demonstrar um exemplo numerico simples de overflow em adicao Q1.7,
%          comparando o comportamento de saturacao (clipping no limite maximo
%          representavel 1 - 2^-7) e o retorno circular (wrap-around em
%          aritmetica modular de complemento de 2 de 8 bits).
%       5. Exportar a tabela consolidada results/tab_E1_produto_Q17.csv.
%
%   Saidas:
%       resultado_E - Estrutura (struct) contendo todos os parametros, metricas,
%                     exemplos numericos e a tabela gerada na Etapa E.
%
%   Autor/Disciplina:
%       Processamento Digital de Sinais (SENAI CIMATEC) - Pratica 3

%% 1. Carregamento das Especificacoes e Configuracao de Caminhos
dir_script = fileparts(mfilename('fullpath')); % Diretorio do script atual
addpath(dir_script);
if isfolder(fullfile(dir_script, 'utils'))
    addpath(fullfile(dir_script, 'utils'));
end

specs = config_specs();

fprintf('======================================================================\n');
fprintf('ETAPA E - PRECISAO ARITMETICA EM PONTO FIXO (Q1.7) E OVERFLOW\n');
fprintf('======================================================================\n');

%% 2. Parametros da Representacao em Ponto Fixo Q1.7 e Q2.14
bits_palavra_Q17 = 8;                     % Largura total da palavra em Q1.7 [bits]
F_Q17            = 7;                     % Numero de bits fracionarios em Q1.7 [bits]
escala_Q17       = 2^F_Q17;               % Fator de escala inteiro de Q1.7 (128) [LSB^-1]
delta_Q17        = 2^(-F_Q17);            % Passo de quantizacao (1 LSB) em Q1.7 (0,0078125) [amplitude]
min_Q17          = -1.0;                  % Limite inferior representavel em Q1.7 (-128/128) [amplitude]
max_Q17          = 1.0 - delta_Q17;       % Limite superior representavel em Q1.7 (+127/128 = 0,9921875) [amplitude]

bits_palavra_Q214 = 16;                   % Largura total do produto completo em Q2.14 [bits]
F_Q214            = 14;                   % Numero de bits fracionarios em Q2.14 [bits]
escala_Q214       = 2^F_Q214;             % Fator de escala inteiro de Q2.14 (16384) [LSB^-1]
delta_Q214        = 2^(-F_Q214);          % Passo de quantizacao (1 LSB) em Q2.14 (2^-14) [amplitude]

fprintf('Formato Q1.7  : %d bits totais (1 sinal + 7 fracionarios), Delta = 2^-7 = %.7f, Faixa = [%.7f, +%.7f]\n', ...
    bits_palavra_Q17, delta_Q17, min_Q17, max_Q17);
fprintf('Formato Q2.14 : %d bits totais (1 sinal + 1 inteiro + 14 fracionarios), Delta = 2^-14 = %.10f\n\n', ...
    bits_palavra_Q214, delta_Q214);

%% 3. Exemplo Numerico de Produto de Dois Operandos Q1.7 (Arredondamento vs Truncamento)
% Escolha didatica de operandos exatos em Q1.7:
%   a = 79/128 = 0,6171875  (inteiro escalado A = 79 = 01001111_2)
%   b = 45/128 = 0,3515625  (inteiro escalado B = 45 = 00101101_2)
% Produto inteiro exato em 16 bits (Q2.14):
%   P = A * B = 79 * 45 = 3555 (0000110111100011_2)
%   Em unidades de LSB de Q1.7 (dividindo por 2^7 = 128):
%   P / 128 = 3555 / 128 = 27 + 99/128 = 27,7734375 LSBs de Q1.7
%   Como a parte fracionaria descartada (99/128 = 0,7734375 LSB) e >= 0,5 LSB:
%   - Arredondamento (round) produz 28/128 = 0,2187500
%   - Truncamento (floor)    produz 27/128 = 0,2109375
int_a_Q17 = 79;                                  % Operando A representado como inteiro escalado por 2^7 [LSB de Q1.7]
int_b_Q17 = 45;                                  % Operando B representado como inteiro escalado por 2^7 [LSB de Q1.7]

op_a_Q17  = int_a_Q17 / escala_Q17;              % Valor real exato do operando A em Q1.7 [amplitude]
op_b_Q17  = int_b_Q17 / escala_Q17;              % Valor real exato do operando B em Q1.7 [amplitude]

% Produto completo exato em Q2.14 (16 bits)
int_prod_Q214       = int_a_Q17 * int_b_Q17;     % Produto inteiro exato em escala 2^14 [LSB de Q2.14]
prod_completo_Q214  = int_prod_Q214 / escala_Q214; % Valor real exato do produto completo em Q2.14 [amplitude]
prod_em_LSB_Q17     = prod_completo_Q214 * escala_Q17; % Produto completo expresso em unidades de LSB de Q1.7 [LSB de Q1.7]
frac_descartada_LSB = prod_em_LSB_Q17 - floor(prod_em_LSB_Q17); % Parte fracionaria descartada dos 7 bits menos significativos [LSB de Q1.7]

% Conversao de Q2.14 para Q1.7 por Arredondamento (round to nearest)
int_prod_arred_Q17  = round(prod_completo_Q214 * escala_Q17); % Inteiro escalado em Q1.7 apos arredondamento [LSB de Q1.7]
prod_arred_Q17      = int_prod_arred_Q17 / escala_Q17;        % Resultado do produto arredondado para Q1.7 [amplitude]
erro_arred          = prod_arred_Q17 - prod_completo_Q214;    % Erro com sinal do arredondamento (Q1.7 - Q2.14) [amplitude]
erro_abs_arred      = abs(erro_arred);                        % Erro absoluto do arredondamento [amplitude]
erro_arred_LSB_Q17  = erro_arred / delta_Q17;                 % Erro do arredondamento em unidades de LSB de Q1.7 [LSB de Q1.7]

% Conversao de Q2.14 para Q1.7 por Truncamento em Complemento de 2 (floor: descarte dos 7 LSBs)
int_prod_trunc_Q17  = floor(prod_completo_Q214 * escala_Q17); % Inteiro escalado em Q1.7 apos truncamento [LSB de Q1.7]
prod_trunc_Q17      = int_prod_trunc_Q17 / escala_Q17;        % Resultado do produto truncado para Q1.7 [amplitude]
erro_trunc          = prod_trunc_Q17 - prod_completo_Q214;    % Erro com sinal do truncamento (Q1.7 - Q2.14) [amplitude]
erro_abs_trunc      = abs(erro_trunc);                        % Erro absoluto do truncamento [amplitude]
erro_trunc_LSB_Q17  = erro_trunc / delta_Q17;                 % Erro do truncamento em unidades de LSB de Q1.7 [LSB de Q1.7]

% Diferenca direta entre arredondamento e truncamento
dif_arred_trunc     = prod_arred_Q17 - prod_trunc_Q17;        % Diferenca entre resultado arredondado e truncado [amplitude]
dif_arred_trunc_LSB = dif_arred_trunc / delta_Q17;            % Diferenca entre arredondado e truncado em LSB de Q1.7 [LSB de Q1.7]

% Strings binarias para documentacao didatica (complemento de 2)
bin_a_Q17          = dec2bin(mod(int_a_Q17, 2^bits_palavra_Q17), bits_palavra_Q17);
bin_b_Q17          = dec2bin(mod(int_b_Q17, 2^bits_palavra_Q17), bits_palavra_Q17);
bin_prod_Q214      = dec2bin(mod(int_prod_Q214, 2^bits_palavra_Q214), bits_palavra_Q214);
bin_prod_arred_Q17 = dec2bin(mod(int_prod_arred_Q17, 2^bits_palavra_Q17), bits_palavra_Q17);
bin_prod_trunc_Q17 = dec2bin(mod(int_prod_trunc_Q17, 2^bits_palavra_Q17), bits_palavra_Q17);

fprintf('--- 1. EXEMPLO NUMERICO: PRODUTO DE DOIS OPERANDOS Q1.7 ---\n');
fprintf('  Operando a (Q1.7)                   : %3d / 128   = %.14f (bin: %s)\n', int_a_Q17, op_a_Q17, bin_a_Q17);
fprintf('  Operando b (Q1.7)                   : %3d / 128   = %.14f (bin: %s)\n', int_b_Q17, op_b_Q17, bin_b_Q17);
fprintf('  Produto completo exato (Q2.14)      : %4d / 16384 = %.14f (bin: %s = %.7f / 128)\n', ...
    int_prod_Q214, prod_completo_Q214, bin_prod_Q214, prod_em_LSB_Q17);
fprintf('  Fracao descartada (7 bits inferiores): 99 / 128 LSB = %.7f LSB de Q1.7 (>= 0,5 LSB)\n', frac_descartada_LSB);
fprintf('  Resultado arredondado (round, Q1.7) : %3d / 128   = %.14f (bin: %s)\n', int_prod_arred_Q17, prod_arred_Q17, bin_prod_arred_Q17);
fprintf('    -> Erro arredondamento (c/ sinal) : %+.14f (%+.7f LSB de Q1.7)\n', erro_arred, erro_arred_LSB_Q17);
fprintf('    -> Erro absoluto arredondamento   :  %.14f ( %.7f LSB de Q1.7 <= 0,5 LSB = %.7f)\n', ...
    erro_abs_arred, abs(erro_arred_LSB_Q17), 0.5 * delta_Q17);
fprintf('  Resultado truncado (floor, Q1.7)    : %3d / 128   = %.14f (bin: %s)\n', int_prod_trunc_Q17, prod_trunc_Q17, bin_prod_trunc_Q17);
fprintf('    -> Erro truncamento (c/ sinal)    : %+.14f (%+.7f LSB de Q1.7)\n', erro_trunc, erro_trunc_LSB_Q17);
fprintf('    -> Erro absoluto truncamento      :  %.14f ( %.7f LSB de Q1.7 <  1,0 LSB = %.7f)\n', ...
    erro_abs_trunc, abs(erro_trunc_LSB_Q17), delta_Q17);
fprintf('  Diferenca (Arredondado - Truncado)  :  %.14f ( %.1f LSB de Q1.7)\n\n', dif_arred_trunc, dif_arred_trunc_LSB);

%% 4. Norma L1 dos Coeficientes (sum|h[k]|), Ganho de Pico BIBO e Crescimento de Palavra
caminho_mat = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
if ~isfile(caminho_mat)
    error('EtapaE:ArquivoNaoEncontrado', ...
        'Arquivo %s nao encontrado. Execute a Etapa A antes da Etapa E.', caminho_mat);
end

dados_A = load(caminho_mat, 'h', 'N');
h = dados_A.h(:).'; % Vetor linha de coeficientes do filtro FIR da Etapa A [adimensional]
N = dados_A.N;      % Comprimento do filtro FIR (numero de coeficientes) [coeficientes]

soma_h           = sum(h);                 % Soma algebrica dos coeficientes (ganho DC) [adimensional]
soma_abs_h       = sum(abs(h));            % Soma dos modulos dos coeficientes (norma L1 / ganho de pico BIBO) [adimensional]
soma_abs_h_dB    = 20 * log10(soma_abs_h); % Ganho maximo de pico no dominio do tempo em decibeis [dB]
max_entrada_Q17  = 1.0;                    % Amplitude maxima absoluta de entrada considerada |x[n]| <= 1 [amplitude]
limite_saida_max = max_entrada_Q17 * soma_abs_h; % Limite superior absoluto da saida |y[n]| <= ||x||_inf * sum(|h[k]|) [amplitude]

% Bits de guarda (guard bits) para o acumulador MAC:
% - Para N somas arbitrárias em [-1, 1]: ceil(log2(N)) bits extras
% - Considerando a restricao fisica do filtro especifico sum(|h[k]|): ceil(log2(soma_abs_h)) bit extra
bits_guarda_pior_caso_N = ceil(log2(N));          % Bits de guarda para soma de N produtos genericos de fundo de escala [bits]
bits_guarda_norma_L1    = ceil(log2(soma_abs_h)); % Bits de guarda estritos para a norma L1 do filtro projetado [bits]

fprintf('--- 2. CRESCIMENTO DE PALAVRA E LIMITE DE AMPLITUDE DE SAIDA (BIBO) ---\n');
fprintf('  Numero de coeficientes do filtro (N)     : %d coeficientes\n', N);
fprintf('  Soma algebrica sum(h[k]) (Ganho DC)      : %.14f\n', soma_h);
fprintf('  Soma dos modulos sum(|h[k]|) (Norma L1)  : %.14f (%.4f dB)\n', soma_abs_h, soma_abs_h_dB);
fprintf('  Limite superior de saida p/ |x[n]| <= 1  : |y[n]| <= %.14f (excede +1,0 em %.2f%%)\n', ...
    limite_saida_max, (limite_saida_max - 1.0) * 100);
fprintf('  Bits de guarda no acumulador (norma L1)  : ceil(log2(%.4f)) = %d bit extra\n', soma_abs_h, bits_guarda_norma_L1);
fprintf('  Bits de guarda no acumulador (N=%d somas): ceil(log2(%d))     = %d bits extras\n\n', N, N, bits_guarda_pior_caso_N);

%% 5. Exemplo Numerico Simples de Overflow em Adicao Q1.7: Saturacao vs Wrap-Around
% Operandos positivos em Q1.7 cuja soma ultrapassa o limite superior +127/128 = 0,9921875:
%   x1 = 96/128 = 0,7500000 (01100000_2)
%   x2 = 64/128 = 0,5000000 (01000000_2)
% Soma real exata:
%   s_exata = 160/128 = +1,2500000 (> +0,9921875 => ocorre overflow positivo!)
% 1) Com Saturacao (clipping):
%   s_sat = min(max(s_exata, -1), 1 - 2^-7) = +127/128 = +0,9921875 (erro = -0,2578125)
% 2) Com Retorno Circular (wrap-around em complemento de 2 de 8 bits):
%   160 em 8 bits sem sinal = 10100000_2 -> interpretado em complemento de 2: 160 - 256 = -96
%   s_wrap = -96/128 = -0,7500000 (inversao severa de polaridade, erro = -2,0000000)
int_ov_1       = 96;                                  % Primeiro operando inteiro da soma em Q1.7 (96/128 = 0,75) [LSB de Q1.7]
int_ov_2       = 64;                                  % Segundo operando inteiro da soma em Q1.7 (64/128 = 0,50) [LSB de Q1.7]
op_ov_1        = int_ov_1 / escala_Q17;               % Primeiro operando real da soma em Q1.7 [amplitude]
op_ov_2        = int_ov_2 / escala_Q17;               % Segundo operando real da soma em Q1.7 [amplitude]

int_soma_exata = int_ov_1 + int_ov_2;                 % Soma inteira exata sem limite de 8 bits (160) [LSB de Q1.7]
soma_exata     = int_soma_exata / escala_Q17;         % Soma real exata (+1,25) [amplitude]

% Aritmetica com Saturacao
soma_saturada     = min(max(soma_exata, min_Q17), max_Q17); % Soma limitada por saturacao em Q1.7 [amplitude]
int_soma_saturada = round(soma_saturada * escala_Q17);      % Inteiro escalado apos saturacao (127) [LSB de Q1.7]
erro_abs_saturada = abs(soma_saturada - soma_exata);        % Erro absoluto da saturacao frente a soma exata [amplitude]

% Aritmetica com Retorno Circular (Wrap-Around em complemento de 2 de 8 bits)
int_soma_wrap     = mod(int_soma_exata + 128, 256) - 128;   % Inteiro em complemento de 2 de 8 bits (-96) [LSB de Q1.7]
soma_wrap         = int_soma_wrap / escala_Q17;             % Valor real apos wrap-around (-0,75) [amplitude]
erro_abs_wrap     = abs(soma_wrap - soma_exata);            % Erro absoluto do wrap-around frente a soma exata [amplitude]

fprintf('--- 3. EXEMPLO NUMERICO: OVERFLOW EM ADICAO Q1.7 (SATURACAO VS WRAP-AROUND) ---\n');
fprintf('  Parcela 1 (Q1.7)                    : %+4d / 128 = %+.7f\n', int_ov_1, op_ov_1);
fprintf('  Parcela 2 (Q1.7)                    : %+4d / 128 = %+.7f\n', int_ov_2, op_ov_2);
fprintf('  Soma exata (sem limite de 8 bits)   : %+4d / 128 = %+.7f (excede max Q1.7 = +%.7f)\n', ...
    int_soma_exata, soma_exata, max_Q17);
fprintf('  Resultado com Saturacao (Q1.7)      : %+4d / 128 = %+.7f (Erro absoluto = %.7f)\n', ...
    int_soma_saturada, soma_saturada, erro_abs_saturada);
fprintf('  Resultado com Wrap-Around (Q1.7)    : %+4d / 128 = %+.7f (Erro absoluto = %.7f - inversao de sinal!)\n\n', ...
    int_soma_wrap, soma_wrap, erro_abs_wrap);

%% 6. Exportacao da Tabela Consolidada results/tab_E1_produto_Q17.csv
Item = [
    "Operando a (Q1.7)";
    "Operando b (Q1.7)";
    "Produto completo exato a*b (Q2.14)";
    "Parte fracionaria descartada (7 LSBs)";
    "Produto arredondado para Q1.7 (round)";
    "Produto truncado para Q1.7 (floor)";
    "Diferenca (Arredondado - Truncado)";
    "Passo de quantizacao Delta (1 LSB Q1.7)";
    "Limite teorico erro arredondamento (Delta/2)";
    "Limite teorico erro truncamento (Delta)";
    "Norma L1 dos coeficientes sum(|h[k]|)";
    "Soma algebrica dos coeficientes sum(h[k])";
    "Bits de guarda acumulador (norma L1)";
    "Bits de guarda acumulador (pior caso N=23)";
    "Exemplo overflow: Parcela 1 (Q1.7)";
    "Exemplo overflow: Parcela 2 (Q1.7)";
    "Exemplo overflow: Soma exata (Q2.7)";
    "Exemplo overflow: Soma com Saturacao (Q1.7)";
    "Exemplo overflow: Soma com Wrap-Around (Q1.7)"
    ];

Formato = [
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Q2.14 (16 bits)";
    "7 bits inferiores";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Ponto flutuante (double)";
    "Ponto flutuante (double)";
    "Inteiro (bits)";
    "Inteiro (bits)";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)";
    "Acima de Q1.7";
    "Q1.7 (8 bits)";
    "Q1.7 (8 bits)"
    ];

Representacao_Fracionaria = [
    sprintf('%d/128', int_a_Q17);
    sprintf('%d/128', int_b_Q17);
    sprintf('%d/16384 (%.7f/128)', int_prod_Q214, prod_em_LSB_Q17);
    sprintf('99/16384 (99/128 LSB Q1.7)');
    sprintf('%d/128', int_prod_arred_Q17);
    sprintf('%d/128', int_prod_trunc_Q17);
    sprintf('%d/128', int_prod_arred_Q17 - int_prod_trunc_Q17);
    "1/128";
    "1/256 (0,5/128)";
    "1/128 (1,0/128)";
    sprintf('N = %d coeficientes', N);
    sprintf('N = %d coeficientes', N);
    sprintf('ceil(log2(%.4f))', soma_abs_h);
    sprintf('ceil(log2(%d))', N);
    sprintf('%d/128', int_ov_1);
    sprintf('%d/128', int_ov_2);
    sprintf('%d/128', int_soma_exata);
    sprintf('%d/128', int_soma_saturada);
    sprintf('%d/128', int_soma_wrap)
    ];

Representacao_Binaria = [
    string(bin_a_Q17);
    string(bin_b_Q17);
    string(bin_prod_Q214);
    string(bin_prod_Q214(10:16));
    string(bin_prod_arred_Q17);
    string(bin_prod_trunc_Q17);
    "00000001";
    "00000001";
    "-";
    "-";
    "-";
    "-";
    "-";
    "-";
    string(dec2bin(int_ov_1, 8));
    string(dec2bin(int_ov_2, 8));
    "010100000 (9 bits)";
    string(dec2bin(int_soma_saturada, 8));
    string(dec2bin(mod(int_soma_wrap, 256), 8))
    ];

Valor_Decimal = [
    op_a_Q17;
    op_b_Q17;
    prod_completo_Q214;
    frac_descartada_LSB * delta_Q17;
    prod_arred_Q17;
    prod_trunc_Q17;
    dif_arred_trunc;
    delta_Q17;
    0.5 * delta_Q17;
    delta_Q17;
    soma_abs_h;
    soma_h;
    bits_guarda_norma_L1;
    bits_guarda_pior_caso_N;
    op_ov_1;
    op_ov_2;
    soma_exata;
    soma_saturada;
    soma_wrap
    ];

Erro_Com_Sinal = [
    0;
    0;
    0;
    0;
    erro_arred;
    erro_trunc;
    dif_arred_trunc;
    0;
    0.5 * delta_Q17;
    -delta_Q17;
    0;
    0;
    0;
    0;
    0;
    0;
    0;
    soma_saturada - soma_exata;
    soma_wrap - soma_exata
    ];

Erro_Absoluto = [
    0;
    0;
    0;
    0;
    erro_abs_arred;
    erro_abs_trunc;
    abs(dif_arred_trunc);
    0;
    0.5 * delta_Q17;
    delta_Q17;
    0;
    0;
    0;
    0;
    0;
    0;
    0;
    erro_abs_saturada;
    erro_abs_wrap
    ];

Erro_Em_LSB_Q17 = [
    0;
    0;
    0;
    frac_descartada_LSB;
    erro_arred_LSB_Q17;
    erro_trunc_LSB_Q17;
    dif_arred_trunc_LSB;
    1.0;
    0.5;
    1.0;
    0;
    0;
    0;
    0;
    0;
    0;
    0;
    (soma_saturada - soma_exata) / delta_Q17;
    (soma_wrap - soma_exata) / delta_Q17
    ];

tab_E1 = table(Item, Formato, Representacao_Fracionaria, Representacao_Binaria, ...
    Valor_Decimal, Erro_Com_Sinal, Erro_Absoluto, Erro_Em_LSB_Q17);

caminho_tab_E1 = fullfile(specs.caminhos.results, 'tab_E1_produto_Q17.csv');
writetable(tab_E1, caminho_tab_E1);

fprintf('Tabela exportada com sucesso:\n');
fprintf('  - %s\n\n', caminho_tab_E1);

%% 7. Estrutura de Retorno
resultado_E.int_a_Q17               = int_a_Q17;
resultado_E.int_b_Q17               = int_b_Q17;
resultado_E.op_a_Q17                = op_a_Q17;
resultado_E.op_b_Q17                = op_b_Q17;
resultado_E.int_prod_Q214           = int_prod_Q214;
resultado_E.prod_completo_Q214      = prod_completo_Q214;
resultado_E.prod_em_LSB_Q17         = prod_em_LSB_Q17;
resultado_E.frac_descartada_LSB     = frac_descartada_LSB;
resultado_E.int_prod_arred_Q17      = int_prod_arred_Q17;
resultado_E.prod_arred_Q17          = prod_arred_Q17;
resultado_E.erro_arred              = erro_arred;
resultado_E.erro_abs_arred          = erro_abs_arred;
resultado_E.erro_arred_LSB_Q17      = erro_arred_LSB_Q17;
resultado_E.int_prod_trunc_Q17      = int_prod_trunc_Q17;
resultado_E.prod_trunc_Q17          = prod_trunc_Q17;
resultado_E.erro_trunc              = erro_trunc;
resultado_E.erro_abs_trunc          = erro_abs_trunc;
resultado_E.erro_trunc_LSB_Q17      = erro_trunc_LSB_Q17;
resultado_E.dif_arred_trunc         = dif_arred_trunc;
resultado_E.dif_arred_trunc_LSB     = dif_arred_trunc_LSB;
resultado_E.N                       = N;
resultado_E.soma_h                  = soma_h;
resultado_E.soma_abs_h              = soma_abs_h;
resultado_E.soma_abs_h_dB           = soma_abs_h_dB;
resultado_E.limite_saida_max        = limite_saida_max;
resultado_E.bits_guarda_norma_L1    = bits_guarda_norma_L1;
resultado_E.bits_guarda_pior_caso_N = bits_guarda_pior_caso_N;
resultado_E.op_ov_1                 = op_ov_1;
resultado_E.op_ov_2                 = op_ov_2;
resultado_E.soma_exata              = soma_exata;
resultado_E.soma_saturada           = soma_saturada;
resultado_E.erro_abs_saturada       = erro_abs_saturada;
resultado_E.soma_wrap               = soma_wrap;
resultado_E.erro_abs_wrap           = erro_abs_wrap;
resultado_E.tab_E1                  = tab_E1;
end
