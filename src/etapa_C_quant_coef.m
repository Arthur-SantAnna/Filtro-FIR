function resultado_C = etapa_C_quant_coef()
% ETAPA_C_QUANT_COEF Investigacao dos efeitos da quantizacao de coeficientes em Q1.7 e Q1.15.
%
%   Proposito:
%       Implementar integralmente a Etapa C da Pratica 3:
%       1. Carregar os coeficientes originais normalizados h (em ponto flutuante
%          de precisao dupla) gerados na Etapa A (data/coeficientes_FIR.mat).
%       2. Quantizar separadamente os coeficientes nos formatos de ponto fixo
%          Q1.7 (F = 7 bits fracionarios) e Q1.15 (F = 15 bits fracionarios)
%          por arredondamento ao nivel representavel mais proximo:
%          hQ = round(h * 2^F) / 2^F, SEM renormalizar apos a quantizacao.
%       3. Calcular erro individual por coeficiente, erro absoluto maximo,
%          erro quadratico medio (EQM), quantidade e indices de coeficientes
%          anulados (quantizados para zero), soma dos coeficientes, ganho DC,
%          erro maximo de simetria e desempenho frente a mascara (via
%          avaliar_mascara.m) para as tres versoes: Original (double), Q1.15 e Q1.7.
%       4. Exportar as tabelas results/tab_C1_coeficientes_erros.csv e
%          results/tab_C2_metricas_quant_coef.csv.
%       5. Gerar e exportar a figura figures/fig_C1_respostas_quant_coef (.pdf e .png)
%          com a resposta em magnitude de 0 a 4.000 Hz e ampliacoes na banda
%          passante (0 a 1.000 Hz) e na banda de rejeicao (2.200 a 4.000 Hz).
%
%   Saidas:
%       resultado_C - Estrutura contendo os vetores quantizados, erros,
%                     avaliacoes da mascara e tabelas geradas na Etapa C.
%
%   Disciplina: Processamento Digital de Sinais (SENAI CIMATEC)
%   Professor:  Elio Pithon Sarno Filho

%% 1. Configuracao de Caminhos e Carregamento das Especificacoes e Coeficientes
dir_script = fileparts(mfilename('fullpath'));
addpath(dir_script);
if isfolder(fullfile(dir_script, 'utils'))
    addpath(fullfile(dir_script, 'utils'));
end

specs = config_specs();

Fs           = specs.Fs;           % Frequencia de amostragem [Hz]
Fpass        = specs.Fpass;        % Frequencia limite da banda passante [Hz]
Fstop        = specs.Fstop;        % Frequencia inicial da banda de rejeicao [Hz]
tol_pass_dB  = specs.tol_pass_dB;  % Desvio maximo permitido na banda passante [dB]
aten_stop_dB = specs.aten_stop_dB; % Atenuacao minima exigida na banda de rejeicao [dB]

caminho_mat = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
if ~isfile(caminho_mat)
    error('EtapaC:ArquivoNaoEncontrado', ...
        'Arquivo %s nao encontrado. Execute a Etapa A antes da Etapa C.', caminho_mat);
end

dados_A = load(caminho_mat, 'h', 'N', 'ordem');
h     = dados_A.h(:).'; % Vetor linha de coeficientes originais normalizados (double) [adimensional]
N     = numel(h);       % Comprimento do filtro (numero de coeficientes) [coeficientes]
ordem = N - 1;          % Ordem do filtro FIR M = N - 1 [adimensional]
k_ind = (0:(N - 1)).';  % Vetor coluna de indices dos coeficientes k = 0, ..., N-1 [amostras]

fprintf('======================================================================\n');
fprintf('ETAPA C - QUANTIZACAO DOS COEFICIENTES DO FILTRO FIR (Q1.7 E Q1.15)\n');
fprintf('======================================================================\n');
fprintf('Filtro carregado: N = %d coeficientes (Ordem M = %d)\n\n', N, ordem);

