function resultado_B = etapa_B_validacao()
% ETAPA_B_VALIDACAO Validacao temporal e espectral da implementacao com buffer circular.
%
%   Proposito:
%       Implementar integralmente os procedimentos de validacao da Etapa B da
%       Pratica 3:
%       1. Carregar os coeficientes projetados na Etapa A (data/coeficientes_FIR.mat)
%          e as especificacoes da mascara via config_specs().
%       2. Teste 1 (Impulso unitario): excitar fir_circular(delta, h) com
%          delta = [1, zeros(1, N + 20)], comparar com filter(h, 1, delta) e
%          com o proprio vetor h[k] nos primeiros N pontos, registrando os
%          erros absolutos maximos.
%       3. Teste 2 (Duas senoides): excitar fir_circular(x, h) com
%          x[n] = sin(2*pi*500*n/Fs) + sin(2*pi*3000*n/Fs), comparar com
%          filter(h, 1, x) e registrar o erro absoluto maximo.
%       4. Verificacao em frequencia via freqz: calcular os ganhos exatos em
%          500 Hz e 3.000 Hz (escala linear e dB) e confrontar com os limites
%          da mascara de especificacoes (avaliar_mascara.m).
%       5. Exportar a tabela consolidada results/tab_B1_erros_e_ganhos.csv
%          (o diagrama TikZ do buffer circular fica embutido em report/main.tex).
%       6. Gerar e exportar via salvar_figura as figuras
%          fig_B1_impulso_comparacao e fig_B2_senoides_temporal (.pdf e .png).
%
%   Saidas:
%       resultado_B - Estrutura com os vetores, ganhos e erros maximos da Etapa B
%
%   Autor/Disciplina:
%       Processamento Digital de Sinais (SENAI CIMATEC) - Pratica 3 (2026)

%% 1. Configuracao de Caminhos e Carregamento dos Coeficientes da Etapa A
dir_script = fileparts(mfilename('fullpath'));
addpath(dir_script);
if isfolder(fullfile(dir_script, 'utils'))
    addpath(fullfile(dir_script, 'utils'));
end

specs = config_specs();

Fs           = specs.Fs;           % Frequencia de amostragem [Hz]
Fpass        = specs.Fpass;        % Limite superior da banda passante [Hz]
Fstop        = specs.Fstop;        % Limite inferior da banda de rejeicao [Hz]
tol_pass_dB  = specs.tol_pass_dB;  % Desvio maximo permitido na banda passante [dB]
aten_stop_dB = specs.aten_stop_dB; % Atenuacao minima exigida na banda de rejeicao [dB]

caminho_mat = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
if ~isfile(caminho_mat)
    error('EtapaB:CoeficientesNaoEncontrados', ...
        'Arquivo %s nao encontrado. Execute etapa_A_janelamento.m antes da Etapa B.', caminho_mat);
end

dados_A = load(caminho_mat);
h       = dados_A.h(:).';          % Vetor linha de coeficientes do filtro FIR [adimensional]
N       = numel(h);                % Numero de coeficientes (tamanho do buffer circular) [coeficientes]
ordem   = N - 1;                   % Ordem do filtro FIR M = N - 1 [adimensional]
atraso_grupo_amostras = (N - 1)/2; % Atraso de grupo constante do filtro de fase linear [amostras]

% Avaliacao completa da mascara usando o helper padronizado
aval_mascara = avaliar_mascara(h, specs);

fprintf('======================================================================\n');
fprintf('ETAPA B - IMPLEMENTACAO COM BUFFER CIRCULAR E VALIDACAO\n');
fprintf('======================================================================\n');
fprintf('Filtro carregado: N = %d coeficientes (Ordem M = %d, Atraso = %.1f amostras)\n\n', ...
    N, ordem, atraso_grupo_amostras);

