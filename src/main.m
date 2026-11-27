% MAIN Orquestrador principal do Projeto de Filtro FIR Passa-Baixa (Pratica 3 - PDS).
%
%   Proposito:
%       Executar de ponta a ponta, a partir de uma sessao limpa e sem qualquer
%       intervencao manual, todas as etapas experimentais e analiticas da
%       Pratica 3 de Processamento Digital de Sinais (SENAI CIMATEC):
%         - Etapa A  : Projeto por serie de Fourier e janela de Hamming (etapa_A_janelamento.m)
%         - Etapa A2 : Comparacao com filtro Equiripple do Filter Designer (etapa_A2_equiripple.m)
%         - Etapa B  : Implementacao e validacao do buffer circular (etapa_B_validacao.m)
%         - Etapa C  : Quantizacao de coeficientes em Q1.7 e Q1.15 (etapa_C_quant_coef.m)
%         - Etapa D  : Quantizacao de amostras de entrada em Q1.7 e SNR (etapa_D_quant_amostras.m)
%         - Etapa E  : Precisao aritmetica em ponto fixo e overflow (etapa_E_ponto_fixo.m)
%
%       Ao final, consolida todas as metricas numericas oficiais em:
%         - results/resumo_metricas.txt    (relatorio textual completo para auditoria)
%         - results/metricas_relatorio.tex (macros LaTeX com fonte unica da verdade)
%       e verifica automaticamente a integridade de todos os arquivos .mat, .csv,
%       .tex, .pdf e .png gerados.
%
%   Disciplina: Processamento Digital de Sinais (SENAI CIMATEC)
%   Professor:  Elio Pithon Sarno Filho
%   Entrega:    02 de dezembro de 2026

%% 1. Inicializacao Limpa do Ambiente
clear; clc; close all;

t_inicio_total = tic; % Marcador de tempo inicial da execucao completa [s]

%% 2. Resolucao Portavel de Diretorios (Compativel com src/ e entrega/)
dir_main = fileparts(mfilename('fullpath')); % Diretorio onde main.m reside
addpath(dir_main);

dir_utils = fullfile(dir_main, 'utils'); % Subdiretorio de funcoes utilitarias
if isfolder(dir_utils)
    addpath(dir_utils);
end

specs = config_specs(); % Carrega especificacoes imutaveis e estrutura de caminhos

fprintf('======================================================================\n');
fprintf('PROJETO DE FILTRO FIR PASSA-BAIXA - EXECUCAO PONTA A PONTA (MAIN)\n');
fprintf('Disciplina : Processamento Digital de Sinais (SENAI CIMATEC)\n');
fprintf('Professor  : Elio Pithon Sarno Filho\n');
fprintf('Diretorio  : %s\n', specs.caminhos.raiz);
fprintf('======================================================================\n\n');

%% 3. Execucao Sequencial das Etapas A, A2, B, C, D e E
t_etapa = tic;
res_A  = etapa_A_janelamento();
tempo_A_s = toc(t_etapa); % Tempo de execucao da Etapa A [s]

t_etapa = tic;
res_A2 = etapa_A2_equiripple();
tempo_A2_s = toc(t_etapa); % Tempo de execucao da Etapa A2 [s]

t_etapa = tic;
res_B  = etapa_B_validacao();
tempo_B_s = toc(t_etapa); % Tempo de execucao da Etapa B [s]

t_etapa = tic;
res_C  = etapa_C_quant_coef();
tempo_C_s = toc(t_etapa); % Tempo de execucao da Etapa C [s]

t_etapa = tic;
res_D  = etapa_D_quant_amostras();
tempo_D_s = toc(t_etapa); % Tempo de execucao da Etapa D [s]

t_etapa = tic;
res_E  = etapa_E_ponto_fixo();
tempo_E_s = toc(t_etapa); % Tempo de execucao da Etapa E [s]

tempo_total_s = toc(t_inicio_total); % Tempo total de execucao do pipeline [s]

%% 4. Consolidacao de Metricas para o Relatorio (resumo_metricas.txt e metricas_relatorio.tex)
caminho_resumo_txt = fullfile(specs.caminhos.results, 'resumo_metricas.txt');
caminho_metricas_tex = fullfile(specs.caminhos.results, 'metricas_relatorio.tex');

% Extrai metricas auxiliares da Etapa A para N=21 e N=22 (comprimentos de fronteira na varredura)
idx_N21 = find(res_A.tab_A1.N == 21, 1);
idx_N22 = find(res_A.tab_A1.N == 22, 1);
desvio_N21_dB = res_A.tab_A1.Desvio_Pass_Max_dB(idx_N21); % Desvio passante para N=21 [dB]
aten_N21_dB   = res_A.tab_A1.Aten_Stop_Min_dB(idx_N21);   % Atenuacao rejeicao para N=21 [dB]
desvio_N22_dB = res_A.tab_A1.Desvio_Pass_Max_dB(idx_N22); % Desvio passante para N=22 [dB]
aten_N22_dB   = res_A.tab_A1.Aten_Stop_Min_dB(idx_N22);   % Atenuacao rejeicao para N=22 [dB]