%% 2. Quantizacao dos Coeficientes em Q1.7 (F = 7) e Q1.15 (F = 15) sem Renormalizar
F_Q17  = 7;              % Numero de bits fracionarios no formato Q1.7 [bits]
F_Q115 = 15;             % Numero de bits fracionarios no formato Q1.15 [bits]

delta_Q17  = 2^(-F_Q17);  % Passo de quantizacao (1 LSB) para Q1.7 [adimensional]
delta_Q115 = 2^(-F_Q115); % Passo de quantizacao (1 LSB) para Q1.15 [adimensional]

meio_delta_Q17  = delta_Q17 / 2;  % Limiar teorico de erro de arredondamento (Delta/2) em Q1.7 [adimensional]
meio_delta_Q115 = delta_Q115 / 2; % Limiar teorico de erro de arredondamento (Delta/2) em Q1.15 [adimensional]

% Arredondamento ao nivel representavel mais proximo (sem renormalizacao posterior)
h_Q17  = round(h * (2^F_Q17))  / (2^F_Q17);  % Coeficientes quantizados em Q1.7 [adimensional]
h_Q115 = round(h * (2^F_Q115)) / (2^F_Q115); % Coeficientes quantizados em Q1.15 [adimensional]

% Normaliza eventual -0.0 de ponto flutuante IEEE 754 para +0.0
h_Q17(h_Q17 == 0)   = 0;
h_Q115(h_Q115 == 0) = 0;

%% 3. Calculo dos Erros de Quantizacao, Simetria, Soma e Coeficientes Anulados
erro_orig = zeros(1, N);   % Erro de quantizacao da versao original em double [adimensional]
erro_Q17  = h_Q17  - h;    % Erro individual de quantizacao em Q1.7: e_k = hQ - h [adimensional]
erro_Q115 = h_Q115 - h;    % Erro individual de quantizacao em Q1.15: e_k = hQ - h [adimensional]

% Erro absoluto maximo e indice onde ocorre
[erro_abs_max_orig, ~]          = max(abs(erro_orig)); % Erro absoluto maximo original [adimensional]
[erro_abs_max_Q17, idx_max_Q17]   = max(abs(erro_Q17));  % Erro absoluto maximo em Q1.7 [adimensional]
[erro_abs_max_Q115, idx_max_Q115] = max(abs(erro_Q115)); % Erro absoluto maximo em Q1.15 [adimensional]

% Erro relativo percentual por coeficiente: 100 * |hQ - h| / |h|
erro_rel_perc_Q17  = 100 * abs(erro_Q17)  ./ max(abs(h), eps); % Erro relativo em Q1.7 [%]
erro_rel_perc_Q115 = 100 * abs(erro_Q115) ./ max(abs(h), eps); % Erro relativo em Q1.15 [%]

% Erro quadratico medio (EQM)
eqm_orig = mean(erro_orig.^2); % Erro quadratico medio original [adimensional^2]
eqm_Q17  = mean(erro_Q17.^2);  % Erro quadratico medio em Q1.7 [adimensional^2]
eqm_Q115 = mean(erro_Q115.^2); % Erro quadratico medio em Q1.15 [adimensional^2]

% Identificacao de coeficientes quantizados para zero
mask_zero_orig = (abs(h) == 0);      % Mascara de coeficientes nulos no original [logico]
mask_zero_Q17  = (abs(h_Q17) == 0);  % Mascara de coeficientes nulos em Q1.7 [logico]
mask_zero_Q115 = (abs(h_Q115) == 0); % Mascara de coeficientes nulos em Q1.15 [logico]

num_zeros_orig = sum(mask_zero_orig); % Quantidade de coeficientes iguais a zero no original [coeficientes]
num_zeros_Q17  = sum(mask_zero_Q17);  % Quantidade de coeficientes iguais a zero em Q1.7 [coeficientes]
num_zeros_Q115 = sum(mask_zero_Q115); % Quantidade de coeficientes iguais a zero em Q1.15 [coeficientes]

idx_zeros_Q17_k  = k_ind(mask_zero_Q17).';  % Indices k (0..N-1) dos coeficientes zerados em Q1.7 [amostras]
idx_zeros_Q115_k = k_ind(mask_zero_Q115).'; % Indices k (0..N-1) dos coeficientes zerados em Q1.15 [amostras]

