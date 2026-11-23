function resultado_A = etapa_A_janelamento()
% ETAPA_A_JANELAMENTO Projeto do filtro FIR passa-baixa por serie de Fourier e janela de Hamming.
%
%   Proposito:
%       Implementar integralmente a Etapa A da Pratica 3:
%       1. Calcular a largura da banda de transicao (delta_f e delta_omega) e
%          estimar o comprimento inicial N para a janela de Hamming.
%       2. Realizar varredura de comprimentos pares e impares ao redor da
%          estimativa inicial (N = 15 a 45), sintetizando a resposta impulsiva
%          ideal centrada em (N-1)/2 (tratando explicitamente n == (N-1)/2),
%          aplicando janela de Hamming e normalizando por h = h / sum(h).
%       3. Avaliar cada comprimento frente a mascara com grade densa e
%          registrar todos os comprimentos testados em tab_A1_varredura_N.csv.
%       4. Selecionar o menor N que satisfaz simultaneamente ambas as
%          exigencias da mascara, calcular soma dos coeficientes, erro maximo
%          de simetria e atraso de grupo (amostras e ms), salvando
%          tab_A2_metricas_finais.csv e data/coeficientes_FIR.mat.
%       5. Gerar e exportar as figuras fig_A1_impulso_janela e
%          fig_A2_magnitude_mascara (.pdf e .png).
%
%   Saidas:
%       resultado_A - Estrutura com os vetores e metricas finais da Etapa A

%% 1. Carregamento das Especificacoes e Configuracao de Caminhos
dir_script = fileparts(mfilename('fullpath'));
addpath(dir_script);
if isfolder(fullfile(dir_script, 'utils'))
    addpath(fullfile(dir_script, 'utils'));
end

specs = config_specs();

Fs           = specs.Fs;           % Frequencia de amostragem [Hz]
Fpass        = specs.Fpass;        % Frequencia limite da banda passante [Hz]
Fstop        = specs.Fstop;        % Frequencia inicial da banda de rejeicao [Hz]
fc           = specs.fc;           % Frequencia de corte ideal inicial [Hz]
tol_pass_dB  = specs.tol_pass_dB;  % Desvio maximo permitido na banda passante [dB]
aten_stop_dB = specs.aten_stop_dB; % Atenuacao minima exigida na banda de rejeicao [dB]

fprintf('======================================================================\n');
fprintf('ETAPA A - PROJETO DE FILTRO FIR PASSA-BAIXA POR JANELAMENTO (HAMMING)\n');
fprintf('======================================================================\n');

%% 2. Calculo da Largura de Transicao e Estimativa Inicial de Comprimento
delta_f_Hz        = Fstop - Fpass;                % Largura da banda de transicao [Hz]
delta_f_norm      = delta_f_Hz / Fs;              % Largura de transicao normalizada [ciclos/amostra]
delta_omega_rad   = 2 * pi * delta_f_Hz / Fs;     % Largura de transicao angular [rad/amostra]
delta_omega_pi    = delta_omega_rad / pi;         % Largura de transicao em multiplos de pi [rad/amostra / pi]
omega_c_rad       = 2 * pi * fc / Fs;             % Frequencia de corte ideal angular [rad/amostra]

% Estimativa inicial para janela de Hamming:
% Referencia classica (Proakis/Oppenheim): delta_omega ~= 6.6*pi / N  =>  N ~= 3.3 / (delta_f / Fs)
% Observacao para conferencia com os slides de aula: caso a formula adotada nos
% slides utilize fator 4 (delta_omega ~= 8*pi / M ou 8*pi / N), a estimativa
% alternativa resulta em N_est_fator4 = ceil(4.0 / (delta_f / Fs)) = 27.
fator_hamming_ref = 3.3;                                  % Fator empirico de transicao da janela de Hamming [adimensional]
N_est_exato       = fator_hamming_ref / delta_f_norm;     % Estimativa continua do comprimento [coeficientes]
N_est             = ceil(N_est_exato);                    % Estimativa inteira inicial (fator 3.3) [coeficientes]
N_est_fator4      = ceil(4.0 / delta_f_norm);             % Estimativa alternativa (fator 4.0 dos slides) [coeficientes]

