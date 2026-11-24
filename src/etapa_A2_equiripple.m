function resultado_A2 = etapa_A2_equiripple()
% ETAPA_A2_EQUIRIPPLE Comparacao entre o filtro FIR por Janelamento (Hamming) e Equiripple (Filter Designer).
%
%   Proposito:
%       Implementar integralmente a Etapa A2 da Pratica 3:
%       1. Carregar os coeficientes h do filtro FIR projetado na Etapa A
%          (serie de Fourier com janela de Hamming, N = 23) a partir de
%          data/coeficientes_FIR.mat, sem jamais sobrescreve-lo.
%       2. Verificar a existencia de data/coeficientes_equiripple.mat
%          (exportado do Filter Designer). Caso nao exista, emitir aviso
%          claro em portugues no console, projetar o filtro Equiripple de
%          ordem minima para a mesma mascara via firpmord + firpm (ajustando
%          a ordem ate atender estritamente a avaliar_mascara) e salvar em
%          data/coeficientes_equiripple.mat.
%       3. Avaliar ambos os filtros exatamente com a mesma funcao
%          avaliar_mascara.m em grade densa de frequencia.
%       4. Exportar a tabela comparativa results/tab_A2_comparacao_equiripple.csv
%          com as metricas exigidas pelo roteiro.
%       5. Gerar e exportar a figura figures/fig_A2_comp_janelamento_equiripple
%          (.pdf e .png) sobrepondo as respostas em magnitude de 0 a 4.000 Hz
%          e as ampliacoes (zoom) na banda passante e na banda de rejeicao.
%
%   Saidas:
%       resultado_A2 - Estrutura contendo os coeficientes, avaliacoes e
%                      tabela comparativa entre Janelamento e Equiripple.
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

Fs           = specs.Fs;           % Frequencia de amostragem [Hz]
Fpass        = specs.Fpass;        % Frequencia limite da banda passante [Hz]
Fstop        = specs.Fstop;        % Frequencia inicial da banda de rejeicao [Hz]
tol_pass_dB  = specs.tol_pass_dB;  % Desvio maximo permitido na banda passante [dB]
aten_stop_dB = specs.aten_stop_dB; % Atenuacao minima exigida na banda de rejeicao [dB]

fprintf('======================================================================\n');
fprintf('ETAPA A2 - FILTER DESIGNER E COMPARACAO JANELAMENTO VS EQUIRIPPLE\n');
fprintf('======================================================================\n');

%% 2. Carregamento do Filtro Principal por Janelamento (Etapa A)
caminho_fir = fullfile(specs.caminhos.data, 'coeficientes_FIR.mat');
if ~isfile(caminho_fir)
    error('EtapaA2:ArquivoAusente', ...
        'Arquivo %s nao encontrado. Execute etapa_A_janelamento.m primeiro.', caminho_fir);
end

dados_fir = load(caminho_fir, 'h');
h_janelamento = dados_fir.h(:).';              % Coeficientes do filtro por janelamento [adimensional]
N_janelamento = numel(h_janelamento);          % Numero de coeficientes do filtro por janelamento [coeficientes]
ordem_janelamento = N_janelamento - 1;         % Ordem do filtro por janelamento [adimensional]
atraso_jan_amostras = ordem_janelamento / 2;   % Atraso de grupo do filtro por janelamento [amostras]
atraso_jan_ms = (atraso_jan_amostras / Fs) * 1000; % Atraso de grupo do filtro por janelamento [ms]

%% 3. Carregamento ou Projeto Automatico (Fallback) do Filtro Equiripple
caminho_eq = fullfile(specs.caminhos.data, 'coeficientes_equiripple.mat');

if isfile(caminho_eq)
    fprintf('Carregando coeficientes Equiripple existentes de:\n  %s\n\n', caminho_eq);
    dados_eq = load(caminho_eq);
    if isfield(dados_eq, 'h_equiripple')
        h_equiripple = dados_eq.h_equiripple(:).'; % Coeficientes do filtro Equiripple [adimensional]
    elseif isfield(dados_eq, 'Num')
        h_equiripple = dados_eq.Num(:).';          % Coeficientes exportados como Num pelo Filter Designer [adimensional]
    else
        nomes_campos = fieldnames(dados_eq);
        h_equiripple = dados_eq.(nomes_campos{1})(:).'; % Primeiro vetor encontrado no arquivo .mat [adimensional]
    end
