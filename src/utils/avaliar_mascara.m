function res = avaliar_mascara(h, specs)
% AVALIAR_MASCARA Avalia a resposta em frequencia de um filtro FIR frente a mascara.
%
%   Proposito:
%       Calcular com grade densa de frequencia (Nfft >= 16384) o desvio maximo
%       na banda passante, a atenuacao minima na banda de rejeicao, o ganho DC
%       e o atendimento simultaneo a todas as exigencias da mascara.
%
%   Entradas:
%       h     - Vetor de coeficientes da resposta ao impulso do filtro FIR [adimensional]
%       specs - (Opcional) Estrutura retornada por config_specs(). Se omitida,
%               carrega config_specs() automaticamente.
%
%   Saidas:
%       res   - Estrutura (struct) contendo:
%           .desvio_pass_max_dB - Maior desvio absoluto |H(f)_dB| em [0, Fpass] [dB]
%           .mag_pass_max_dB    - Maior magnitude em [0, Fpass] [dB]
%           .mag_pass_min_dB    - Menor magnitude em [0, Fpass] [dB]
%           .aten_stop_min_dB   - Atenuacao minima (-max(H(f)_dB)) em [Fstop, Fs/2] [dB]
%           .pico_stop_max_dB   - Maior magnitude em [Fstop, Fs/2] [dB]
%           .ganho_dc_linear    - Soma dos coeficientes H(e^{j0}) = sum(h) [adimensional]
%           .ganho_dc_dB        - Ganho em corrente continua (f = 0 Hz) [dB]
%           .atende_pass        - Logico indicando se desvio_pass_max_dB <= tol_pass_dB
%           .atende_stop        - Logico indicando se aten_stop_min_dB >= aten_stop_dB
%           .atende_mascara     - Logico indicando atendimento simultaneo das duas bandas
%           .f_Hz               - Vetor de frequencias avaliadas em [0, Fs/2] [Hz]
%           .mag_dB             - Vetor de magnitude da resposta em frequencia [dB]
%           .H                  - Vetor complexo da resposta em frequencia [adimensional]
%

if nargin < 2 || isempty(specs)
    specs = config_specs();
end

h = h(:).'; % Garante vetor linha [adimensional]
Nfft = max(specs.Nfft, 16384); % Grade densa de frequencia [pontos]

% Calculo da resposta em frequencia em [0, Fs/2]
[H, f_Hz] = freqz(h, 1, Nfft, specs.Fs); % f_Hz em [Hz], H complexo [adimensional]
mag_abs = abs(H);                         % Magnitude linear [adimensional]
mag_dB  = 20 * log10(max(mag_abs, eps));  % Magnitude em decibeis [dB]

% Mascaras de indices para cada banda
idx_pass = (f_Hz >= 0) & (f_Hz <= specs.Fpass);           % Banda passante [0, 1000 Hz]
idx_stop = (f_Hz >= specs.Fstop) & (f_Hz <= specs.Fs/2);  % Banda de rejeicao [2200, 4000 Hz]

% Metricas na banda passante (desvio em relacao a 0 dB)
res.mag_pass_max_dB    = max(mag_dB(idx_pass));      % Valor maximo na passante [dB]
res.mag_pass_min_dB    = min(mag_dB(idx_pass));      % Valor minimo na passante [dB]
res.desvio_pass_max_dB = max(abs(mag_dB(idx_pass))); % Desvio absoluto maximo em torno de 0 dB [dB]

% Metricas na banda de rejeicao
res.pico_stop_max_dB   = max(mag_dB(idx_stop));      % Pico maximo na banda de rejeicao [dB]
res.aten_stop_min_dB   = min(-mag_dB(idx_stop));     % Atenuacao minima na banda de rejeicao [dB]

% Ganho em corrente continua (DC, f = 0 Hz)
res.ganho_dc_linear    = sum(h);                                  % Ganho DC linear [adimensional]
res.ganho_dc_dB        = 20 * log10(max(abs(res.ganho_dc_linear), eps)); % Ganho DC [dB]

% Verificacao de conformidade com a mascara (com tolerancia numerica de ponto flutuante 1e-12)
tol_num = 1e-12; % Tolerancia numerica para comparacao de ponto flutuante [dB]
res.atende_pass    = (res.desvio_pass_max_dB <= specs.tol_pass_dB + tol_num);
res.atende_stop    = (res.aten_stop_min_dB   >= specs.aten_stop_dB - tol_num);
res.atende_mascara = res.atende_pass && res.atende_stop;

% Vetores completos para plotagem direta
res.f_Hz   = f_Hz;   % Frequencia [Hz]
res.mag_dB = mag_dB; % Magnitude [dB]
res.H      = H;      % Resposta complexa [adimensional]
end