%% 2. Teste 1: Resposta ao Impulso Unitario
num_zeros_extras = 20;                        % Amostras nulas adicionais apos o comprimento N [amostras]
L_imp            = N + num_zeros_extras;      % Comprimento total do sinal de teste impulsivo [amostras]
n_imp            = 0:(L_imp - 1);             % Vetor de indices temporais discretos do impulso [amostras]
delta            = [1, zeros(1, L_imp - 1)];  % Sinal impulso unitario discreto delta[n] [amplitude]

y_circ_imp = fir_circular(delta, h);          % Saida obtida com buffer circular [amplitude]
y_filt_imp = filter(h, 1, delta);             % Saida de referencia obtida com filter() [amplitude]
y_conv_imp = conv(delta, h);                  % Convolucao completa com cauda adicional de M amostras [amplitude]

erro_imp_filter_vet = abs(y_circ_imp - y_filt_imp);        % Erro ponto a ponto frente a filter() [amplitude]
erro_imp_conv_max   = max(abs(y_circ_imp - y_conv_imp(1:L_imp))); % Erro frente aos L_imp primeiros pontos de conv() [amplitude]
erro_imp_h_vet      = abs(y_circ_imp(1:N) - h);            % Erro nos primeiros N pontos frente a h[k] [amplitude]
num_retornos_imp    = floor((L_imp - 1) / N) + 1;          % Quantidade de retornos circulares (1 -> N) de idx_recente [contagem]

erro_max_imp_filter = max(erro_imp_filter_vet);            % Erro absoluto maximo (fir_circular vs filter) [amplitude]
erro_max_imp_h      = max(erro_imp_h_vet);                 % Erro absoluto maximo nos N primeiros pontos vs h[k] [amplitude]
erro_max_imp_cauda  = max(abs(y_circ_imp((N + 1):end)));   % Amplitude residual maxima para n >= N [amplitude]

fprintf('--- TESTE 1: RESPOSTA AO IMPULSO UNITARIO (L = %d amostras) ---\n', L_imp);
fprintf('  Erro abs. maximo |fir_circular(delta,h) - filter(h,1,delta)| : %.6e\n', erro_max_imp_filter);
fprintf('  Erro abs. maximo |fir_circular(1:L) - conv(delta,h)(1:L)|    : %.6e (conv total = %d amostras)\n', ...
    erro_imp_conv_max, numel(y_conv_imp));
fprintf('  Erro abs. maximo |fir_circular(1:N) - h(1:N)|                : %.6e\n', erro_max_imp_h);
fprintf('  Amplitude maxima na cauda nula (n >= N)                      : %.6e\n', erro_max_imp_cauda);
fprintf('  Retornos circulares (wrap-around 1 -> N) de idx_recente      : %d vezes (L > N)\n\n', num_retornos_imp);

%% 3. Teste 2: Sinal Composto por Duas Senoides (500 Hz e 3.000 Hz)
f1_Hz  = 500;                                 % Frequencia da senoide na banda passante [Hz]
f2_Hz  = 3000;                                % Frequencia da senoide na banda de rejeicao [Hz]
L_sen  = 400;                                 % Numero total de amostras do sinal senoidal (50 ms) [amostras]
n_sen  = 0:(L_sen - 1);                       % Vetor de indices de tempo discreto [amostras]
t_ms   = (n_sen / Fs) * 1000;                 % Vetor de tempo correspondente [ms]

x_500  = sin(2 * pi * f1_Hz * n_sen / Fs);    % Componente senoidal de 500 Hz (passante) [amplitude]
x_3000 = sin(2 * pi * f2_Hz * n_sen / Fs);    % Componente senoidal de 3000 Hz (rejeicao) [amplitude]
x_sen  = x_500 + x_3000;                      % Sinal de entrada composto x[n] [amplitude]

y_circ_sen = fir_circular(x_sen, h);          % Saida filtrada via buffer circular [amplitude]
y_filt_sen = filter(h, 1, x_sen);             % Saida de referencia via filter() [amplitude]
y_conv_sen = conv(x_sen, h);                  % Convolucao completa incluindo cauda de M amostras [amplitude]