% Extrai metricas da Etapa A2
reducao_coefs_perc = 100 * (res_A2.N_janelamento - res_A2.N_equiripple) / res_A2.N_janelamento; % Reducao percentual de coeficientes [%]
macs_seg_jan = res_A2.N_janelamento * specs.Fs; % Taxa de operacoes MAC/s no janelamento [MAC/s]
macs_seg_eq  = res_A2.N_equiripple  * specs.Fs; % Taxa de operacoes MAC/s no Equiripple [MAC/s]

% --- 4.1 Gravacao de results/resumo_metricas.txt ---
fid_txt = fopen(caminho_resumo_txt, 'w', 'n', 'UTF-8');
if fid_txt == -1
    error('Main:ErroEscritaResumo', 'Nao foi possivel abrir %s para escrita.', caminho_resumo_txt);
end

fprintf(fid_txt, '======================================================================\n');
fprintf(fid_txt, 'RESUMO CONSOLIDADO DE METRICAS - PROJETO FILTRO FIR PASSA-BAIXA\n');
fprintf(fid_txt, 'Disciplina : Processamento Digital de Sinais (SENAI CIMATEC) - Pratica 3\n');
fprintf(fid_txt, 'Professor  : Elio Pithon Sarno Filho\n');
fprintf(fid_txt, '======================================================================\n\n');

fprintf(fid_txt, '0. ESPECIFICACOES DA MASCARA\n');
fprintf(fid_txt, '  Frequencia de amostragem (Fs)          : %d Hz\n', specs.Fs);
fprintf(fid_txt, '  Banda passante (Fpass)                 : 0 a %d Hz\n', specs.Fpass);
fprintf(fid_txt, '  Desvio maximo na passante (tol_pass)   : +/-%.2f dB\n', specs.tol_pass_dB);
fprintf(fid_txt, '  Banda de rejeicao (Fstop)              : %d a %d Hz\n', specs.Fstop, specs.Fs / 2);
fprintf(fid_txt, '  Atenuacao minima na rejeicao (Astop)   : %.2f dB\n', specs.aten_stop_dB);
fprintf(fid_txt, '  Frequencia de corte ideal inicial (fc) : %d Hz\n', specs.fc);
fprintf(fid_txt, '  Grade de avaliacao espectral (Nfft)    : %d pontos\n\n', specs.Nfft);

fprintf(fid_txt, '1. ETAPA A - PROJETO POR SERIE DE FOURIER E JANELA DE HAMMING\n');
fprintf(fid_txt, '  Largura de transicao (delta_f)         : %.1f Hz (delta_omega = 0,3*pi = %.6f rad/amostra)\n', ...
    specs.Fstop - specs.Fpass, 2 * pi * (specs.Fstop - specs.Fpass) / specs.Fs);
fprintf(fid_txt, '  Estimativa inicial (fator 3,3)         : N_est = 22 coeficientes (Ordem 21)\n');
fprintf(fid_txt, '  Estimativa alternativa (fator 4,0)     : N_est_alt = 27 coeficientes (Ordem 26)\n');
fprintf(fid_txt, '  Fronteira N = 21 (Impar, Ordem 20)     : Desvio pass = %.6f dB | Aten stop = %.4f dB (Reprova stop)\n', ...
    desvio_N21_dB, aten_N21_dB);
fprintf(fid_txt, '  Fronteira N = 22 (Par, Ordem 21)       : Desvio pass = %.6f dB | Aten stop = %.4f dB (Reprova stop)\n', ...
    desvio_N22_dB, aten_N22_dB);
fprintf(fid_txt, '  Menor comprimento aprovado (N)         : %d coeficientes (Impar, Ordem M = %d)\n', res_A.N, res_A.ordem);
fprintf(fid_txt, '  Desvio maximo na banda passante        : %.6f dB (<= 0,10 dB)\n', res_A.desvio_pass_max_dB);
fprintf(fid_txt, '  Atenuacao minima na banda de rejeicao  : %.4f dB (>= 45,00 dB)\n', res_A.aten_stop_min_dB);
fprintf(fid_txt, '  Soma dos coeficientes sum(h[k])        : %.16f\n', res_A.soma_coef);
fprintf(fid_txt, '  Ganho DC                               : %.6f dB\n', res_A.ganho_dc_dB);
fprintf(fid_txt, '  Erro maximo de simetria                : %.4e\n', res_A.erro_simetria_max);
fprintf(fid_txt, '  Atraso de grupo constante              : %.1f amostras (%.4f ms)\n', ...
    res_A.atraso_grupo_amostras, res_A.atraso_grupo_ms);
