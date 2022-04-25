function [f_n_table] = Natural_frequencies(machine_params, m)
%Estimate the natural frequencies for the stator
%   Gives the natural frequencies for the stator core and
%   the stator-frame system for modes r. Based on Gieras Ch5

s = machine_params.s;                           % Number of slots
h_c = machine_params.w_bi;                      % Stator thickness, assumed to be the yoke thickness
D_c = 2*machine_params.R_so - h_c;              % Mean diameter                    
rho_c = machine_params.rho_c;                   % Core density
k_i = machine_params.k_i;                       % Stacking factor
L_i = machine_params.L;                         % Length
h_sl = machine_params.d_s;                      % Slot depth
w_th = machine_params.w_th;                     % Tooth width
E_c = machine_params.E_plane;                   % Young's modulus
nu_c = machine_params.nu_plane;                 % Poisson ratio
w_s = 2*pi/s * machine_params.R_si - w_th;      % Slot width

kappa2 = h_c^2 / (3 * D_c^2);                   % Nondimensional thickness

% Frame parameters
D_f = machine_params.D_f;                       % Frame outer diameter
L_f = machine_params.L_f;                       % Frame length
h_f = machine_params.h_f;                       % Frame thickness
rho_f = machine_params.rho_f;                   % Frame density
E_f = machine_params.E_f;                       % Frame Young's modulus
nu_f = machine_params.nu_f;                     % Frame Poisson ratio
R_f = 0.5 * (D_f - h_f);                        % Mean frame radius

% Winding parameters
rho_w = machine_params.rho_w;                   % Winding density

% Considered spatial orders
% Radial: 0,1,2... until lowest force order, then multiples of lowest order
% Axial: 1,2,3 
RadialOrder = repmat([0:m(2)-1 m(2:end)], 1, 3);
AxialOrder = [ones(1, length(RadialOrder)/3), ...
    2*ones(1, length(RadialOrder)/3), 3*ones(1, length(RadialOrder)/3)];



% Calculate masses of different components
M_c = pi*D_c*h_c*L_i * rho_c * k_i;             % Stator core mass 
M_t = s * h_sl * w_th * L_i * rho_c * k_i;      % Teeth mass
M_w = (s * w_s * h_sl * L_i + ...
    (w_s + w_th) * D_c * pi * h_sl)* rho_w;     % Winding mass (slot + overhang)
M_f = pi*2*R_f*h_f*L_f * rho_f;                 % Frame mass

% Calculate mass addition factors
k_md = 1 + M_t/M_c;                             % For displacement, teeth

M_0 = M_c * k_md;

% Calculate stiffnesses
% Eq. (5.25) for core
K_mc = 4 * DonnellMushtari2(kappa2, RadialOrder).^2 / D_c * pi * L_i * h_c * E_c / (1-nu_c^2);

% Hoppe's method
%K_mc = 16/12 * pi * E_c * h_c^3 * L_i / D_c^3 * ...
%    RadialOrder.^2 .* (RadialOrder.^2 - 1).^2 ./ (RadialOrder.^2 + 1);

% Eq. (5.34) for frame
K_mn = 2 * DonnellMushtari3(RadialOrder, AxialOrder, nu_f, R_f, L_f, h_f)/R_f * ...
    pi*L_f*h_f*E_f ./ (1-nu_f^2);

% Calculate natural frequencies of core, frame and system
f_m_c = 1/(2*pi) * sqrt(K_mc / M_0);
f_mn_f = 1/(2*pi) * sqrt(K_mn / M_f);
f_mn_s = 1/(2*pi) * sqrt((K_mc + K_mn)/(M_0 + M_f + M_w));

% Create table with output
f_n_table = table(f_m_c.', f_mn_f.', f_mn_s.', ...
    'VariableNames', {'Stator Core', 'Frame', 'Assembly'}, ...
    'RowNames', "(" + string(RadialOrder.') + "," + string(AxialOrder.') + ")");

f_n_table.Properties.Description = 'Natural frequencies for mode (m,n) in Hz';
end

function Omega_m = DonnellMushtari2(kappa2, m)
    % Roots of the second order characteristic equation
    
Omega_m = 0.5 * sqrt((1 + m.^2 + kappa2*m.^4) - ...
    sqrt((1 + m.^2 + kappa2 * m.^4).^2 - 4 * kappa2 * m.^6));

Omega_m(m == 0) = 1;
end

function Omega_mn2 = DonnellMushtari3(m, n, nu_f, R_f, L_f, h_f)
    % Roots of the third order characteristic equation
    % for clamped-clammped frame

L0 = L_f * 0.3 ./ (n + 0.3);
lambda = n * pi * R_f./(L_f-L0);
kappa2_f = h_f^2 / (12 * R_f^2);                % Nondimensional frame thickness

% Calculate constants
C0 = 0.5 * (1 - nu_f) * ((1 - nu_f^2)*lambda.^4 + kappa2_f * (m.^2 + lambda.^2).^4);
C1 = 0.5 * (1 - nu_f) * ((3 + 2*nu_f)*lambda.^2 + m.^2 + ...
    (m.^2 + lambda.^2).^2 + (3-nu_f)./(1-nu_f) .* kappa2_f .* (m.^2 + lambda.^2).^2);
C2 = 1 + 0.5 * (3-nu_f) * (m.^2 + lambda.^2) + kappa2_f * (m.^2 + lambda.^2).^2;

% Initialize Omega_mn2 vector and calculate the roots of the polynomial
Omega_mn2 = zeros(1, length(m));

for k=1:length(m)
    roots_all = roots([1, -C2(k), C1(k), -C0(k)]);
    is_real = roots_all == real(roots_all);     % Select real values
    Omega_mn2(k) = min(roots_all(is_real));     % Select smallest value
end

end