erro_sen_filter_vet = abs(y_circ_sen - y_filt_sen); % Erro absoluto ponto a ponto [amplitude]
erro_max_sen_filter = max(erro_sen_filter_vet);     % Erro absoluto maximo nas duas senoides [amplitude]
erro_max_sen_conv   = max(abs(y_circ_sen - y_conv_sen(1:L_sen))); % Erro frente a conv(x,h)(1:L_sen) [amplitude]
num_retornos_sen    = floor((L_sen - 1) / N) + 1;   % Quantidade de retornos circulares de idx_recente [contagem]

fprintf('--- TESTE 2: SINAL DE DUAS SENOIDES (%d Hz + %d Hz, L = %d amostras) ---\n', ...
    f1_Hz, f2_Hz, L_sen);
fprintf('  Erro abs. maximo |fir_circular(x,h) - filter(h,1,x)|         : %.6e\n', erro_max_sen_filter);
fprintf('  Erro abs. maximo |fir_circular(1:L) - conv(x,h)(1:L)|        : %.6e (conv total = %d amostras)\n', ...
    erro_max_sen_conv, numel(y_conv_sen));
fprintf('  Retornos circulares (wrap-around 1 -> N) de idx_recente      : %d vezes (L > N)\n\n', num_retornos_sen);

%% 4. Ganhos Exatos em 500 Hz e 3.000 Hz via freqz e Comparacao com a Mascara
freqs_teste_Hz = [f1_Hz, f2_Hz];              % Frequencias avaliadas pontualmente via freqz [Hz]
H_freqz        = freqz(h, 1, freqs_teste_Hz, Fs); % Resposta em frequencia complexa [adimensional]

ganho_500_linear  = abs(H_freqz(1));                       % Ganho linear em 500 Hz |H(500)| [adimensional]
ganho_500_dB      = 20 * log10(max(ganho_500_linear, eps));% Ganho em 500 Hz [dB]
desvio_500_dB     = abs(ganho_500_dB);                     % Desvio absoluto em relacao a 0 dB em 500 Hz [dB]
fase_500_graus    = rad2deg(angle(H_freqz(1)));            % Fase da resposta em 500 Hz [graus]
atende_500_Hz     = (desvio_500_dB <= tol_pass_dB + 1e-12);% Conformidade com +-0,1 dB em 500 Hz [logico]

ganho_3000_linear = abs(H_freqz(2));                        % Ganho linear em 3000 Hz |H(3000)| [adimensional]
ganho_3000_dB     = 20 * log10(max(ganho_3000_linear, eps));% Ganho em 3000 Hz [dB]
atenuacao_3000_dB = -ganho_3000_dB;                         % Atenuacao efetiva em 3000 Hz (-|H|_dB) [dB]
fase_3000_graus   = rad2deg(angle(H_freqz(2)));             % Fase da resposta em 3000 Hz [graus]
atende_3000_Hz    = (atenuacao_3000_dB >= aten_stop_dB - 1e-12); % Conformidade com >= 45 dB em 3000 Hz [logico]

% Sinal ideal de 500 Hz atrasado de tau_g amostras e escalado pelo ganho exato em 500 Hz
x_500_atrasado = ganho_500_linear * sin(2 * pi * f1_Hz * (n_sen - atraso_grupo_amostras) / Fs); % Referencia teorica em regime permanente [amplitude]
erro_regime_500 = max(abs(y_circ_sen(N:end) - x_500_atrasado(N:end))); % Amplitude residual maxima de 3000 Hz no regime permanente [amplitude]

fprintf('--- VERIFICACAO EM FREQUENCIA VIA FREQZ ---\n');
fprintf('  f =  500 Hz (Passante) : |H| = %.8f | Ganho = %+10.6f dB | Exigencia: |Ganho| <= %.2f dB | Atende: %d\n', ...
    ganho_500_linear, ganho_500_dB, tol_pass_dB, atende_500_Hz);