fprintf(fid_txt, '  Erro maximo |h - fir1(M,fc,hamming)|   : %.6e\n', res_A.erro_max_fir1);
fprintf(fid_txt, '  Atraso medido via grpdelay (passante)  : %.6f amostras (desvio max = %.6e)\n\n', ...
    res_A.atraso_gd_medio, res_A.desvio_gd_max);

fprintf(fid_txt, '2. ETAPA A2 - COMPARACAO JANELAMENTO (HAMMING) VS EQUIRIPPLE (FILTER DESIGNER)\n');
fprintf(fid_txt, '  [Janelamento Hamming]\n');
fprintf(fid_txt, '    Numero de coeficientes (N)           : %d (Ordem M = %d)\n', res_A2.N_janelamento, res_A2.ordem_janelamento);
fprintf(fid_txt, '    Desvio maximo na passante            : %.6f dB\n', res_A2.aval_janelamento.desvio_pass_max_dB);
fprintf(fid_txt, '    Atenuacao minima na rejeicao         : %.4f dB\n', res_A2.aval_janelamento.aten_stop_min_dB);
fprintf(fid_txt, '    Ganho DC / Soma dos coeficientes     : %.6f dB (soma = %.6f)\n', ...
    res_A2.aval_janelamento.ganho_dc_dB, sum(res_A2.h_janelamento));
fprintf(fid_txt, '    Atraso de grupo                      : %.1f amostras (%.4f ms)\n', ...
    res_A2.ordem_janelamento / 2, (res_A2.ordem_janelamento / (2 * specs.Fs)) * 1000);
fprintf(fid_txt, '    Custo computacional a Fs = 8000 Hz   : %d MACs/amostra (%d MACs/s)\n', ...
    res_A2.N_janelamento, macs_seg_jan);
fprintf(fid_txt, '  [Equiripple Ordem Minima]\n');
fprintf(fid_txt, '    Numero de coeficientes (N_eq)        : %d (Ordem M_eq = %d)\n', res_A2.N_equiripple, res_A2.ordem_equiripple);
fprintf(fid_txt, '    Desvio maximo na passante            : %.6f dB\n', res_A2.aval_equiripple.desvio_pass_max_dB);
fprintf(fid_txt, '    Atenuacao minima na rejeicao         : %.4f dB\n', res_A2.aval_equiripple.aten_stop_min_dB);
fprintf(fid_txt, '    Ganho DC / Soma dos coeficientes     : %+.6f dB (soma = %.6f)\n', ...
    res_A2.aval_equiripple.ganho_dc_dB, sum(res_A2.h_equiripple));
fprintf(fid_txt, '    Atraso de grupo                      : %.1f amostras (%.4f ms)\n', ...
    res_A2.ordem_equiripple / 2, (res_A2.ordem_equiripple / (2 * specs.Fs)) * 1000);
fprintf(fid_txt, '    Custo computacional a Fs = 8000 Hz   : %d MACs/amostra (%d MACs/s | Reducao de %.2f%%)\n\n', ...
    res_A2.N_equiripple, macs_seg_eq, reducao_coefs_perc);

fprintf(fid_txt, '3. ETAPA B - IMPLEMENTACAO COM BUFFER CIRCULAR (fir_circular)\n');
fprintf(fid_txt, '  Erro max. Impulso (fir_circular vs filter)       : %.6e\n', res_B.erro_max_imp_filter);
fprintf(fid_txt, '  Erro max. Impulso (fir_circular(1:N) vs h[k])    : %.6e\n', res_B.erro_max_imp_h);
fprintf(fid_txt, '  Amplitude residual na cauda nula (n >= N)        : %.6e\n', res_B.erro_max_imp_cauda);
fprintf(fid_txt, '  Erro max. Duas Senoides (fir_circular vs filter) : %.6e\n', res_B.erro_max_sen_filter);
fprintf(fid_txt, '  Ganho via freqz em f1 = 500 Hz (Passante)        : |H| = %.8f (%+.6f dB | Desvio = %.6f dB <= 0,10 dB)\n', ...
    res_B.ganho_500_linear, res_B.ganho_500_dB, res_B.desvio_500_dB);
fprintf(fid_txt, '  Ganho via freqz em f2 = 3000 Hz (Rejeicao)       : |H| = %.8f (%.4f dB | Atenuacao = %.4f dB >= 45,00 dB)\n\n', ...
    res_B.ganho_3000_linear, res_B.ganho_3000_dB, res_B.atenuacao_3000_dB);

fprintf(fid_txt, '4. ETAPA C - QUANTIZACAO DOS COEFICIENTES (Q1.15 E Q1.7 SEM RENORMALIZAR)\n');
fprintf(fid_txt, '  [Q1.15 - F = 15 bits, Delta = 2^-15 = %.6e, Delta/2 = %.6e]\n', ...
    res_C.delta_Q115, res_C.delta_Q115 / 2);