else
    fprintf('[AVISO] Arquivo %s nao encontrado.\n', caminho_eq);
    fprintf('        Projetando filtro FIR Equiripple de ordem minima via firpmord + firpm\n');
    fprintf('        para a mesma mascara (Fs = %d Hz, Fpass = %d Hz, Fstop = %d Hz,\n', Fs, Fpass, Fstop);
    fprintf('        desvio passante <= +/-%.2f dB, atenuacao rejeicao >= %.1f dB)...\n\n', tol_pass_dB, aten_stop_dB);

    % Conversao das tolerancias em dB para desvios lineares (ripple)
    % Para garantir |20*log10(|H(f)|)| <= tol_pass_dB em torno de 0 dB (ganho unitario),
    % usa-se o limite linear mais restritivo entre o pico superior e o vale inferior:
    desvio_pass_linear = 1 - 10^(-tol_pass_dB / 20); % Desvio linear maximo na banda passante [adimensional]
    desvio_stop_linear = 10^(-aten_stop_dB / 20);    % Desvio linear maximo na banda de rejeicao [adimensional]

    % Estimativa inicial de ordem minima via firpmord (Parks-McClellan)
    [ordem_est_eq, freq_norm_eq, amp_desejada_eq, pesos_eq] = firpmord( ...
        [Fpass, Fstop], [1, 0], [desvio_pass_linear, desvio_stop_linear], Fs);

    % Busca ascendente a partir de max(1, ordem_est_eq - 2) para garantir a menor ordem
    % que satisfaz estritamente avaliar_mascara(h_equiripple, specs)
    ordem_busca_inicio = max(1, ordem_est_eq - 2); % Ordem inicial da busca [adimensional]
    ordem_busca_fim    = ordem_est_eq + 15;        % Ordem maxima da busca [adimensional]
    h_equiripple       = [];

    for ordem_cand = ordem_busca_inicio:ordem_busca_fim
        h_cand = firpm(ordem_cand, freq_norm_eq, amp_desejada_eq, pesos_eq); % Coeficientes candidatos [adimensional]
        aval_cand = avaliar_mascara(h_cand, specs);

        if aval_cand.atende_mascara
            h_equiripple = h_cand(:).'; % Coeficientes do filtro Equiripple aprovado [adimensional]
            break;
        end
    end

    if isempty(h_equiripple)
        error('EtapaA2:FalhaProjetoEquiripple', ...
            'Nao foi possivel encontrar filtro Equiripple que atenda a mascara na faixa testada.');
    end

    N_equiripple     = numel(h_equiripple);      % Numero de coeficientes Equiripple [coeficientes]
    ordem_equiripple = N_equiripple - 1;         % Ordem do filtro Equiripple [adimensional]
    atraso_eq_amostras = ordem_equiripple / 2;   % Atraso de grupo Equiripple [amostras]
    atraso_eq_ms       = (atraso_eq_amostras / Fs) * 1000; % Atraso de grupo Equiripple [ms]

    % Salva data/coeficientes_equiripple.mat sem tocar em data/coeficientes_FIR.mat
    save(caminho_eq, 'h_equiripple', 'N_equiripple', 'ordem_equiripple', ...
        'atraso_eq_amostras', 'atraso_eq_ms', 'Fs', 'Fpass', 'Fstop', ...
        'tol_pass_dB', 'aten_stop_dB');
    fprintf('Filtro Equiripple salvo com sucesso em:\n  %s\n\n', caminho_eq);
end

N_equiripple       = numel(h_equiripple);              % Numero de coeficientes Equiripple [coeficientes]
ordem_equiripple   = N_equiripple - 1;                 % Ordem do filtro Equiripple [adimensional]
atraso_eq_amostras = ordem_equiripple / 2;             % Atraso de grupo Equiripple [amostras]
atraso_eq_ms       = (atraso_eq_amostras / Fs) * 1000; % Atraso de grupo Equiripple [ms]

%% 4. Avaliacao Padronizada de Ambos os Filtros via avaliar_mascara.m
aval_jan = avaliar_mascara(h_janelamento, specs); % Metricas do filtro por Janelamento
aval_eq  = avaliar_mascara(h_equiripple, specs);  % Metricas do filtro Equiripple

soma_jan = sum(h_janelamento);                           % Soma dos coeficientes Janelamento [adimensional]
soma_eq  = sum(h_equiripple);                            % Soma dos coeficientes Equiripple [adimensional]
sim_jan  = max(abs(h_janelamento - fliplr(h_janelamento))); % Erro maximo de simetria Janelamento [adimensional]
sim_eq   = max(abs(h_equiripple  - fliplr(h_equiripple)));  % Erro maximo de simetria Equiripple [adimensional]

if aval_jan.atende_mascara
    str_atende_jan = "Sim";
else
    str_atende_jan = "Nao";
end

if aval_eq.atende_mascara
    str_atende_eq = "Sim";
else
    str_atende_eq = "Nao";
end