fprintf('  f = 3000 Hz (Rejeicao) : |H| = %.8f | Ganho = %+10.4f dB (Aten. = %.4f dB) | Exigencia: <= -%.1f dB | Atende: %d\n', ...
    ganho_3000_linear, ganho_3000_dB, atenuacao_3000_dB, aten_stop_dB, atende_3000_Hz);
fprintf('  Diferenca maxima em regime permanente |y[n] - |H(500)|*sin(500 Hz atrasada)| : %.6e (~= |H(3000)|)\n\n', ...
    erro_regime_500);

%% 5. Exportacao da Tabela results/tab_B1_erros_e_ganhos.csv
Metrica = [
    "Comprimento do buffer circular (N)";
    "Amostras testadas no impulso unitario (L_imp)";
    "Erro abs maximo Impulso (fir_circular vs filter)";
    "Erro abs maximo Impulso (fir_circular(1:N) vs h)";
    "Erro abs maximo Impulso na cauda nula (n >= N)";
    "Amostras testadas no sinal de duas senoides (L_sen)";
    "Erro abs maximo Duas Senoides (fir_circular vs filter)";
    "Ganho linear em 500 Hz via freqz |H(500 Hz)|";
    "Ganho em 500 Hz via freqz";
    "Desvio absoluto em 500 Hz frente a 0 dB";
    "Limite maximo de desvio na banda passante (0 a 1000 Hz)";
    "Atende mascara em 500 Hz?";
    "Ganho linear em 3000 Hz via freqz |H(3000 Hz)|";
    "Ganho em 3000 Hz via freqz";
    "Atenuacao em 3000 Hz via freqz (-20*log10|H(3000 Hz)|)";
    "Atenuacao minima exigida na banda de rejeicao (2200 a 4000 Hz)";
    "Atende mascara em 3000 Hz?";
    "Desvio maximo global na banda passante (avaliar_mascara)";
    "Atenuacao minima global na banda de rejeicao (avaliar_mascara)";
    "Atende mascara globalmente (avaliar_mascara)?"
    ];

Valor = [
    N;
    L_imp;
    erro_max_imp_filter;
    erro_max_imp_h;
    erro_max_imp_cauda;
    L_sen;
    erro_max_sen_filter;
    ganho_500_linear;
    ganho_500_dB;
    desvio_500_dB;
    tol_pass_dB;
    double(atende_500_Hz);
    ganho_3000_linear;
    ganho_3000_dB;
    atenuacao_3000_dB;
    aten_stop_dB;
    double(atende_3000_Hz);
    aval_mascara.desvio_pass_max_dB;
    aval_mascara.aten_stop_min_dB;
    double(aval_mascara.atende_mascara)
    ];

Unidade = [
    "coeficientes";
    "amostras";
    "amplitude";
    "amplitude";
    "amplitude";
    "amostras";
    "amplitude";
    "adimensional";
    "dB";
    "dB";
    "dB";
    "logico (1=Sim, 0=Nao)";
    "adimensional";
    "dB";
    "dB";
    "dB";
    "logico (1=Sim, 0=Nao)";
    "dB";
    "dB";
    "logico (1=Sim, 0=Nao)"
    ];

tab_B1 = table(Metrica, Valor, Unidade);
caminho_tab_B1 = fullfile(specs.caminhos.results, 'tab_B1_erros_e_ganhos.csv');
writetable(tab_B1, caminho_tab_B1);

%% 6. Geracao das Figuras da Etapa B

% --- Figura B1: Resposta ao Impulso de fir_circular vs h[k] e filter() ---
fig_B1 = figure('Name', 'Etapa B - Validacao da Resposta ao Impulso (Buffer Circular)', ...
    'Position', [100, 100, 880, 640], 'Visible', 'off');
tiledlayout(fig_B1, 2, 1, 'TileSpacing', 'normal', 'Padding', 'normal');