% Soma dos coeficientes e erro de simetria par max|hQ[k] - hQ[N-1-k]|
soma_orig = sum(h);      % Soma dos coeficientes originais [adimensional]
soma_Q17  = sum(h_Q17);  % Soma dos coeficientes quantizados em Q1.7 [adimensional]
soma_Q115 = sum(h_Q115); % Soma dos coeficientes quantizados em Q1.15 [adimensional]

% Soma dos modulos (norma L1) dos coeficientes efetivamente armazenados.
% A Aula 18 recomenda conferir sum(abs(hq)) para o limite de pico da saida,
% sum(hq) para o ganho DC e freqz(hq,1,...) para a mascara.
soma_abs_orig = sum(abs(h));      % Norma L1 dos coeficientes originais [adimensional]
soma_abs_Q17  = sum(abs(h_Q17));  % Norma L1 dos coeficientes quantizados em Q1.7 [adimensional]
soma_abs_Q115 = sum(abs(h_Q115)); % Norma L1 dos coeficientes quantizados em Q1.15 [adimensional]

erro_sim_orig = max(abs(h      - fliplr(h)));      % Erro maximo de simetria no original [adimensional]
erro_sim_Q17  = max(abs(h_Q17  - fliplr(h_Q17)));  % Erro maximo de simetria em Q1.7 [adimensional]
erro_sim_Q115 = max(abs(h_Q115 - fliplr(h_Q115))); % Erro maximo de simetria em Q1.15 [adimensional]

%% 4. Avaliacao da Resposta em Frequencia e Conformidade com a Mascara
aval_orig = avaliar_mascara(h,      specs); % Avaliacao espectral para h original (double)
aval_Q115 = avaliar_mascara(h_Q115, specs); % Avaliacao espectral para h_Q115
aval_Q17  = avaliar_mascara(h_Q17,  specs); % Avaliacao espectral para h_Q17

%% 5. Exibicao Detalhada no Console e Exportacao das Tabelas CSV
fprintf('--- Tabela C1: Coeficientes e Erros de Quantizacao ---\n');
fprintf('%-3s | %-14s | %-14s | %-14s | %-14s | %-14s\n', ...
    'k', 'h_original', 'h_Q17', 'erro_Q17', 'h_Q115', 'erro_Q115');
fprintf('%s\n', repmat('-', 1, 88));
for i = 1:N
    fprintf('%-3d | %14.10f | %14.10f | %+14.10f | %14.10f | %+14.10f\n', ...
        k_ind(i), h(i), h_Q17(i), erro_Q17(i), h_Q115(i), erro_Q115(i));
end

% Exporta results/tab_C1_coeficientes_erros.csv
tab_C1 = table(k_ind, h(:), h_Q17(:), erro_Q17(:), h_Q115(:), erro_Q115(:), ...
    'VariableNames', {'k', 'h_original', 'h_Q17', 'erro_Q17', 'h_Q115', 'erro_Q115'});
caminho_tab_C1 = fullfile(specs.caminhos.results, 'tab_C1_coeficientes_erros.csv');
writetable(tab_C1, caminho_tab_C1);