fprintf('Largura de transicao: delta_f = %.1f Hz | delta_omega = %.4f*pi rad/amostra (%.6f rad/amostra)\n', ...
    delta_f_Hz, delta_omega_pi, delta_omega_rad);
fprintf('Estimativa inicial (fator 3,3): N_est = ceil(3,3 / %.4f) = %d coeficientes (ordem %d)\n', ...
    delta_f_norm, N_est, N_est - 1);
fprintf('Estimativa alternativa (fator 4,0): N_est_alt = ceil(4,0 / %.4f) = %d coeficientes (ordem %d)\n\n', ...
    delta_f_norm, N_est_fator4, N_est_fator4 - 1);

%% 3. Varredura de Comprimentos Pares e Impares ao Redor da Estimativa
vetor_N = 15:45;                   % Faixa de comprimentos pares e impares testados [coeficientes]
num_testes = numel(vetor_N);       % Quantidade total de comprimentos avaliados [testes]

col_N                 = zeros(num_testes, 1);   % Comprimento N (numero de coeficientes) [coeficientes]
col_Ordem             = zeros(num_testes, 1);   % Ordem do filtro M = N - 1 [adimensional]
col_Paridade          = strings(num_testes, 1); % Paridade do comprimento ('Impar' ou 'Par')
col_Desvio_Pass_dB    = zeros(num_testes, 1);   % Desvio maximo na banda passante [dB]
col_Aten_Stop_dB      = zeros(num_testes, 1);   % Atenuacao minima na banda de rejeicao [dB]
col_Ganho_DC_dB       = zeros(num_testes, 1);   % Ganho em corrente continua (f = 0 Hz) [dB]
col_Atende_Pass       = false(num_testes, 1);   % Atendimento ao limite da banda passante [logico]
col_Atende_Stop       = false(num_testes, 1);   % Atendimento ao limite da banda de rejeicao [logico]
col_Atende_Mascara    = false(num_testes, 1);   % Atendimento simultaneo a mascara completa [logico]

N_selecionado = NaN; % Menor comprimento N que satisfaz simultaneamente a mascara [coeficientes]

fprintf('%-4s | %-5s | %-6s | %-18s | %-18s | %-11s | %-11s | %-14s\n', ...
    'N', 'Ordem', 'Tipo', 'Desvio Pass [dB]', 'Aten Stop [dB]', 'Atende Pass', 'Atende Stop', 'Atende Mascara');
fprintf('%s\n', repmat('-', 1, 102));

for idx = 1:num_testes
    N_teste = vetor_N(idx); % Comprimento sob teste [coeficientes]
    [h_teste, ~, ~] = sintetizar_fir_hamming(N_teste, omega_c_rad);
    aval = avaliar_mascara(h_teste, specs);

    col_N(idx)              = N_teste;
    col_Ordem(idx)          = N_teste - 1;
    if mod(N_teste, 2) == 0
        col_Paridade(idx)   = "Par";
    else
        col_Paridade(idx)   = "Impar";
    end
    col_Desvio_Pass_dB(idx) = aval.desvio_pass_max_dB;
    col_Aten_Stop_dB(idx)   = aval.aten_stop_min_dB;
    col_Ganho_DC_dB(idx)    = aval.ganho_dc_dB;
    col_Atende_Pass(idx)    = aval.atende_pass;
    col_Atende_Stop(idx)    = aval.atende_stop;
    col_Atende_Mascara(idx) = aval.atende_mascara;

    if aval.atende_mascara && isnan(N_selecionado)
        N_selecionado = N_teste;
    end

    fprintf('%-4d | %-5d | %-6s | %18.6f | %18.4f | %-11d | %-11d | %-14d\n', ...
        N_teste, N_teste - 1, col_Paridade(idx), ...
        aval.desvio_pass_max_dB, aval.aten_stop_min_dB, ...
        aval.atende_pass, aval.atende_stop, aval.atende_mascara);