fprintf(fid_txt, '    Erro absoluto maximo                 : %.6e (no coef. central k = 11)\n', res_C.erro_abs_max_Q115);
fprintf(fid_txt, '    Erro quadratico medio (EQM)          : %.6e\n', res_C.eqm_Q115);
fprintf(fid_txt, '    Coeficientes iguais a zero           : %d (k = [%s])\n', ...
    res_C.num_zeros_Q115, num2str(res_C.idx_zeros_Q115_k));
fprintf(fid_txt, '    Erro maximo de simetria              : %.4e\n', res_C.erro_sim_Q115);
fprintf(fid_txt, '    Soma dos coeficientes / Ganho DC     : %.8f (%+.6f dB)\n', ...
    res_C.soma_Q115, res_C.aval_Q115.ganho_dc_dB);
fprintf(fid_txt, '    Desvio max. passante / Aten. min.    : %.6f dB / %.4f dB (Atende mascara: %d)\n', ...
    res_C.aval_Q115.desvio_pass_max_dB, res_C.aval_Q115.aten_stop_min_dB, res_C.aval_Q115.atende_mascara);
fprintf(fid_txt, '  [Q1.7 - F = 7 bits, Delta = 2^-7 = %.7f, Delta/2 = %.8f]\n', ...
    res_C.delta_Q17, res_C.delta_Q17 / 2);
fprintf(fid_txt, '    Erro absoluto maximo                 : %.6e (no par simetrico k = 2 e k = 20)\n', res_C.erro_abs_max_Q17);
fprintf(fid_txt, '    Erro quadratico medio (EQM)          : %.6e\n', res_C.eqm_Q17);
fprintf(fid_txt, '    Coeficientes iguais a zero           : %d (k = [%s])\n', ...
    res_C.num_zeros_Q17, num2str(res_C.idx_zeros_Q17_k));
fprintf(fid_txt, '    Erro maximo de simetria              : %.4e\n', res_C.erro_sim_Q17);
fprintf(fid_txt, '    Soma dos coeficientes / Ganho DC     : %.8f (%+.6f dB)\n', ...
    res_C.soma_Q17, res_C.aval_Q17.ganho_dc_dB);
fprintf(fid_txt, '    Desvio max. passante / Aten. min.    : %.6f dB / %.4f dB (Atende mascara: %d)\n', ...
    res_C.aval_Q17.desvio_pass_max_dB, res_C.aval_Q17.aten_stop_min_dB, res_C.aval_Q17.atende_mascara);
fprintf(fid_txt, '  Norma L1 sum(|hQ|): Q1.15 = %.8f | Q1.7 = %.8f\n\n', ...
    res_C.soma_abs_Q115, res_C.soma_abs_Q17);

fprintf(fid_txt, '5. ETAPA D - QUANTIZACAO DAS AMOSTRAS DE ENTRADA EM Q1.7 E ANALISE DE SNR\n');
fprintf(fid_txt, '  Janela de regime permanente            : n = %d..%d (%d amostras = 48 periodos de 16 amostras)\n', ...
    res_D.n_inicio_regime, res_D.L - 1, res_D.L_regime);
fprintf(fid_txt, '  [Caso 1: x1[n] = 0,8*sen(2*pi*500*n/Fs)]\n');
fprintf(fid_txt, '    Erro abs. max. na entrada max|e[n]|  : %.6e <= Delta/2 = %.6e (%.2f%% de Delta/2)\n', ...
    res_D.caso1.erro_max_in, res_D.meio_delta, 100 * res_D.caso1.erro_max_in / res_D.meio_delta);
fprintf(fid_txt, '    Erro abs. max. na saida (regime)     : %.6e\n', res_D.caso1.erro_max_out_ss);
fprintf(fid_txt, '    Potencia do sinal (P_x -> P_y_ss)    : %.6f -> %.6f (%+.4f dB)\n', ...
    res_D.caso1.P_x, res_D.caso1.P_y_ss, res_D.caso1.var_pot_sinal_dB);
fprintf(fid_txt, '    Potencia do ruido (P_e -> P_ey_ss)   : %.6e -> %.6e (%+.4f dB)\n', ...
    res_D.caso1.P_e, res_D.caso1.P_ey_ss, res_D.caso1.var_pot_ruido_dB);
fprintf(fid_txt, '    SNR (Entrada -> Saida | Delta SNR)   : %.4f dB -> %.4f dB (%+.4f dB)\n', ...
    res_D.caso1.SNR_in_dB, res_D.caso1.SNR_out_dB, res_D.caso1.delta_SNR_dB);
fprintf(fid_txt, '  [Caso 2: x2[n] = 0,5*sen(2*pi*500*n/Fs) + 0,3*sen(2*pi*3000*n/Fs)]\n');
fprintf(fid_txt, '    Erro abs. max. na entrada max|e[n]|  : %.6e <= Delta/2 = %.6e (%.2f%% de Delta/2)\n', ...
    res_D.caso2.erro_max_in, res_D.meio_delta, 100 * res_D.caso2.erro_max_in / res_D.meio_delta);