% Monta e exporta results/tab_C2_metricas_quant_coef.csv
Versao = ["Original (double)"; "Q1.15"; "Q1.7"];
Bits_Fracionarios = [53; F_Q115; F_Q17]; % Bits de precisao fracionaria [bits]
Passo_Delta = [eps; delta_Q115; delta_Q17]; % Passo de quantizacao Delta [adimensional]
Limite_Meio_Delta = [eps/2; meio_delta_Q115; meio_delta_Q17]; % Limite teorico Delta/2 [adimensional]
Erro_Abs_Max = [erro_abs_max_orig; erro_abs_max_Q115; erro_abs_max_Q17]; % Erro absoluto maximo [adimensional]
EQM = [eqm_orig; eqm_Q115; eqm_Q17]; % Erro quadratico medio [adimensional^2]
Coefs_Zerados = [num_zeros_orig; num_zeros_Q115; num_zeros_Q17]; % Quantidade de coeficientes zerados [coeficientes]
Erro_Max_Simetria = [erro_sim_orig; erro_sim_Q115; erro_sim_Q17]; % Erro maximo de simetria [adimensional]
Soma_Coeficientes = [soma_orig; soma_Q115; soma_Q17]; % Soma dos coeficientes [adimensional]
Soma_Modulos = [soma_abs_orig; soma_abs_Q115; soma_abs_Q17]; % Norma L1 sum(|hQ[k]|) [adimensional]
Ganho_DC_dB = [aval_orig.ganho_dc_dB; aval_Q115.ganho_dc_dB; aval_Q17.ganho_dc_dB]; % Ganho DC [dB]
Desvio_Pass_Max_dB = [aval_orig.desvio_pass_max_dB; aval_Q115.desvio_pass_max_dB; aval_Q17.desvio_pass_max_dB]; % Desvio maximo na passante [dB]
Aten_Stop_Min_dB = [aval_orig.aten_stop_min_dB; aval_Q115.aten_stop_min_dB; aval_Q17.aten_stop_min_dB]; % Atenuacao minima na rejeicao [dB]
Atende_Pass = [aval_orig.atende_pass; aval_Q115.atende_pass; aval_Q17.atende_pass]; % Conformidade na passante [logico]
Atende_Stop = [aval_orig.atende_stop; aval_Q115.atende_stop; aval_Q17.atende_stop]; % Conformidade na rejeicao [logico]
Atende_Mascara = [aval_orig.atende_mascara; aval_Q115.atende_mascara; aval_Q17.atende_mascara]; % Conformidade global [logico]

tab_C2 = table(Versao, Bits_Fracionarios, Passo_Delta, Limite_Meio_Delta, ...
    Erro_Abs_Max, EQM, Coefs_Zerados, Erro_Max_Simetria, ...
    Soma_Coeficientes, Soma_Modulos, Ganho_DC_dB, Desvio_Pass_Max_dB, Aten_Stop_Min_dB, ...
    Atende_Pass, Atende_Stop, Atende_Mascara);
caminho_tab_C2 = fullfile(specs.caminhos.results, 'tab_C2_metricas_quant_coef.csv');
writetable(tab_C2, caminho_tab_C2);

fprintf('\n--- Tabela C2: Resumo Comparativo das Metricas de Quantizacao ---\n');
fprintf('  Versao            | Delta        | Erro Abs Max | EQM          | Zeros | Soma Coefs | Ganho DC [dB] | Desvio Pass [dB] | Aten Stop [dB] | Atende?\n');
fprintf('%s\n', repmat('-', 1, 142));
for i = 1:3
    fprintf('  %-17s | %12.4e | %12.4e | %12.4e | %5d | %10.7f | %+13.6f | %16.6f | %14.4f | %d\n', ...
        Versao(i), Passo_Delta(i), Erro_Abs_Max(i), EQM(i), Coefs_Zerados(i), ...
        Soma_Coeficientes(i), Ganho_DC_dB(i), Desvio_Pass_Max_dB(i), Aten_Stop_Min_dB(i), Atende_Mascara(i));
end
fprintf('----------------------------------------------------------------------\n');
fprintf('Detalhes adicionais:\n');
fprintf('  - Q1.7 : Maior erro absoluto = %.6e (limite Delta/2 = %.6e) em k = %d (e simetrico k = %d)\n', ...
    erro_abs_max_Q17, meio_delta_Q17, idx_max_Q17 - 1, N - idx_max_Q17);
fprintf('  - Q1.7 : Coeficientes quantizados para zero (%d): k = [%s]\n', ...
    num_zeros_Q17, num2str(idx_zeros_Q17_k));
fprintf('  - Q1.15: Maior erro absoluto = %.6e (limite Delta/2 = %.6e) em k = %d (e simetrico k = %d)\n', ...
    erro_abs_max_Q115, meio_delta_Q115, idx_max_Q115 - 1, N - idx_max_Q115);