end

if isnan(N_selecionado)
    error('EtapaA:NenhumFiltroValido', ...
        'Nenhum comprimento na faixa testada atendeu simultaneamente a mascara.');
end

% Salva tabela de varredura completa (incluindo os comprimentos que falharam)
tab_A1 = table(col_N, col_Ordem, col_Paridade, ...
    col_Desvio_Pass_dB, col_Aten_Stop_dB, col_Ganho_DC_dB, ...
    col_Atende_Pass, col_Atende_Stop, col_Atende_Mascara, ...
    'VariableNames', {'N', 'Ordem', 'Paridade', ...
    'Desvio_Pass_Max_dB', 'Aten_Stop_Min_dB', 'Ganho_DC_dB', ...
    'Atende_Pass', 'Atende_Stop', 'Atende_Mascara'});

caminho_tab_A1 = fullfile(specs.caminhos.results, 'tab_A1_varredura_N.csv');
writetable(tab_A1, caminho_tab_A1);

%% 4. Sintese e Metricas Finais para o Menor N Selecionado
N     = N_selecionado; % Numero de coeficientes selecionado [coeficientes]
ordem = N - 1;         % Ordem do filtro selecionado [adimensional]

[h, h_ideal, w] = sintetizar_fir_hamming(N, omega_c_rad);
aval_final      = avaliar_mascara(h, specs);

soma_coef             = sum(h);                         % Soma dos coeficientes normalizados [adimensional]
erro_simetria_max     = max(abs(h - fliplr(h)));        % Erro maximo de simetria par h[k] - h[N-1-k] [adimensional]
atraso_grupo_amostras = (N - 1) / 2;                    % Atraso de grupo constante [amostras]
atraso_grupo_ms       = (atraso_grupo_amostras / Fs) * 1000; % Atraso de grupo constante [ms]
desvio_pass_max_dB    = aval_final.desvio_pass_max_dB;  % Desvio maximo na banda passante [dB]
aten_stop_min_dB      = aval_final.aten_stop_min_dB;    % Atenuacao minima na banda de rejeicao [dB]
ganho_dc_dB           = aval_final.ganho_dc_dB;         % Ganho em corrente continua [dB]
atende_mascara        = aval_final.atende_mascara;      % Status final de atendimento [logico]

fprintf('\n----------------------------------------------------------------------\n');
fprintf('RESULTADO FINAL SELECIONADO (ETAPA A):\n');
fprintf('  Menor comprimento que atende a mascara : N = %d coeficientes\n', N);
fprintf('  Ordem do filtro                        : M = N - 1 = %d\n', ordem);
fprintf('  Desvio maximo na banda passante        : %.6f dB (limite <= %.2f dB)\n', desvio_pass_max_dB, tol_pass_dB);
fprintf('  Atenuacao minima na banda de rejeicao  : %.4f dB (limite >= %.2f dB)\n', aten_stop_min_dB, aten_stop_dB);
fprintf('  Soma dos coeficientes sum(h)           : %.16f (Ganho DC = %.4e dB)\n', soma_coef, ganho_dc_dB);
fprintf('  Erro maximo de simetria                : %.4e\n', erro_simetria_max);
fprintf('  Atraso de grupo                        : %.1f amostras (%.4f ms)\n', atraso_grupo_amostras, atraso_grupo_ms);
fprintf('----------------------------------------------------------------------\n');