fprintf('----------------------------------------------------------------------\n');
fprintf('COMPARACAO DE DESEMPENHO: JANELAMENTO (HAMMING) VS EQUIRIPPLE\n');
fprintf('----------------------------------------------------------------------\n');
fprintf('%-38s | %-15s | %-15s\n', 'Metrica', 'Janelamento', 'Equiripple');
fprintf('%s\n', repmat('-', 1, 74));
fprintf('%-38s | %-15d | %-15d\n', 'Numero de coeficientes (N)', N_janelamento, N_equiripple);
fprintf('%-38s | %-15d | %-15d\n', 'Ordem do filtro (M = N - 1)', ordem_janelamento, ordem_equiripple);
fprintf('%-38s | %-15.6f | %-15.6f\n', 'Desvio maximo na passante (dB)', aval_jan.desvio_pass_max_dB, aval_eq.desvio_pass_max_dB);
fprintf('%-38s | %-15.4f | %-15.4f\n', 'Atenuacao minima na rejeicao (dB)', aval_jan.aten_stop_min_dB, aval_eq.aten_stop_min_dB);
fprintf('%-38s | %-15.6f | %-15.6f\n', 'Ganho DC (dB)', aval_jan.ganho_dc_dB, aval_eq.ganho_dc_dB);
fprintf('%-38s | %-15.6f | %-15.6f\n', 'Soma dos coeficientes sum(h)', soma_jan, soma_eq);
fprintf('%-38s | %-15.2f | %-15.2f\n', 'Atraso de grupo (amostras)', atraso_jan_amostras, atraso_eq_amostras);
fprintf('%-38s | %-15.4f | %-15.4f\n', 'Atraso de grupo (ms)', atraso_jan_ms, atraso_eq_ms);
fprintf('%-38s | %-15s | %-15s\n', 'Atende a mascara?', str_atende_jan, str_atende_eq);
fprintf('----------------------------------------------------------------------\n\n');

%% 5. Exportacao da Tabela Comparativa (results/tab_A2_comparacao_equiripple.csv)
Resultado = [
    "Numero de coeficientes";
    "Ordem do filtro";
    "Desvio maximo na passante (dB)";
    "Atenuacao minima na rejeicao (dB)";
    "Ganho DC (dB)";
    "Soma dos coeficientes";
    "Atraso de grupo (amostras)";
    "Atraso de grupo (ms)";
    "Atende a mascara?"
    ];

Janelamento = [
     sprintf("%d", N_janelamento);
     sprintf("%d", ordem_janelamento);
     sprintf("%.6f", aval_jan.desvio_pass_max_dB);
     sprintf("%.4f", aval_jan.aten_stop_min_dB);
     sprintf("%.6f", aval_jan.ganho_dc_dB);
     sprintf("%.6f", soma_jan);
     sprintf("%.1f", atraso_jan_amostras);
     sprintf("%.4f", atraso_jan_ms);
     str_atende_jan
    ];

Equiripple = [
     sprintf("%d", N_equiripple);
     sprintf("%d", ordem_equiripple);
     sprintf("%.6f", aval_eq.desvio_pass_max_dB);
     sprintf("%.4f", aval_eq.aten_stop_min_dB);
     sprintf("%.6f", aval_eq.ganho_dc_dB);
     sprintf("%.6f", soma_eq);
     sprintf("%.1f", atraso_eq_amostras);
     sprintf("%.4f", atraso_eq_ms);
     str_atende_eq
    ];

tab_comp = table(Resultado, Janelamento, Equiripple);
caminho_csv = fullfile(specs.caminhos.results, 'tab_A2_comparacao_equiripple.csv');
writetable(tab_comp, caminho_csv);

%% 6. Geracao da Figura Comparativa (figures/fig_A2_comp_janelamento_equiripple)
f_Hz       = aval_jan.f_Hz;   % Vetor de frequencia avaliado [Hz]
mag_jan_dB = aval_jan.mag_dB; % Magnitude do filtro por Janelamento [dB]
mag_eq_dB  = aval_eq.mag_dB;  % Magnitude do filtro Equiripple [dB]

fig_comp = figure('Name', 'Etapa A2 - Comparacao Janelamento vs Equiripple', ...
    'Position', [100, 100, 940, 700], 'Visible', 'off');