fprintf('  - Q1.15: Coeficientes quantizados para zero (%d): k = [%s]\n', ...
    num_zeros_Q115, num2str(idx_zeros_Q115_k));
fprintf('  - Norma L1 sum(|h|): Original = %.8f | Q1.15 = %.8f | Q1.7 = %.8f\n\n', ...
    soma_abs_orig, soma_abs_Q115, soma_abs_Q17);

%% 6. Geracao da Figura fig_C1_respostas_quant_coef (Visao Global + Ampliacoes)
f_Hz        = aval_orig.f_Hz;   % Vetor de frequencia [Hz]
mag_orig_dB = aval_orig.mag_dB; % Magnitude do filtro original (double) [dB]
mag_Q115_dB = aval_Q115.mag_dB; % Magnitude do filtro quantizado em Q1.15 [dB]
mag_Q17_dB  = aval_Q17.mag_dB;  % Magnitude do filtro quantizado em Q1.7 [dB]

cor_orig = [0.00, 0.45, 0.74]; % Azul para Original (double)
cor_Q115 = [0.13, 0.55, 0.13]; % Verde para Q1.15
cor_Q17  = [0.85, 0.33, 0.10]; % Laranja/vermelho para Q1.7

fig_C1 = figure('Name', 'Etapa C - Resposta em Magnitude com Coeficientes Quantizados', ...
    'Position', [100, 100, 960, 720], 'Visible', 'off');
tiledlayout(fig_C1, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Painel 1 (Superior, 2 colunas): Resposta em magnitude de 0 a 4000 Hz
nexttile([1, 2]);
plot(f_Hz, mag_orig_dB, '-',  'Color', cor_orig, 'LineWidth', 1.6);
hold on;
plot(f_Hz, mag_Q115_dB, '--', 'Color', cor_Q115, 'LineWidth', 1.3);
plot(f_Hz, mag_Q17_dB,  '-.', 'Color', cor_Q17,  'LineWidth', 1.4);
% Limites da mascara
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], ':r', 'LineWidth', 1.2);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], ':r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
xline(Fpass, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.9, 'HandleVisibility', 'off');
xline(Fstop, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.9, 'HandleVisibility', 'off');
hold off;
title(sprintf('Resposta em Magnitude |H(f)|: Original (double) vs. Q1.15 vs. Q1.7 (N = %d)', N));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, Fs/2]);
ylim([-100, 5]);
legend({'Original (double)', ...
    'Quantizado Q1.15 (16 bits)', ...
    'Quantizado Q1.7 (8 bits)', ...
    sprintf('Limite passante (\\pm%.1f dB até %d Hz)', tol_pass_dB, Fpass), ...
    sprintf('Limite rejeição (-%d dB a partir de %d Hz)', round(aten_stop_dB), Fstop)}, ...
    'Location', 'southwest');

% Painel 2 (Inferior esquerdo): Ampliacao da Banda Passante (0 a 1000 Hz)
nexttile;
idx_zoom_pass = (f_Hz >= 0) & (f_Hz <= 1100);
plot(f_Hz(idx_zoom_pass), mag_orig_dB(idx_zoom_pass), '-',  'Color', cor_orig, 'LineWidth', 1.6);
hold on;
plot(f_Hz(idx_zoom_pass), mag_Q115_dB(idx_zoom_pass), '--', 'Color', cor_Q115, 'LineWidth', 1.3);
plot(f_Hz(idx_zoom_pass), mag_Q17_dB(idx_zoom_pass),  '-.', 'Color', cor_Q17,  'LineWidth', 1.4);
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], '--r', 'LineWidth', 1.2);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], '--r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(Fpass, ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
yline(0, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.8, 'HandleVisibility', 'off');
hold off;
title(sprintf('Ampliação na Banda Passante (0 a %d Hz)', Fpass));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, 1050]);
ylim([-0.28, 0.15]);
legend({'Original (double)', ...
    sprintf('Q1.15 (desvio = %.4f dB)', aval_Q115.desvio_pass_max_dB), ...
    sprintf('Q1.7 (desvio = %.4f dB)', aval_Q17.desvio_pass_max_dB), ...
    sprintf('Máscara \\pm%.1f dB', tol_pass_dB)}, ...
    'Location', 'south');