% Painel 1: Sobreposicao da resposta ao impulso y_circ_imp[n], filter(h,1,delta) e h[k]
nexttile;
stem(n_imp, y_circ_imp, 'filled', 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.3, 'MarkerSize', 5);
hold on;
plot(n_imp, y_filt_imp, 'o', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'MarkerSize', 8);
plot(0:(N - 1), h, 's', 'Color', [0.13, 0.55, 0.13], 'LineWidth', 1.1, 'MarkerSize', 10);
xline(N - 0.5, '--', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.0);
hold off;
title(sprintf('Resposta ao Impulso: fir\\_circular(\\delta, h) vs filter(h, 1, \\delta) e h[k] (N = %d)', N));
xlabel('Amostra [n]');
ylabel('Amplitude');
xlim([-0.8, L_imp - 0.5]);
ylim([-0.10, 0.46]);
legend({'fir\_circular(\delta, h)', 'filter(h, 1, \delta)', 'Coeficientes h[k] (k = 0..N-1)', ...
    sprintf('Fim da memória (n = %d)', N - 1)}, 'Location', 'northeast');

% Painel 2: Erro absoluto ponto a ponto |y_circ[n] - y_filter[n]| e |y_circ[k] - h[k]|
nexttile;
stem(n_imp, erro_imp_filter_vet, 'filled', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.2, 'MarkerSize', 5);
hold on;
plot(0:(N - 1), erro_imp_h_vet, 's', 'Color', [0.13, 0.55, 0.13], 'LineWidth', 1.2, 'MarkerSize', 7);
xline(N - 0.5, '--', 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1.0);
hold off;
title(sprintf('Erro Absoluto no Impulso (Máx vs filter = %.1e | Máx vs h[k] = %.1e)', ...
    erro_max_imp_filter, erro_max_imp_h));
xlabel('Amostra [n]');
ylabel('Erro Absoluto [amplitude]');
xlim([-0.8, L_imp - 0.5]);
ylim([-0.2, 1.0]);
legend({'|y_{circ}[n] - y_{filter}[n]|', '|y_{circ}[k] - h[k]|', ...
    sprintf('Limite n = %d', N - 1)}, 'Location', 'northeast');

salvar_figura(fig_B1, 'fig_B1_impulso_comparacao', specs);
close(fig_B1);

% --- Figura B2: Filtragem Temporal do Sinal de Duas Senoides (500 Hz + 3000 Hz) ---
fig_B2 = figure('Name', 'Etapa B - Filtragem Temporal de Duas Senoides (500 Hz e 3000 Hz)', ...
    'Position', [120, 120, 900, 780], 'Visible', 'off');
tiledlayout(fig_B2, 3, 1, 'TileSpacing', 'normal', 'Padding', 'normal');

% Janela de visualizacao detalhada (primeiras 120 amostras = 15 ms, cobrindo 7,5 ciclos de 500 Hz)
N_plot_detalhe = 120;                         % Quantidade de amostras exibidas nos paineis temporais [amostras]
idx_det        = 1:N_plot_detalhe;            % Indices para plotagem detalhada [indices]

% Painel 1: Sinal de entrada composto x[n] vs saida filtrada y[n]
nexttile;
plot(n_sen(idx_det), x_sen(idx_det), 'Color', [0.65, 0.65, 0.65], 'LineWidth', 1.1);
hold on;
plot(n_sen(idx_det), y_circ_sen(idx_det), 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.6);
xline(N - 1, '--r', 'LineWidth', 1.2);
hold off;
title(sprintf('Entrada Composta x[n] (500 Hz + 3000 Hz) e Saída Filtrada y[n] (F_s = %d Hz)', Fs));
xlabel('Amostra [n]');
ylabel('Amplitude');
xlim([0, N_plot_detalhe - 1]);
ylim([-2.4, 2.4]);
legend({'Entrada x[n] (500 Hz + 3000 Hz)', 'Saída y_{circ}[n] = fir\_circular(x, h)', ...
    sprintf('Fim do transitório (n = %d)', N - 1)}, 'Location', 'northeast');