% Exporta tabela de metricas finais da Etapa A
Parametro = [
    "Frequencia de amostragem (Fs)";
    "Banda passante (Fpass)";
    "Banda de rejeicao (Fstop)";
    "Frequencia de corte ideal (fc)";
    "Largura da banda de transicao (delta_f)";
    "Largura de transicao angular (delta_omega / pi)";
    "Estimativa inicial de comprimento (fator 3.3)";
    "Estimativa alternativa de comprimento (fator 4.0)";
    "Comprimento selecionado (N)";
    "Ordem do filtro selecionado (M = N - 1)";
    "Desvio maximo na banda passante";
    "Atenuacao minima na banda de rejeicao";
    "Soma dos coeficientes sum(h)";
    "Ganho DC";
    "Erro maximo de simetria max|h[k] - h[N-1-k]|";
    "Atraso de grupo (amostras)";
    "Atraso de grupo (tempo)"
    ];
Valor = [
    Fs;
    Fpass;
    Fstop;
    fc;
    delta_f_Hz;
    delta_omega_pi;
    N_est;
    N_est_fator4;
    N;
    ordem;
    desvio_pass_max_dB;
    aten_stop_min_dB;
    soma_coef;
    ganho_dc_dB;
    erro_simetria_max;
    atraso_grupo_amostras;
    atraso_grupo_ms
    ];
Unidade = [
    "Hz";
    "Hz";
    "Hz";
    "Hz";
    "Hz";
    "pi rad/amostra";
    "coeficientes";
    "coeficientes";
    "coeficientes";
    "adimensional";
    "dB";
    "dB";
    "adimensional";
    "dB";
    "adimensional";
    "amostras";
    "ms"
    ];

tab_A2 = table(Parametro, Valor, Unidade);
caminho_tab_A2 = fullfile(specs.caminhos.results, 'tab_A2_metricas_finais.csv');
writetable(tab_A2, caminho_tab_A2);

% Salva arquivo data/coeficientes_FIR.mat exigido pelo roteiro
caminho_mat = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
save(caminho_mat, ...
    'h', 'h_ideal', 'w', 'N', 'ordem', ...
    'Fs', 'Fpass', 'Fstop', 'fc', ...
    'tol_pass_dB', 'aten_stop_dB', ...
    'delta_f_Hz', 'delta_omega_rad', 'N_est', 'N_est_fator4', ...
    'soma_coef', 'erro_simetria_max', ...
    'atraso_grupo_amostras', 'atraso_grupo_ms', ...
    'desvio_pass_max_dB', 'aten_stop_min_dB', 'ganho_dc_dB', 'atende_mascara');

%% 5. Geracao das Figuras da Etapa A
k_ind = 0:(N - 1); % Indices das amostras dos coeficientes k = 0, ..., N-1 [amostras]

% --- Figura A1: Resposta Impulsiva Ideal, Janela de Hamming e Coeficientes Finais ---
fig_A1 = figure('Name', 'Etapa A - Resposta ao Impulso e Janela de Hamming', ...
    'Position', [100, 100, 820, 680], 'Visible', 'off');