% Painel 3 (Inferior direito): Ampliacao da Banda de Rejeicao (2200 a 4000 Hz)
nexttile;
idx_zoom_stop = (f_Hz >= 2100) & (f_Hz <= Fs/2);
plot(f_Hz(idx_zoom_stop), mag_orig_dB(idx_zoom_stop), '-',  'Color', cor_orig, 'LineWidth', 1.6);
hold on;
plot(f_Hz(idx_zoom_stop), mag_Q115_dB(idx_zoom_stop), '--', 'Color', cor_Q115, 'LineWidth', 1.3);
plot(f_Hz(idx_zoom_stop), mag_Q17_dB(idx_zoom_stop),  '-.', 'Color', cor_Q17,  'LineWidth', 1.4);
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
xline(Fstop, ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
hold off;
title(sprintf('Ampliação na Banda de Rejeição (%d a %d Hz)', Fstop, Fs/2));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([2150, Fs/2]);
ylim([-95, -25]);
legend({'Original (double)', ...
    sprintf('Q1.15 (aten. mín = %.2f dB)', aval_Q115.aten_stop_min_dB), ...
    sprintf('Q1.7 (aten. mín = %.2f dB)', aval_Q17.aten_stop_min_dB), ...
    sprintf('Máscara -%d dB', round(aten_stop_dB))}, ...
    'Location', 'northeast');

salvar_figura(fig_C1, 'fig_C1_respostas_quant_coef', specs);
close(fig_C1);

fprintf('Arquivos da Etapa C exportados com sucesso:\n');
fprintf('  - %s\n', caminho_tab_C1);
fprintf('  - %s\n', caminho_tab_C2);
fprintf('  - %s (.pdf e .png)\n\n', fullfile(specs.caminhos.figures, 'fig_C1_respostas_quant_coef'));

%% 7. Empacotamento da Estrutura de Retorno
resultado_C.N                  = N;
resultado_C.ordem              = ordem;
resultado_C.k                  = k_ind;
resultado_C.h_original         = h;
resultado_C.h_Q17              = h_Q17;
resultado_C.h_Q115             = h_Q115;
resultado_C.erro_Q17           = erro_Q17;
resultado_C.erro_Q115          = erro_Q115;
resultado_C.erro_rel_perc_Q17  = erro_rel_perc_Q17;
resultado_C.erro_rel_perc_Q115 = erro_rel_perc_Q115;
resultado_C.delta_Q17          = delta_Q17;
resultado_C.delta_Q115         = delta_Q115;
resultado_C.erro_abs_max_Q17   = erro_abs_max_Q17;
resultado_C.erro_abs_max_Q115  = erro_abs_max_Q115;
resultado_C.eqm_Q17            = eqm_Q17;
resultado_C.eqm_Q115           = eqm_Q115;
resultado_C.num_zeros_Q17      = num_zeros_Q17;
resultado_C.num_zeros_Q115     = num_zeros_Q115;
resultado_C.idx_zeros_Q17_k    = idx_zeros_Q17_k;
resultado_C.idx_zeros_Q115_k   = idx_zeros_Q115_k;
resultado_C.soma_orig          = soma_orig;
resultado_C.soma_Q17           = soma_Q17;
resultado_C.soma_Q115          = soma_Q115;
resultado_C.soma_abs_orig      = soma_abs_orig;
resultado_C.soma_abs_Q17       = soma_abs_Q17;
resultado_C.soma_abs_Q115      = soma_abs_Q115;
resultado_C.erro_sim_orig      = erro_sim_orig;
resultado_C.erro_sim_Q17       = erro_sim_Q17;
resultado_C.erro_sim_Q115      = erro_sim_Q115;
resultado_C.aval_orig          = aval_orig;
resultado_C.aval_Q115          = aval_Q115;
resultado_C.aval_Q17           = aval_Q17;
resultado_C.tab_C1             = tab_C1;
resultado_C.tab_C2             = tab_C2;
end