tiledlayout(fig_comp, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Painel 1 (Superior, 2 colunas): Resposta em Magnitude Global (0 a 4000 Hz) ---
nexttile([1, 2]);
plot(f_Hz, mag_jan_dB, 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
plot(f_Hz, mag_eq_dB, 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.4, 'LineStyle', '-');
% Limites da mascara na banda passante (+0,1 dB e -0,1 dB ate 1000 Hz)
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], '--k', 'LineWidth', 1.1);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
% Limite da mascara na banda de rejeicao (-45 dB de 2200 a 4000 Hz)
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
% Linhas verticais de referencia das bordas das bandas
xline(Fpass, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
xline(Fstop, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
hold off;
title(sprintf('Comparação da Resposta em Magnitude: Janelamento (N = %d) vs Equiripple (N = %d)', ...
    N_janelamento, N_equiripple));
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, Fs/2]);
ylim([-100, 5]);
legend({sprintf('Janelamento Hamming (N = %d, M = %d)', N_janelamento, ordem_janelamento), ...
        sprintf('Equiripple Ordem Mínima (N = %d, M = %d)', N_equiripple, ordem_equiripple), ...
        sprintf('Limite passante (\\pm%.1f dB até %d Hz)', tol_pass_dB, Fpass), ...
        sprintf('Limite rejeição (-%d dB a partir de %d Hz)', round(aten_stop_dB), Fstop)}, ...
        'Location', 'southwest');

% --- Painel 2 (Inferior esquerdo): Ampliacao na Banda Passante ---
nexttile;
idx_ampliacao_pass = (f_Hz >= 0) & (f_Hz <= 1150); % Indices da faixa ampliada da banda passante [logico]
plot(f_Hz(idx_ampliacao_pass), mag_jan_dB(idx_ampliacao_pass), 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
plot(f_Hz(idx_ampliacao_pass), mag_eq_dB(idx_ampliacao_pass), 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.4);
plot([0, Fpass], [ tol_pass_dB,  tol_pass_dB], '--k', 'LineWidth', 1.1);
plot([0, Fpass], [-tol_pass_dB, -tol_pass_dB], '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xline(Fpass, ':k', 'LineWidth', 1.0);
yline(0, ':', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.8, 'HandleVisibility', 'off');
hold off;
title({'Ampliação da Banda Passante', ...
    sprintf('(Desvio máx: Jan = %.4f dB | Eq = %.4f dB)', ...
    aval_jan.desvio_pass_max_dB, aval_eq.desvio_pass_max_dB)});
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([0, 1100]);
ylim([-0.15, 0.15]);
legend({'Janelamento', 'Equiripple', sprintf('Máscara \\pm%.1f dB', tol_pass_dB), ...
    sprintf('F_{pass} = %d Hz', Fpass)}, 'Location', 'southwest');

% --- Painel 3 (Inferior direito): Ampliacao na Banda de Rejeicao ---
nexttile;
idx_ampliacao_stop = (f_Hz >= 2050) & (f_Hz <= Fs/2); % Indices da faixa ampliada da banda de rejeicao [logico]
plot(f_Hz(idx_ampliacao_stop), mag_jan_dB(idx_ampliacao_stop), 'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.5);
hold on;
plot(f_Hz(idx_ampliacao_stop), mag_eq_dB(idx_ampliacao_stop), 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.4);
plot([Fstop, Fs/2], [-aten_stop_dB, -aten_stop_dB], '--m', 'LineWidth', 1.2);
xline(Fstop, ':k', 'LineWidth', 1.0);
hold off;
title({'Ampliação da Banda de Rejeição', ...
    sprintf('(Atenuação mín: Jan = %.2f dB | Eq = %.2f dB)', ...
    aval_jan.aten_stop_min_dB, aval_eq.aten_stop_min_dB)});
xlabel('Frequência [Hz]');
ylabel('Magnitude [dB]');
xlim([2100, Fs/2]);
ylim([-95, -35]);
legend({'Janelamento', 'Equiripple', sprintf('Máscara -%d dB', round(aten_stop_dB)), ...
    sprintf('F_{stop} = %d Hz', Fstop)}, 'Location', 'northeast');

caminhos_fig = salvar_figura(fig_comp, 'fig_A2_comp_janelamento_equiripple', specs);
close(fig_comp);

fprintf('Arquivos da Etapa A2 gerados com sucesso:\n');
fprintf('  - %s\n', caminho_eq);
fprintf('  - %s\n', caminho_csv);
fprintf('  - %s\n', caminhos_fig.pdf);
fprintf('  - %s\n\n', caminhos_fig.png);

%% 7. Estrutura de Retorno
resultado_A2.h_janelamento     = h_janelamento;
resultado_A2.N_janelamento     = N_janelamento;
resultado_A2.ordem_janelamento = ordem_janelamento;
resultado_A2.aval_janelamento  = aval_jan;
resultado_A2.sim_janelamento   = sim_jan;
resultado_A2.h_equiripple      = h_equiripple;
resultado_A2.N_equiripple      = N_equiripple;
resultado_A2.ordem_equiripple  = ordem_equiripple;
resultado_A2.aval_equiripple   = aval_eq;
resultado_A2.sim_equiripple    = sim_eq;
resultado_A2.tab_comparacao    = tab_comp;
end