fprintf(fid_txt, '    Erro abs. max. na saida (regime)     : %.6e\n', res_D.caso2.erro_max_out_ss);
fprintf(fid_txt, '    Potencia do sinal (P_x -> P_y_ss)    : %.6f -> %.6f (%+.4f dB)\n', ...
    res_D.caso2.P_x, res_D.caso2.P_y_ss, res_D.caso2.var_pot_sinal_dB);
fprintf(fid_txt, '    Potencia do ruido (P_e -> P_ey_ss)   : %.6e -> %.6e (%+.4f dB)\n', ...
    res_D.caso2.P_e, res_D.caso2.P_ey_ss, res_D.caso2.var_pot_ruido_dB);
fprintf(fid_txt, '    SNR (Entrada -> Saida | Delta SNR)   : %.4f dB -> %.4f dB (%+.4f dB)\n\n', ...
    res_D.caso2.SNR_in_dB, res_D.caso2.SNR_out_dB, res_D.caso2.delta_SNR_dB);

fprintf(fid_txt, '6. ETAPA E - PRECISAO ARITMETICA EM PONTO FIXO (Q1.7) E OVERFLOW\n');
fprintf(fid_txt, '  Operando a (Q1.7)                      : %d/128 = %.7f\n', res_E.int_a_Q17, res_E.op_a_Q17);
fprintf(fid_txt, '  Operando b (Q1.7)                      : %d/128 = %.7f\n', res_E.int_b_Q17, res_E.op_b_Q17);
fprintf(fid_txt, '  Produto completo exato a*b (Q2.14)     : %d/16384 = %.14f (%.7f/128)\n', ...
    res_E.int_prod_Q214, res_E.prod_completo_Q214, res_E.prod_em_LSB_Q17);
fprintf(fid_txt, '  Resultado arredondado p/ Q1.7 (round)  : %d/128 = %.7f (Erro = %+.14f = %+.7f LSB)\n', ...
    res_E.int_prod_arred_Q17, res_E.prod_arred_Q17, res_E.erro_arred, res_E.erro_arred_LSB_Q17);
fprintf(fid_txt, '  Resultado truncado p/ Q1.7 (floor)     : %d/128 = %.7f (Erro = %+.14f = %+.7f LSB)\n', ...
    res_E.int_prod_trunc_Q17, res_E.prod_trunc_Q17, res_E.erro_trunc, res_E.erro_trunc_LSB_Q17);
fprintf(fid_txt, '  Norma L1 dos coeficientes sum(|h[k]|)  : %.14f (%.4f dB)\n', ...
    res_E.soma_abs_h, res_E.soma_abs_h_dB);
fprintf(fid_txt, '  Bits de guarda no acumulador           : %d bit (norma L1) | %d bits (pior caso N=%d)\n', ...
    res_E.bits_guarda_norma_L1, res_E.bits_guarda_pior_caso_N, res_E.N);
fprintf(fid_txt, '  Exemplo overflow (0,75 + 0,50 = +1,25) : Saturacao = +%.7f (erro = %.7f) | Wrap-Around = %.7f (erro = %.7f)\n\n', ...
    res_E.soma_saturada, res_E.erro_abs_saturada, res_E.soma_wrap, res_E.erro_abs_wrap);
fprintf(fid_txt, '  Amplitude maxima de entrada (Aula 18)  : K = %d passos -> |x[n]| <= %.6f (pico %.4f | K+1: %.4f passos)\n', ...
    res_E.K_max_entrada, res_E.A_max_entrada, res_E.pico_saida_K_passos, res_E.pico_saida_K1_passos);
fprintf(fid_txt, '  Coeficientes / sum(|h|)                : ganho DC = %.6f (%.4f dB) antes de quantizar\n', ...
    res_E.ganho_dc_esc, res_E.ganho_dc_esc_dB);
fprintf(fid_txt, '  Escalonados em Q1.7 (armazenados)      : sum(|hq|) = %.7f | sum(hq) = %.7f (%.4f dB) | pico = %.7f (overflow = %d)\n', ...
    res_E.soma_abs_h_esc_Q17, res_E.soma_h_esc_Q17, res_E.ganho_dc_esc_Q17_dB, res_E.pico_esc_Q17, res_E.overflow_esc_Q17);
fprintf(fid_txt, '  Momento do arredondamento (exemplo)    : Q por ramo = %d/128 | Q apos soma = %d/128\n', ...
    res_E.saida_Q_por_ramo_LSB, res_E.saida_Q_apos_soma_LSB);
fprintf(fid_txt, '  Limite do erro (N = %d)                : Q por ramo <= %.8f | Q apos soma <= %.8f\n\n', ...
    res_E.N, res_E.erro_max_por_ramo, res_E.erro_max_apos_soma);