tiledlayout(fig_A1, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% Subplot 1: Resposta impulsiva ideal h_ideal[k]
nexttile;
stem(k_ind, h_ideal, 'filled', 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.2, 'MarkerSize', 5);
hold on;
xline(atraso_grupo_amostras, '--', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.0);
hold off;
title(sprintf('Resposta Impulsiva Ideal Centrada h_{ideal}[k] (f_c = %d Hz, \\alpha = %.1f amostras)', ...
    fc, atraso_grupo_amostras));
xlabel('Índice da amostra [k]');
ylabel('Amplitude');
xlim([-0.5, N - 0.5]);
legend({'h_{ideal}[k]', sprintf('Centro de simetria (\\alpha = %.1f)', atraso_grupo_amostras)}, ...
    'Location', 'northeast');

% Subplot 2: Janela de Hamming w[k]
nexttile;
stem(k_ind, w, 'filled', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'MarkerSize', 5);
hold on;
plot(k_ind, w, ':', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.0);
hold off;
title(sprintf('Janela de Hamming w[k] (Comprimento N = %d, Ordem M = %d)', N, ordem));
xlabel('Índice da amostra [k]');
ylabel('Peso w[k]');
xlim([-0.5, N - 0.5]);
ylim([0, 1.1]);
legend({'w[k] (Hamming)', 'Envoltória'}, 'Location', 'northeast');

% Subplot 3: Coeficientes finais normalizados h[k]
nexttile;
stem(k_ind, h, 'filled', 'Color', [0.13, 0.55, 0.13], 'LineWidth', 1.2, 'MarkerSize', 5);
hold on;
xline(atraso_grupo_amostras, '--', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.0);
hold off;
title(sprintf('Coeficientes Finais Normalizados h[k] (\\Sigma h[k] = %.4f, Atraso de grupo = %.3f ms)', ...
    soma_coef, atraso_grupo_ms));
xlabel('Índice do coeficiente [k]');
ylabel('Amplitude');
xlim([-0.5, N - 0.5]);
legend({'h[k] normalizado', sprintf('Eixo de simetria (\\alpha = %.1f)', atraso_grupo_amostras)}, ...
    'Location', 'northeast');

salvar_figura(fig_A1, 'fig_A1_impulso_janela', specs);
close(fig_A1);

% --- Figura A2: Resposta em Magnitude (0 a 4000 Hz) e Ampliacoes (Zoom) ---
f_Hz   = aval_final.f_Hz;   % Vetor de frequencia [Hz]
mag_dB = aval_final.mag_dB; % Magnitude [dB]

fig_A2 = figure('Name', 'Etapa A - Resposta em Magnitude e Mascara de Especificacoes', ...
    'Position', [120, 120, 920, 680], 'Visible', 'off');
tiledlayout(fig_A2, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Painel 1 (Superior, 2 colunas): Visao global de 0 a 4000 Hz
nexttile([1, 2]);
plot(f_Hz, mag_dB, 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
% Limites da mascara na banda passante (+0,1 dB e -0,1 dB de 0 a 1000 Hz)
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], '--r', 'LineWidth', 1.2);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], '--r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
% Limite da mascara na banda de rejeicao (-45 dB de 2200 a 4000 Hz)
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
% Linhas verticais de referencia das bordas das bandas e fc
xline(Fpass, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
xline(fc,    '-.', 'Color', [0.2, 0.6, 0.2], 'LineWidth', 1.0);
xline(Fstop, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
hold off;
title(sprintf('Resposta em Magnitude |H(f)| do Filtro FIR Projetado (Hamming, N = %d, Ordem = %d)', N, ordem));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, Fs/2]);
ylim([-100, 5]);
legend({'|H(f)| projetado', ...
    sprintf('Limite passante (\\pm%.1f dB até %d Hz)', tol_pass_dB, Fpass), ...
    sprintf('Limite rejeição (-%d dB a partir de %d Hz)', round(aten_stop_dB), Fstop), ...
    sprintf('Corte ideal f_c = %d Hz', fc)}, ...
    'Location', 'southwest');

% Painel 2 (Inferior esquerdo): Ampliacao (Zoom) na Banda Passante (0 a 1000 Hz)
nexttile;
idx_zoom_pass = (f_Hz >= 0) & (f_Hz <= 1150);
plot(f_Hz(idx_zoom_pass), mag_dB(idx_zoom_pass), 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], '--r', 'LineWidth', 1.2);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], '--r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(Fpass, ':k', 'LineWidth', 1.0);
yline(0, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.8, 'HandleVisibility', 'off');
hold off;
title(sprintf('Ampliação da Banda Passante (Desvio máx = %.4f dB)', desvio_pass_max_dB));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, 1100]);
ylim([-0.15, 0.15]);
legend({'|H(f)|', sprintf('Máscara \\pm%.1f dB', tol_pass_dB), sprintf('F_{pass} = %d Hz', Fpass)}, ...
    'Location', 'southwest');

