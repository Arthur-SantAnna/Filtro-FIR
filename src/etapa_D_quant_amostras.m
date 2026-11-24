function resultado_D = etapa_D_quant_amostras()
% ETAPA_D_QUANT_AMOSTRAS Quantizacao das amostras de entrada em Q1.7 e analise de SNR.
%
%   Proposito:
%       Implementar integralmente a Etapa D da Pratica 3:
%       1. Manter os coeficientes originais h em ponto flutuante (double),
%          isolando exclusivamente o efeito da quantizacao das amostras de
%          entrada x[n] no formato Q1.7 (8 bits com sinal, 7 bits fracionarios,
%          passo Delta = 2^-7 = 0,0078125).
%       2. Avaliar dois sinais de teste com Fs = 8000 Hz e L = 800 amostras:
%          - Caso 1: x1[n] = 0,8*sin(2*pi*500*n/Fs)
%          - Caso 2: x2[n] = 0,5*sin(2*pi*500*n/Fs) + 0,3*sin(2*pi*3000*n/Fs)
%       3. Quantizar x[n] por arredondamento e saturacao estrita ao intervalo
%          representavel [-1, 1 - 2^-7], calcular o erro de entrada
%          e[n] = xq[n] - x[n] e compara-lo ao limite teorico +-Delta/2 = +-2^-8.
%       4. Filtrar x[n] e xq[n] com os mesmos coeficientes h em ponto flutuante,
%          obter o erro na saida ey[n] = yq[n] - y[n] e medir as potencias medias
%          e a relacao sinal-ruido (SNR) na entrada e na saida (excluindo o
%          transitorio inicial para n >= 32, multiplo de 16 amostras >= N-1).
%       5. Exportar a tabela comparativa results/tab_D1_snr_comparacao.csv e as
%          figuras fig_D1_caso1_amostras_e_erros e fig_D2_caso2_amostras_e_erros.
%
%   Saidas:
%       resultado_D - Estrutura contendo os sinais, erros, potencias e SNRs
%                     dos Casos 1 e 2, alem da tabela comparativa.
%
%   Autor/Disciplina:
%       Processamento Digital de Sinais (SENAI CIMATEC) - Pratica 3

%% 1. Carregamento das Especificacoes e dos Coeficientes Originais
dir_script = fileparts(mfilename('fullpath'));
addpath(dir_script);
if isfolder(fullfile(dir_script, 'utils'))
    addpath(fullfile(dir_script, 'utils'));
end

specs = config_specs();

caminho_mat = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
if ~isfile(caminho_mat)
    error('EtapaD:ArquivoNaoEncontrado', ...
        'Arquivo %s nao encontrado. Execute etapa_A_janelamento antes da Etapa D.', caminho_mat);
end