fprintf(fid_txt, '7. TEMPOS DE EXECUCAO\n');
fprintf(fid_txt, '  Etapa A  : %.3f s\n', tempo_A_s);
fprintf(fid_txt, '  Etapa A2 : %.3f s\n', tempo_A2_s);
fprintf(fid_txt, '  Etapa B  : %.3f s\n', tempo_B_s);
fprintf(fid_txt, '  Etapa C  : %.3f s\n', tempo_C_s);
fprintf(fid_txt, '  Etapa D  : %.3f s\n', tempo_D_s);
fprintf(fid_txt, '  Etapa E  : %.3f s\n', tempo_E_s);
fprintf(fid_txt, '  TOTAL    : %.3f s\n', tempo_total_s);

fclose(fid_txt);

% --- 4.2 Gravacao de results/metricas_relatorio.tex ---
fid_tex = fopen(caminho_metricas_tex, 'w', 'n', 'UTF-8');
if fid_tex == -1
    error('Main:ErroEscritaTex', 'Nao foi possivel abrir %s para escrita.', caminho_metricas_tex);
end

fprintf(fid_tex, '%% ======================================================================\n');
fprintf(fid_tex, '%% METRICAS OFICIAIS GERADAS AUTOMATICAMENTE POR src/main.m\n');
fprintf(fid_tex, '%% Fonte unica da verdade para o relatorio LaTeX (report/main.tex)\n');
fprintf(fid_tex, '%% ======================================================================\n\n');

% Etapa A
fprintf(fid_tex, '%% --- Etapa A: Projeto por Janelamento (Hamming) ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaAN}{%d}\n', res_A.N);
fprintf(fid_tex, '\\newcommand{\\MetricaAOrdem}{%d}\n', res_A.ordem);
fprintf(fid_tex, '\\newcommand{\\MetricaADesvioPassdB}{%.6f}\n', res_A.desvio_pass_max_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaAAtenStopdB}{%.4f}\n', res_A.aten_stop_min_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaASomaCoefs}{%.10f}\n', res_A.soma_coef);
fprintf(fid_tex, '\\newcommand{\\MetricaAGanhoDCdB}{%.6f}\n', res_A.ganho_dc_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaAErroSimetria}{%.4e}\n', res_A.erro_simetria_max);
fprintf(fid_tex, '\\newcommand{\\MetricaAAtrasoAmostras}{%.1f}\n', res_A.atraso_grupo_amostras);
fprintf(fid_tex, '\\newcommand{\\MetricaAAtrasoMs}{%.4f}\n', res_A.atraso_grupo_ms);
fprintf(fid_tex, '\\newcommand{\\MetricaAErroFirI}{%.6e}\n', res_A.erro_max_fir1);
fprintf(fid_tex, '\\newcommand{\\MetricaAAtrasoGdMedio}{%.6f}\n', res_A.atraso_gd_medio);
fprintf(fid_tex, '\\newcommand{\\MetricaAAtrasoGdDesvio}{%.6e}\n\n', res_A.desvio_gd_max);

% Etapa A2
fprintf(fid_tex, '%% --- Etapa A2: Comparacao com Equiripple ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqN}{%d}\n', res_A2.N_equiripple);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqOrdem}{%d}\n', res_A2.ordem_equiripple);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqDesvioPassdB}{%.6f}\n', res_A2.aval_equiripple.desvio_pass_max_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqAtenStopdB}{%.4f}\n', res_A2.aval_equiripple.aten_stop_min_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqGanhoDCdB}{%+.6f}\n', res_A2.aval_equiripple.ganho_dc_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqSomaCoefs}{%.6f}\n', sum(res_A2.h_equiripple));
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqAtrasoAmostras}{%.1f}\n', res_A2.ordem_equiripple / 2);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIEqAtrasoMs}{%.4f}\n', (res_A2.ordem_equiripple / (2 * specs.Fs)) * 1000);
fprintf(fid_tex, '\\newcommand{\\MetricaAIIReducaoCoefsPerc}{%.2f}\n\n', reducao_coefs_perc);

% Etapa B
fprintf(fid_tex, '%% --- Etapa B: Buffer Circular ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaBErroMaxImpFilter}{%.6e}\n', res_B.erro_max_imp_filter);
fprintf(fid_tex, '\\newcommand{\\MetricaBErroMaxImpH}{%.6e}\n', res_B.erro_max_imp_h);
fprintf(fid_tex, '\\newcommand{\\MetricaBErroMaxSenFilter}{%.6e}\n', res_B.erro_max_sen_filter);
fprintf(fid_tex, '\\newcommand{\\MetricaBGanhoPassLin}{%.8f}\n', res_B.ganho_500_linear);
fprintf(fid_tex, '\\newcommand{\\MetricaBGanhoPassdB}{%.6f}\n', res_B.ganho_500_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaBGanhoStopLin}{%.8f}\n', res_B.ganho_3000_linear);
fprintf(fid_tex, '\\newcommand{\\MetricaBGanhoStopdB}{%.4f}\n', res_B.ganho_3000_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaBAtenStopdB}{%.4f}\n\n', res_B.atenuacao_3000_dB);