% Painel 3 (Inferior direito): Ampliacao (Zoom) na Banda de Rejeicao (2200 a 4000 Hz)
nexttile;
idx_zoom_stop = (f_Hz >= 2050) & (f_Hz <= Fs/2);
plot(f_Hz(idx_zoom_stop), mag_dB(idx_zoom_stop), 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
xline(Fstop, ':k', 'LineWidth', 1.0);
hold off;
title(sprintf('Ampliação da Banda de Rejeição (Atenuação mín = %.2f dB)', aten_stop_min_dB));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([2100, Fs/2]);
ylim([-95, -35]);
legend({'|H(f)|', sprintf('Máscara -%d dB', round(aten_stop_dB)), sprintf('F_{stop} = %d Hz', Fstop)}, ...
    'Location', 'northeast');

salvar_figura(fig_A2, 'fig_A2_magnitude_mascara', specs);
close(fig_A2);

fprintf('Arquivos gerados com sucesso:\n');
fprintf('  - %s\n', caminho_mat);
fprintf('  - %s\n', caminho_tab_A1);
fprintf('  - %s\n', caminho_tab_A2);
fprintf('  - %s (.pdf e .png)\n', fullfile(specs.caminhos.figures, 'fig_A1_impulso_janela'));
fprintf('  - %s (.pdf e .png)\n\n', fullfile(specs.caminhos.figures, 'fig_A2_magnitude_mascara'));

% Estrutura de retorno
resultado_A.N                     = N;
resultado_A.ordem                 = ordem;
resultado_A.h                     = h;
resultado_A.h_ideal               = h_ideal;
resultado_A.w                     = w;
resultado_A.soma_coef             = soma_coef;
resultado_A.erro_simetria_max     = erro_simetria_max;
resultado_A.atraso_grupo_amostras = atraso_grupo_amostras;
resultado_A.atraso_grupo_ms       = atraso_grupo_ms;
resultado_A.desvio_pass_max_dB    = desvio_pass_max_dB;
resultado_A.aten_stop_min_dB      = aten_stop_min_dB;
resultado_A.ganho_dc_dB           = ganho_dc_dB;
resultado_A.atende_mascara        = atende_mascara;
resultado_A.tab_A1                = tab_A1;
resultado_A.tab_A2                = tab_A2;
end

%% Funcao Local de Sintese por Serie de Fourier e Janela de Hamming
function [h, h_ideal, w] = sintetizar_fir_hamming(N, omega_c_rad)
% SINTETIZAR_FIR_HAMMING Sintetiza um filtro FIR passa-baixa causal com janela de Hamming.
%
%   Entradas:
%       N           - Comprimento do filtro (numero de coeficientes, par ou impar) [coeficientes]
%       omega_c_rad - Frequencia angular de corte ideal [rad/amostra]
%
%   Saidas:
%       h       - Vetor linha de coeficientes finais normalizados para ganho DC unitario [adimensional]
%       h_ideal - Vetor linha da resposta impulsiva ideal truncada e deslocada [adimensional]
%       w       - Vetor linha da janela de Hamming de comprimento N [adimensional]

n     = 0:(N - 1);       % Vetor de indices temporais discretos [amostras]
alpha = (N - 1) / 2;     % Centro de simetria / atraso de grupo [amostras]
desloc = n - alpha;      % Deslocamento em relacao ao centro de simetria [amostras]

h_ideal = zeros(1, N);   % Pre-alocacao da resposta impulsiva ideal [adimensional]

% Tratamento explicito do ponto central n == (N-1)/2 para evitar 0/0 = NaN quando N e impar
idx_centro = (abs(desloc) < 1e-12);
h_ideal(idx_centro)  = omega_c_rad / pi;
h_ideal(~idx_centro) = sin(omega_c_rad * desloc(~idx_centro)) ./ (pi * desloc(~idx_centro));

% Aplicacao da janela de Hamming (suporta N par e N impar)
w = hamming(N).';        % Vetor linha da janela de Hamming [adimensional]
h_janelado = h_ideal .* w; % Resposta impulsiva janelada nao normalizada [adimensional]

% Normalizacao para garantir ganho unitario (0 dB) em DC (f = 0 Hz)
h = h_janelado / sum(h_janelado);
end