dados_A = load(caminho_mat, 'h', 'N');
h = double(dados_A.h(:).'); % Coeficientes originais mantidos em ponto flutuante (double) [adimensional]
N = numel(h);               % Comprimento do filtro FIR (N = 23) [coeficientes]

Fs = specs.Fs;              % Frequencia de amostragem [Hz]
L  = 800;                   % Numero total de amostras dos sinais de teste [amostras]
n  = 0:(L - 1);             % Vetor de indices de tempo discreto (base 0) [amostras]

%% 2. Parametros de Quantizacao Q1.7 e Definicao da Janela de Regime Permanente
bits_frac       = 7;                     % Numero de bits fracionarios do formato Q1.7 [bits]
escala_Q17      = 2^bits_frac;           % Fator de escala 2^7 = 128 [adimensional]
passo_delta     = 2^(-bits_frac);        % Passo de quantizacao Delta = 2^-7 = 0,0078125 [amplitude]
meio_delta      = passo_delta / 2;       % Limite teorico de arredondamento Delta/2 = 2^-8 = 0,00390625 [amplitude]
lim_inf_Q17     = -1.0;                  % Limite inferior representavel em Q1.7 [-1] [amplitude]
lim_sup_Q17     = 1.0 - passo_delta;     % Limite superior representavel em Q1.7 [1 - 2^-7 = 0,9921875] [amplitude]

% Exclusao do transitorio inicial na saida:
% O filtro FIR de comprimento N = 23 possui transitorio inicial nas primeiras
% N - 1 = 22 amostras (n = 0..21). Como f1 = 500 Hz possui periodo fundamental
% N1 = Fs/f1 = 8000/500 = 16 amostras e f2 = 3000 Hz possui 6 ciclos a cada
% 16 amostras, adota-se n_inicio_regime = 32 (em base 0, correspondente ao
% indice MATLAB idx_inicio_regime = 33 em base 1).
% Dessa forma:
%   - Descartam-se as primeiras 32 amostras (n = 0..31), garantindo n >= N (32 >= 23);
%   - Restam exatamente L_regime = 800 - 32 = 768 amostras (48 periodos exatos de
%     16 amostras) em regime permanente para medicao sem vies das potencias medias.
n_inicio_regime   = ceil(N / 16) * 16;   % Indice temporal inicial do regime permanente (base 0: n = 32) [amostras]
idx_inicio_regime = n_inicio_regime + 1; % Indice inicial no vetor MATLAB (base 1: idx = 33) [amostras]
idx_regime        = idx_inicio_regime:L; % Vetor de indices em regime permanente (33..800) [amostras]
L_regime          = numel(idx_regime);   % Quantidade de amostras avaliadas em regime permanente (768) [amostras]
periodo_fund_amostras = 16;              % Periodo fundamental discreto dos sinais e do erro [amostras]

fprintf('======================================================================\n');
fprintf('ETAPA D - QUANTIZACAO DAS AMOSTRAS DE ENTRADA (Q1.7) E ANALISE DE SNR\n');
fprintf('======================================================================\n');
fprintf('Filtro FIR original (double): N = %d coeficientes (ordem M = %d)\n', N, N - 1);
fprintf('Formato Q1.7: Delta = 2^-%d = %.7f | Limite +-Delta/2 = +-%.8f\n', ...
    bits_frac, passo_delta, meio_delta);
fprintf('Intervalo estrito Q1.7: [%.7f, %.7f]\n', lim_inf_Q17, lim_sup_Q17);
fprintf('Corte de transitorio na saida: descartadas as primeiras %d amostras (n = 0..%d)\n', ...
    n_inicio_regime, n_inicio_regime - 1);
fprintf('Janela de regime permanente: n = %d..%d (idx = %d..%d, %d amostras = %d periodos de %d amostras)\n\n', ...
    n_inicio_regime, L - 1, idx_inicio_regime, L, L_regime, L_regime / periodo_fund_amostras, periodo_fund_amostras);

%% 3. Geracao dos Sinais de Teste (Caso 1 e Caso 2)
f1_Hz = 500;  % Frequencia da componente dentro da banda passante [Hz]
f2_Hz = 3000; % Frequencia da componente dentro da banda de rejeicao [Hz]

% Caso 1: Senoide pura na banda passante (500 Hz, amplitude 0,8)
A1_500 = 0.8; % Amplitude da senoide de 500 Hz no Caso 1 [amplitude]
x1 = A1_500 * sin(2 * pi * f1_Hz * n / Fs); % Sinal de entrada original do Caso 1 [amplitude]

% Caso 2: Soma de senoide na banda passante (500 Hz, amplitude 0,5) e na rejeicao (3000 Hz, amplitude 0,3)
A2_500  = 0.5; % Amplitude da componente de 500 Hz no Caso 2 [amplitude]
A2_3000 = 0.3; % Amplitude da componente de 3000 Hz no Caso 2 [amplitude]
x2 = A2_500 * sin(2 * pi * f1_Hz * n / Fs) + A2_3000 * sin(2 * pi * f2_Hz * n / Fs); % Sinal de entrada original do Caso 2 [amplitude]

%% 4. Processamento e Medicao de Metricas para Ambos os Casos
caso1 = processar_caso_quantizacao( ...
    "Caso 1: 0,8*sen(2*pi*500*n/Fs)", x1, h, ...
    escala_Q17, lim_inf_Q17, lim_sup_Q17, passo_delta, meio_delta, ...
    idx_regime, periodo_fund_amostras);

caso2 = processar_caso_quantizacao( ...
    "Caso 2: 0,5*sen(2*pi*500*n/Fs) + 0,3*sen(2*pi*3000*n/Fs)", x2, h, ...
    escala_Q17, lim_inf_Q17, lim_sup_Q17, passo_delta, meio_delta, ...
    idx_regime, periodo_fund_amostras);

casos = [caso1; caso2];
num_casos = numel(casos);

%% 5. Impressao no Console e Exportacao da Tabela Comparativa
fprintf('%-10s | %-11s | %-11s | %-11s | %-12s | %-12s | %-12s | %-12s\n', ...
    'Sinal', 'SNR_in [dB]', 'SNR_out[dB]', 'Delta [dB]', 'P_x [W]', 'P_y_ss [W]', 'P_e [W]', 'P_ey_ss [W]');
fprintf('%s\n', repmat('-', 1, 108));
for k = 1:num_casos
    c = casos(k);
    fprintf('Caso %-5d | %11.4f | %11.4f | %+11.4f | %12.6e | %12.6e | %12.6e | %12.6e\n', ...
        k, c.SNR_in_dB, c.SNR_out_dB, c.delta_SNR_dB, ...
        c.P_x, c.P_y_ss, c.P_e, c.P_ey_ss);
end
fprintf('\n');

for k = 1:num_casos
    c = casos(k);
    fprintf('Resumo Detalhado - %s:\n', c.descricao);
    fprintf('  Erro abs. maximo na entrada max|e[n]|   : %.8f (Limite Delta/2 = %.8f | %.2f%% de Delta/2 | Atende: %d)\n', ...
        c.erro_max_in, c.meio_delta, 100 * (c.erro_max_in / c.meio_delta), c.atende_limite_delta);
    fprintf('  Erro abs. maximo na saida (regime perm.): %.8f (Total c/ transitorio = %.8f)\n', ...
        c.erro_max_out_ss, c.erro_max_out_total);
    fprintf('  Variacao da potencia do sinal (Saida/Ent): %+.4f dB (P_x = %.6f -> P_y_ss = %.6f)\n', ...
        c.var_pot_sinal_dB, c.P_x, c.P_y_ss);
    fprintf('  Variacao da potencia do ruido (Saida/Ent): %+.4f dB (P_e = %.6e -> P_ey_ss = %.6e)\n', ...
        c.var_pot_ruido_dB, c.P_e, c.P_ey_ss);
    fprintf('  Periodicidade de e[n] (periodo N0 = %d)  : erro max entre ciclos = %.4e\n\n', ...
        periodo_fund_amostras, c.erro_periodicidade_in);
end

% Montagem da tabela tab_D1_snr_comparacao.csv
Caso                  = ["Caso 1"; "Caso 2"];
Descricao_Sinal       = [caso1.descricao; caso2.descricao];
Amostras_Total        = [L; L];
Inicio_Regime_Amostra = [n_inicio_regime; n_inicio_regime];
Amostras_Regime       = [L_regime; L_regime];
Passo_Delta           = [passo_delta; passo_delta];
Limite_Meio_Delta     = [meio_delta; meio_delta];
Erro_Max_Entrada      = [caso1.erro_max_in; caso2.erro_max_in];
Atende_Meio_Delta     = [caso1.atende_limite_delta; caso2.atende_limite_delta];
Erro_Max_Saida_Regime = [caso1.erro_max_out_ss; caso2.erro_max_out_ss];
Pot_Sinal_Entrada     = [caso1.P_x; caso2.P_x];
Pot_Ruido_Entrada     = [caso1.P_e; caso2.P_e];
Pot_Sinal_Saida_Reg   = [caso1.P_y_ss; caso2.P_y_ss];
Pot_Ruido_Saida_Reg   = [caso1.P_ey_ss; caso2.P_ey_ss];
Var_Pot_Sinal_dB      = [caso1.var_pot_sinal_dB; caso2.var_pot_sinal_dB];
Var_Pot_Ruido_dB      = [caso1.var_pot_ruido_dB; caso2.var_pot_ruido_dB];
SNR_Entrada_dB        = [caso1.SNR_in_dB; caso2.SNR_in_dB];
SNR_Saida_dB          = [caso1.SNR_out_dB; caso2.SNR_out_dB];
Delta_SNR_dB          = [caso1.delta_SNR_dB; caso2.delta_SNR_dB];

tab_D1 = table( ...
    Caso, Descricao_Sinal, Amostras_Total, Inicio_Regime_Amostra, Amostras_Regime, ...
    Passo_Delta, Limite_Meio_Delta, Erro_Max_Entrada, Atende_Meio_Delta, Erro_Max_Saida_Regime, ...
    Pot_Sinal_Entrada, Pot_Ruido_Entrada, Pot_Sinal_Saida_Reg, Pot_Ruido_Saida_Reg, ...
    Var_Pot_Sinal_dB, Var_Pot_Ruido_dB, SNR_Entrada_dB, SNR_Saida_dB, Delta_SNR_dB);

caminho_tab_D1 = fullfile(specs.caminhos.results, 'tab_D1_snr_comparacao.csv');
writetable(tab_D1, caminho_tab_D1);

%% 6. Geracao e Exportacao das Figuras (Caso 1 e Caso 2)
gerar_figura_caso_D(n, caso1, 1, n_inicio_regime, periodo_fund_amostras, ...
    'fig_D1_caso1_amostras_e_erros', specs);

gerar_figura_caso_D(n, caso2, 2, n_inicio_regime, periodo_fund_amostras, ...
    'fig_D2_caso2_amostras_e_erros', specs);

fprintf('Arquivos gerados com sucesso:\n');
fprintf('  - %s\n', caminho_tab_D1);
fprintf('  - %s (.pdf e .png)\n', fullfile(specs.caminhos.figures, 'fig_D1_caso1_amostras_e_erros'));
fprintf('  - %s (.pdf e .png)\n\n', fullfile(specs.caminhos.figures, 'fig_D2_caso2_amostras_e_erros'));

%% 7. Estrutura de Retorno
resultado_D.N                     = N;
resultado_D.Fs                    = Fs;
resultado_D.L                     = L;
resultado_D.n                     = n;
resultado_D.n_inicio_regime       = n_inicio_regime;
resultado_D.idx_regime            = idx_regime;
resultado_D.L_regime              = L_regime;
resultado_D.passo_delta           = passo_delta;
resultado_D.meio_delta            = meio_delta;
resultado_D.caso1                 = caso1;
resultado_D.caso2                 = caso2;
resultado_D.tab_D1                = tab_D1;
end

%% ========================================================================
%  Funcoes Locais Auxiliares
%  ========================================================================

function res = processar_caso_quantizacao(descricao, x, h, ...
    escala_Q17, lim_inf_Q17, lim_sup_Q17, passo_delta, meio_delta, ...
    idx_regime, periodo_fund)
% PROCESSAR_CASO_QUANTIZACAO Quantiza a entrada em Q1.7, filtra e calcula potencias e SNRs.
%
%   Entradas:
%       descricao    - Texto descritivo do caso de teste
%       x            - Sinal de entrada original em ponto flutuante [amplitude]
%       h            - Coeficientes originais do filtro FIR em ponto flutuante [adimensional]
%       escala_Q17   - Fator de escala 2^7 = 128 [adimensional]
%       lim_inf_Q17  - Limite inferior de saturacao (-1) [amplitude]
%       lim_sup_Q17  - Limite superior de saturacao (1 - 2^-7) [amplitude]
%       passo_delta  - Passo de quantizacao Delta = 2^-7 [amplitude]
%       meio_delta   - Meio passo Delta/2 = 2^-8 [amplitude]
%       idx_regime   - Indices das amostras em regime permanente (base 1) [amostras]
%       periodo_fund - Periodo fundamental do sinal discreto (16 amostras) [amostras]
%
%   Saidas:
%       res          - Estrutura com sinais, erros, potencias e metricas de SNR

% 1. Quantizacao Q1.7 com arredondamento e saturacao estrita em [-1, 1 - 2^-7]
xq_arred = round(x * escala_Q17) / escala_Q17;                % Amostras arredondadas para multiplo de 2^-7 [amplitude]
xq       = min(max(xq_arred, lim_inf_Q17), lim_sup_Q17);      % Amostras quantizadas e saturadas em Q1.7 [amplitude]

% 2. Erro de quantizacao na entrada
e = xq - x;                                                   % Erro de quantizacao na entrada e[n] = xq[n] - x[n] [amplitude]

% 3. Filtragem com os mesmos coeficientes h em ponto flutuante
y  = filter(h, 1, x);                                         % Saida ideal com entrada em ponto flutuante [amplitude]
yq = filter(h, 1, xq);                                        % Saida com entrada quantizada em Q1.7 [amplitude]
ey = yq - y;                                                  % Erro na saida do filtro ey[n] = yq[n] - y[n] [amplitude]

% 4. Potencias medias na entrada (sobre todas as L amostras, multiplo exato de 16)
P_x = mean(x.^2);                                             % Potencia media do sinal de entrada [amplitude^2]
P_e = mean(e.^2);                                             % Potencia media do erro de entrada [amplitude^2]

% 5. Potencias medias na saida (exclusivamente em regime permanente: idx_regime)
y_ss  = y(idx_regime);                                        % Saida ideal em regime permanente [amplitude]
yq_ss = yq(idx_regime);                                       % Saida com entrada quantizada em regime permanente [amplitude]
ey_ss = ey(idx_regime);                                       % Erro de saida em regime permanente [amplitude]

P_y_ss  = mean(y_ss.^2);                                      % Potencia media do sinal util na saida [amplitude^2]
P_ey_ss = mean(ey_ss.^2);                                     % Potencia media do erro na saida [amplitude^2]

% 6. Relacoes Sinal-Ruido (SNR) e variacoes de potencia em dB
SNR_in_dB        = 10 * log10(P_x / P_e);                     % SNR na entrada do filtro [dB]
SNR_out_dB       = 10 * log10(P_y_ss / P_ey_ss);              % SNR na saida do filtro (regime permanente) [dB]
delta_SNR_dB     = SNR_out_dB - SNR_in_dB;                    % Variacao de SNR (SNR_out - SNR_in) [dB]
var_pot_sinal_dB = 10 * log10(P_y_ss / P_x);                  % Variacao da potencia do sinal util [dB]
var_pot_ruido_dB = 10 * log10(P_ey_ss / P_e);                 % Variacao da potencia do ruido de quantizacao [dB]

% 7. Extremos de erro e verificacao frente a +-Delta/2
erro_max_in         = max(abs(e));                            % Erro absoluto maximo na entrada [amplitude]
erro_min_in         = min(e);                                 % Menor valor algébrico de e[n] [amplitude]
erro_sup_in         = max(e);                                 % Maior valor algébrico de e[n] [amplitude]
atende_limite_delta = (erro_max_in <= (meio_delta + 1e-12));  % Confirmacao de |e[n]| <= Delta/2 [logico]
erro_max_out_ss     = max(abs(ey_ss));                        % Erro absoluto maximo na saida em regime permanente [amplitude]
erro_max_out_total  = max(abs(ey));                           % Erro absoluto maximo na saida incluindo transitorio [amplitude]

% 8. Verificacao numerica da periodicidade de e[n] com periodo N0 = 16 amostras
e_bloco1 = e(1:(end - periodo_fund));
e_bloco2 = e((1 + periodo_fund):end);
erro_periodicidade_in = max(abs(e_bloco2 - e_bloco1));        % Desvio maximo entre amostras separadas por N0 [amplitude]

% Armazenamento na estrutura de saida
res.descricao             = descricao;
res.x                     = x;
res.xq                    = xq;
res.e                     = e;
res.y                     = y;
res.yq                    = yq;
res.ey                    = ey;
res.P_x                   = P_x;
res.P_e                   = P_e;
res.P_y_ss                = P_y_ss;
res.P_ey_ss               = P_ey_ss;
res.SNR_in_dB             = SNR_in_dB;
res.SNR_out_dB            = SNR_out_dB;
res.delta_SNR_dB          = delta_SNR_dB;
res.var_pot_sinal_dB      = var_pot_sinal_dB;
res.var_pot_ruido_dB      = var_pot_ruido_dB;
res.passo_delta           = passo_delta;
res.meio_delta            = meio_delta;
res.erro_max_in           = erro_max_in;
res.erro_min_in           = erro_min_in;
res.erro_sup_in           = erro_sup_in;
res.atende_limite_delta   = atende_limite_delta;
res.erro_max_out_ss       = erro_max_out_ss;
res.erro_max_out_total    = erro_max_out_total;
res.erro_periodicidade_in = erro_periodicidade_in;
end

function gerar_figura_caso_D(n, caso, num_caso, n_inicio_regime, periodo_fund, nome_base, specs)
% GERAR_FIGURA_CASO_D Plota amostras originais/quantizadas e erros na entrada e saida com marcadores.
%
%   Entradas:
%       n               - Vetor de indices de amostra [amostras]
%       caso            - Estrutura retornada por processar_caso_quantizacao
%       num_caso        - Indice numerico do caso (1 ou 2)
%       n_inicio_regime - Indice inicial do regime permanente (32) [amostras]
%       periodo_fund    - Periodo fundamental do sinal discreto (16) [amostras]
%       nome_base       - Nome base do arquivo para salvar_figura
%       specs           - Estrutura de especificacoes e caminhos

% Janelas de visualizacao para destacar os marcadores discretos e a periodicidade:
% - Painel 1: 3 periodos fundamentais (n = 0..47, 48 amostras) para visualizar
%             nitidamente os marcadores de x[n] e os patamares discretos de xq[n].
% - Painel 2: 4 periodos fundamentais (n = 0..63, 64 amostras) para evidenciar a
%             repeticao periodica exata do erro e[n] a cada 16 amostras e o
%             confinamento dentro de +-Delta/2.
% - Painel 3: n = 0..95 (96 amostras) para mostrar o transitorio inicial do filtro
%             (n < 32) seguido da estabilizacao periodica de ey[n] em regime permanente.
idx_jan_sinal = (n >= 0) & (n <= 3 * periodo_fund - 1); % n = 0..47 [amostras]
idx_jan_ein   = (n >= 0) & (n <= 4 * periodo_fund - 1); % n = 0..63 [amostras]
idx_jan_eout  = (n >= 0) & (n <= 6 * periodo_fund - 1); % n = 0..95 [amostras]

meio_delta_mV = caso.meio_delta * 1e3; % Limite Delta/2 em mili-unidades (10^-3) [10^-3 amplitude]

fig = figure('Name', sprintf('Etapa D - Caso %d: Quantizacao de Amostras Q1.7', num_caso), ...
    'Position', [100, 80, 920, 760], 'Visible', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Painel 1: Amostras Originais x[n] vs Quantizadas xq[n] (com marcadores explicitos) ---
nexttile;
plot(n(idx_jan_sinal), caso.x(idx_jan_sinal), '-o', ...
    'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.2, 'MarkerSize', 5, ...
    'MarkerFaceColor', [0.00, 0.45, 0.74]);
hold on;
stem(n(idx_jan_sinal), caso.xq(idx_jan_sinal), 's', ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.1, 'MarkerSize', 5.5);
% Degraus de quantizacao tracejados conectando os niveis discretos de xq[n]
stairs(n(idx_jan_sinal), caso.xq(idx_jan_sinal), ':', ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.0, 'HandleVisibility', 'off');
for p = 1:2
    xline(p * periodo_fund, ':', 'Color', [0.55, 0.55, 0.55], ...
        'LineWidth', 0.9, 'HandleVisibility', 'off');
end
hold off;
title(sprintf('%s — Amostras x[n] vs x_q[n] em Q1.7 (\\Delta = 2^{-7} = %.7f)', ...
    caso.descricao, caso.passo_delta));
xlabel('Amostra [n]');
ylabel('Amplitude');
xlim([0, 3 * periodo_fund - 1]);
ylim([-1.10, 1.35]);
legend({'x[n] original (double)', 'x_q[n] quantizado (Q1.7)'}, ...
    'Location', 'north', 'Orientation', 'horizontal');

% --- Painel 2: Erro de Quantizacao na Entrada e[n] = xq[n] - x[n] vs +-Delta/2 ---
nexttile;
stem(n(idx_jan_ein), caso.e(idx_jan_ein) * 1e3, 'filled', ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.1, 'MarkerSize', 4.5);
hold on;
plot(n(idx_jan_ein), caso.e(idx_jan_ein) * 1e3, '-', ...
    'Color', [0.85, 0.33, 0.10, 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');
yline( meio_delta_mV, '--r', 'LineWidth', 1.2);
yline(-meio_delta_mV, '--r', 'LineWidth', 1.2, 'HandleVisibility', 'off');
for p = 1:3
    if p == 1
        xline(p * periodo_fund, ':', 'Color', [0.35, 0.35, 0.35], 'LineWidth', 1.0);
    else
        xline(p * periodo_fund, ':', 'Color', [0.35, 0.35, 0.35], ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
end
hold off;
title(sprintf('Erro na Entrada e[n] = x_q[n] - x[n] (max|e[n]| = %.4f \\times 10^{-3} \\leq \\Delta/2 = %.4f \\times 10^{-3}, SNR_{in} = %.2f dB)', ...
    caso.erro_max_in * 1e3, meio_delta_mV, caso.SNR_in_dB));
xlabel('Amostra [n]');
ylabel('Erro e[n] [\times 10^{-3}]');
xlim([0, 4 * periodo_fund - 1]);
ylim([-1.30 * meio_delta_mV, 1.65 * meio_delta_mV]);
legend({'e[n] = x_q[n] - x[n]', ...
    sprintf('Limites \\pm\\Delta/2 (\\pm%.4f \\times 10^{-3})', meio_delta_mV), ...
    sprintf('Período N_0 = %d amostras', periodo_fund)}, ...
    'Location', 'north', 'Orientation', 'horizontal');

% --- Painel 3: Erro na Saida Filtrada ey[n] = yq[n] - y[n] (Transitorio e Regime Permanente) ---
nexttile;
plot(n(idx_jan_eout), caso.ey(idx_jan_eout) * 1e3, '-o', ...
    'Color', [0.13, 0.55, 0.13], 'LineWidth', 1.1, 'MarkerSize', 4, ...
    'MarkerFaceColor', [0.13, 0.55, 0.13]);
hold on;
yline( meio_delta_mV, '--r', 'LineWidth', 1.1);
yline(-meio_delta_mV, '--r', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(n_inicio_regime, '-.k', 'LineWidth', 1.3);
hold off;
title(sprintf('Erro na Saída e_y[n] = y_q[n] - y[n] (Regime n \\geq %d: max|e_y[n]| = %.4f \\times 10^{-3}, SNR_{out} = %.2f dB, \\Delta SNR = %+.2f dB)', ...
    n_inicio_regime, caso.erro_max_out_ss * 1e3, caso.SNR_out_dB, caso.delta_SNR_dB));
xlabel('Amostra [n]');
ylabel('Erro e_y[n] [\times 10^{-3}]');
xlim([0, 6 * periodo_fund - 1]);
ylim([-1.30 * meio_delta_mV, 1.65 * meio_delta_mV]);
legend({'e_y[n] = y_q[n] - y[n]', ...
    sprintf('Referência \\pm\\Delta/2 (\\pm%.4f \\times 10^{-3})', meio_delta_mV), ...
    sprintf('Início do regime permanente (n = %d)', n_inicio_regime)}, ...
    'Location', 'north', 'Orientation', 'horizontal');

salvar_figura(fig, nome_base, specs);
close(fig);
end