% Etapa C
fprintf(fid_tex, '%% --- Etapa C: Quantizacao de Coeficientes ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaCErroMaxQXV}{%.6e}\n', res_C.erro_abs_max_Q115);
fprintf(fid_tex, '\\newcommand{\\MetricaCEQMQXV}{%.6e}\n', res_C.eqm_Q115);
fprintf(fid_tex, '\\newcommand{\\MetricaCSomaQXV}{%.8f}\n', res_C.soma_Q115);
fprintf(fid_tex, '\\newcommand{\\MetricaCGanhoDCQXVdB}{%.6f}\n', res_C.aval_Q115.ganho_dc_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCDesvioPassQXVdB}{%.6f}\n', res_C.aval_Q115.desvio_pass_max_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCAtenStopQXVdB}{%.4f}\n', res_C.aval_Q115.aten_stop_min_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCErroMaxQVII}{%.6e}\n', res_C.erro_abs_max_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaCEQMQVII}{%.6e}\n', res_C.eqm_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaCSomaQVII}{%.8f}\n', res_C.soma_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaCGanhoDCQVIIdB}{%.6f}\n', res_C.aval_Q17.ganho_dc_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCDesvioPassQVIIdB}{%.6f}\n', res_C.aval_Q17.desvio_pass_max_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCAtenStopQVIIdB}{%.4f}\n', res_C.aval_Q17.aten_stop_min_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaCSomaAbsQXV}{%.8f}\n', res_C.soma_abs_Q115);
fprintf(fid_tex, '\\newcommand{\\MetricaCSomaAbsQVII}{%.8f}\n\n', res_C.soma_abs_Q17);

% Etapa D
fprintf(fid_tex, '%% --- Etapa D: Quantizacao de Amostras (Q1.7) ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoISNRIn}{%.4f}\n', res_D.caso1.SNR_in_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoISNROut}{%.4f}\n', res_D.caso1.SNR_out_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoIDeltaSNR}{%+.4f}\n', res_D.caso1.delta_SNR_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoIISNRIn}{%.4f}\n', res_D.caso2.SNR_in_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoIISNROut}{%.4f}\n', res_D.caso2.SNR_out_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaDCasoIIDeltaSNR}{%+.4f}\n\n', res_D.caso2.delta_SNR_dB);

% Etapa E
fprintf(fid_tex, '%% --- Etapa E: Precisao Aritmetica e Overflow ---\n');
fprintf(fid_tex, '\\newcommand{\\MetricaEProdCompleto}{%.14f}\n', res_E.prod_completo_Q214);
fprintf(fid_tex, '\\newcommand{\\MetricaEProdArred}{%.7f}\n', res_E.prod_arred_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaEErroArred}{%+.14f}\n', res_E.erro_arred);
fprintf(fid_tex, '\\newcommand{\\MetricaEProdTrunc}{%.7f}\n', res_E.prod_trunc_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaEErroTrunc}{%+.14f}\n', res_E.erro_trunc);
fprintf(fid_tex, '\\newcommand{\\MetricaENormaLI}{%.14f}\n', res_E.soma_abs_h);
fprintf(fid_tex, '\\newcommand{\\MetricaENormaLIdB}{%.4f}\n', res_E.soma_abs_h_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaEKMax}{%d}\n', res_E.K_max_entrada);
fprintf(fid_tex, '\\newcommand{\\MetricaEAMax}{%.6f}\n', res_E.A_max_entrada);
fprintf(fid_tex, '\\newcommand{\\MetricaEPicoK}{%.4f}\n', res_E.pico_saida_K_passos);
fprintf(fid_tex, '\\newcommand{\\MetricaEPicoKI}{%.4f}\n', res_E.pico_saida_K1_passos);
fprintf(fid_tex, '\\newcommand{\\MetricaEGanhoDCEsc}{%.6f}\n', res_E.ganho_dc_esc);
fprintf(fid_tex, '\\newcommand{\\MetricaEGanhoDCEscdB}{%.4f}\n', res_E.ganho_dc_esc_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaESomaAbsEscQ}{%.7f}\n', res_E.soma_abs_h_esc_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaESomaAbsEscQInt}{%d}\n', round(res_E.soma_abs_h_esc_Q17 * 128));
fprintf(fid_tex, '\\newcommand{\\MetricaESomaEscQ}{%.7f}\n', res_E.soma_h_esc_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaESomaEscQInt}{%d}\n', round(res_E.soma_h_esc_Q17 * 128));
fprintf(fid_tex, '\\newcommand{\\MetricaEGanhoDCEscQdB}{%.4f}\n', res_E.ganho_dc_esc_Q17_dB);
fprintf(fid_tex, '\\newcommand{\\MetricaEPicoEscQ}{%.7f}\n', res_E.pico_esc_Q17);
fprintf(fid_tex, '\\newcommand{\\MetricaEQRamo}{%d}\n', res_E.saida_Q_por_ramo_LSB);
fprintf(fid_tex, '\\newcommand{\\MetricaEQSoma}{%d}\n', res_E.saida_Q_apos_soma_LSB);
fprintf(fid_tex, '\\newcommand{\\MetricaEErroRamo}{%.8f}\n', res_E.erro_max_por_ramo);
fprintf(fid_tex, '\\newcommand{\\MetricaEErroSoma}{%.8f}\n', res_E.erro_max_apos_soma);