% Painel 2: Sobreposicao de fir_circular, filter() e senoide ideal de 500 Hz deslocada do atraso de grupo
nexttile;
plot(n_sen(idx_det), y_circ_sen(idx_det), '-', 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.6);
hold on;
plot(n_sen(idx_det), y_filt_sen(idx_det), '--', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.4);
plot(n_sen(idx_det), x_500_atrasado(idx_det), ':', 'Color', [0.13, 0.55, 0.13], 'LineWidth', 1.5);
xline(N - 1, '--r', 'LineWidth', 1.1, 'HandleVisibility', 'off');
hold off;
title(sprintf('Saída fir\\_circular vs filter() e Referência de 500 Hz (\\tau_g = %.0f amostras, |H(500)| = %.4f dB)', ...
    atraso_grupo_amostras, ganho_500_dB));
xlabel('Amostra [n]');
ylabel('Amplitude');
xlim([0, N_plot_detalhe - 1]);
ylim([-1.45, 1.45]);
legend({'fir\_circular(x, h)', 'filter(h, 1, x)', ...
    sprintf('|H(500)|\\cdot sen(2\\pi\\cdot500(n - %d)/F_s)', atraso_grupo_amostras)}, ...
    'Location', 'northeast');

% Painel 3: Erro absoluto ponto a ponto |y_circ[n] - y_filter[n]| ao longo de todas as L_sen amostras
nexttile;
plot(n_sen, erro_sen_filter_vet, 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.1);
title(sprintf('Erro Absoluto |fir\\_circular(x, h) - filter(h, 1, x)| (Erro Máx = %.3e)', ...
    erro_max_sen_filter));
xlabel('Amostra [n]');
ylabel('Erro Absoluto [amplitude]');
xlim([0, L_sen - 1]);
ylim([0, max(erro_max_sen_filter, 1e-15) * 1.35]);
legend({'|y_{circ}[n] - y_{filter}[n]|'}, 'Location', 'northeast');

salvar_figura(fig_B2, 'fig_B2_senoides_temporal', specs);
close(fig_B2);

fprintf('Arquivos gerados com sucesso:\n');
fprintf('  - %s\n', caminho_tab_B1);
fprintf('  - %s (.pdf e .png)\n', fullfile(specs.caminhos.figures, 'fig_B1_impulso_comparacao'));
fprintf('  - %s (.pdf e .png)\n\n', fullfile(specs.caminhos.figures, 'fig_B2_senoides_temporal'));

%% 7. Estrutura de Retorno
resultado_B.N                   = N;
resultado_B.ordem               = ordem;
resultado_B.h                   = h;
resultado_B.delta               = delta;
resultado_B.y_circ_imp          = y_circ_imp;
resultado_B.y_filt_imp          = y_filt_imp;
resultado_B.erro_max_imp_filter = erro_max_imp_filter;
resultado_B.erro_max_imp_h      = erro_max_imp_h;
resultado_B.erro_max_imp_cauda  = erro_max_imp_cauda;
resultado_B.x_sen               = x_sen;
resultado_B.y_circ_sen          = y_circ_sen;
resultado_B.y_filt_sen          = y_filt_sen;
resultado_B.erro_max_sen_filter = erro_max_sen_filter;
resultado_B.ganho_500_linear    = ganho_500_linear;
resultado_B.ganho_500_dB        = ganho_500_dB;
resultado_B.desvio_500_dB       = desvio_500_dB;
resultado_B.fase_500_graus      = fase_500_graus;
resultado_B.atende_500_Hz       = atende_500_Hz;
resultado_B.ganho_3000_linear   = ganho_3000_linear;
resultado_B.ganho_3000_dB       = ganho_3000_dB;
resultado_B.atenuacao_3000_dB   = atenuacao_3000_dB;
resultado_B.fase_3000_graus     = fase_3000_graus;
resultado_B.atende_3000_Hz      = atende_3000_Hz;
resultado_B.t_ms                = t_ms;
resultado_B.tab_B1              = tab_B1;
end