fclose(fid_tex);

%% 5. Auditoria Automatica de Todos os Artefatos Gerados
arquivos_esperados = {
    fullfile(specs.caminhos.data,    'coeficientes_FIR.mat');
    fullfile(specs.caminhos.data,    'coeficientes_equiripple.mat');
    fullfile(specs.caminhos.results, 'tab_A1_varredura_N.csv');
    fullfile(specs.caminhos.results, 'tab_A2_metricas_finais.csv');
    fullfile(specs.caminhos.results, 'tab_A2_comparacao_equiripple.csv');
    fullfile(specs.caminhos.results, 'tab_B1_erros_e_ganhos.csv');
    fullfile(specs.caminhos.results, 'tab_C1_coeficientes_erros.csv');
    fullfile(specs.caminhos.results, 'tab_C2_metricas_quant_coef.csv');
    fullfile(specs.caminhos.results, 'tab_D1_snr_comparacao.csv');
    fullfile(specs.caminhos.results, 'tab_E1_produto_Q17.csv');
    fullfile(specs.caminhos.results, 'tab_E2_limite_amplitude.csv');
    fullfile(specs.caminhos.results, 'resumo_metricas.txt');
    fullfile(specs.caminhos.results, 'metricas_relatorio.tex');
    fullfile(specs.caminhos.figures, 'fig_A1_impulso_janela.pdf');
    fullfile(specs.caminhos.figures, 'fig_A1_impulso_janela.png');
    fullfile(specs.caminhos.figures, 'fig_A2_magnitude_mascara.pdf');
    fullfile(specs.caminhos.figures, 'fig_A2_magnitude_mascara.png');
    fullfile(specs.caminhos.figures, 'fig_A2_comp_janelamento_equiripple.pdf');
    fullfile(specs.caminhos.figures, 'fig_A2_comp_janelamento_equiripple.png');
    fullfile(specs.caminhos.figures, 'fig_B1_impulso_comparacao.pdf');
    fullfile(specs.caminhos.figures, 'fig_B1_impulso_comparacao.png');
    fullfile(specs.caminhos.figures, 'fig_B2_senoides_temporal.pdf');
    fullfile(specs.caminhos.figures, 'fig_B2_senoides_temporal.png');
    fullfile(specs.caminhos.figures, 'fig_C1_respostas_quant_coef.pdf');
    fullfile(specs.caminhos.figures, 'fig_C1_respostas_quant_coef.png');
    fullfile(specs.caminhos.figures, 'fig_D1_caso1_amostras_e_erros.pdf');
    fullfile(specs.caminhos.figures, 'fig_D1_caso1_amostras_e_erros.png');
    fullfile(specs.caminhos.figures, 'fig_D2_caso2_amostras_e_erros.pdf');
    fullfile(specs.caminhos.figures, 'fig_D2_caso2_amostras_e_erros.png')
    };

fprintf('======================================================================\n');
fprintf('AUDITORIA FINAL DE ARTEFATOS GERADOS (%d arquivos verificados)\n', numel(arquivos_esperados));
fprintf('======================================================================\n');

todos_integros = true; % Indicador logico de integridade global dos arquivos [logico]
for idx_arq = 1:numel(arquivos_esperados)
    caminho_arq = arquivos_esperados{idx_arq};
    info_arq = dir(caminho_arq);
    if isempty(info_arq) || info_arq(1).bytes == 0
        todos_integros = false;
        fprintf('  [FALHA] Arquivo ausente ou vazio: %s\n', caminho_arq);
    else
        fprintf('  [OK] %-44s (%8d bytes)\n', info_arq(1).name, info_arq(1).bytes);
    end
end

if ~todos_integros
    error('Main:AuditoriaFalhou', 'Um ou mais arquivos obrigatorios nao foram gerados corretamente.');
end

fprintf('----------------------------------------------------------------------\n');
fprintf('PIPELINE COMPLETO EXECUTADO COM SUCESSO EM %.2f SEGUNDOS!\n', tempo_total_s);
fprintf('Resumo consolidado salvo em:\n');
fprintf('  - %s\n', caminho_resumo_txt);
fprintf('  - %s\n', caminho_metricas_tex);
fprintf('======================================================================\n');
