clear all; close all; clc;
data_folder = '../data';
graphs_folder = 'graphs';
folders = {graphs_folder, fullfile(graphs_folder, 'angles'), fullfile(graphs_folder, 'velocities'), ...
    fullfile(graphs_folder, 'comparison'), fullfile(graphs_folder, 'parameters')};
[angles_folder, velocities_folder, comparison_folder, parameters_folder] = deal(folders{2:5});

voltages = [-100, -80, -60, -40, -20, 20, 40, 60, 80, 100];
n_files = length(voltages);
J = 0.0023; R = 6.5; U_max = 9.0;
[k_all, Tm_all, ke_all, km_all] = deal(NaN(n_files, 1));

%% Main processing loop
fig_angle = figure(1); fig_vel = figure(2);
for i = 1:n_files
    U_pr = voltages(i);
    filename = fullfile(data_folder, sprintf('data%d', U_pr));
    
    try
        data = readmatrix(filename);
        time = data(:, 1);
        angle_deg = data(:, 2);
        omega_deg = data(:, 3);
        angle_rad = angle_deg * pi / 180;
        omega_rad = omega_deg * pi / 180;

        % Subplots для углов и скоростей
        figure(fig_angle); subplot(2, 5, i); plot(time, angle_deg, 'b.', 'MarkerSize', 6);
        xlabel('Время, с'); ylabel('Угол, рад'); title(sprintf('U = %d%%', U_pr)); grid on;
        
        figure(fig_vel); subplot(2, 5, i); plot(time, omega_deg, 'b.', 'MarkerSize', 6);
        xlabel('Время, с'); ylabel('Скорость, рад/с'); title(sprintf('U = %d%%', U_pr)); grid on;

        % Fitting by angle
        fun_theta = @(par, t) U_pr * par(1) * (t - par(2) * (1 - exp(-t/par(2))));
        options = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxFunctionEvaluations', 10000);
        
        try
            par = lsqcurvefit(fun_theta, [15, 0.06], time, angle_rad, [], [], options);
            k = par(1); Tm = par(2);
            k_all(i) = k; Tm_all(i) = Tm;
            ke_all(i) = U_max / (100 * k);
            km_all(i) = J * R / (Tm * ke_all(i));

            time_apr = linspace(0, max(time), 200);
            theta_apr_deg = fun_theta([k, Tm], time_apr) * 180 / pi;
            omega_apr_deg = k * U_pr * (1 - exp(-time_apr/Tm)) * 180 / pi;

            figure(fig_angle); subplot(2, 5, i); hold on; plot(time_apr, theta_apr_deg, 'r-', 'LineWidth', 2);
            legend('Эксперимент', 'Аппроксимация', 'Location', 'best');
            
            figure(fig_vel); subplot(2, 5, i); hold on; plot(time_apr, omega_apr_deg, 'r-', 'LineWidth', 2);
            legend('Эксперимент', 'Аппроксимация', 'Location', 'best');

            fprintf('U = %d%%: k = %.4f, Tm = %.4f с, ke = %.4f, km = %.4f\n', U_pr, k, Tm, ke_all(i), km_all(i));
        catch ME
            fprintf('Ошибка аппроксимации U = %d%%: %s\n', U_pr, ME.message);
        end
    catch ME
        fprintf('Ошибка чтения %s: %s\n', filename, ME.message);
    end
end

saveas(fig_angle, fullfile(graphs_folder, 'all_angles.png'));
saveas(fig_vel, fullfile(graphs_folder, 'all_velocities.png'));

%% Individual plots for each voltage
for i = 1:n_files
    U_pr = voltages(i);
    if ~isnan(k_all(i)) && ~isnan(Tm_all(i))
        filename = fullfile(data_folder, sprintf('data%d', U_pr));
        try
            data = readmatrix(filename);
            time = data(:, 1);
            time_apr = 0:0.01:max(time);
            
            % Angle plot
            figure(10 + i);
            plot(time, data(:, 2), 'b.', 'MarkerSize', 8);
            hold on;
            theta_apr_deg = U_pr * k_all(i) * (time_apr - Tm_all(i) * (1 - exp(-time_apr/Tm_all(i)))) * 180 / pi;
            plot(time_apr, theta_apr_deg, 'r-', 'LineWidth', 2);
            xlabel('Время, с'); ylabel('Угол поворота, град');
            title(sprintf('U = %d%%, k = %.3f, Tm = %.3f с', U_pr, k_all(i), Tm_all(i)));
            legend('Эксперимент', 'Аппроксимация'); grid on;
            saveas(gcf, fullfile(angles_folder, sprintf('angle_%d.png', U_pr)));
            
            % Velocity plot
            figure(20 + i);
            plot(time, data(:, 3), 'b.', 'MarkerSize', 8);
            hold on;
            omega_apr_deg = k_all(i) * U_pr * (1 - exp(-time_apr/Tm_all(i))) * 180 / pi;
            plot(time_apr, omega_apr_deg, 'r-', 'LineWidth', 2);
            xlabel('Время, с'); ylabel('Угловая скорость, град/с');
            title(sprintf('U = %d%%, k = %.3f, Tm = %.3f с', U_pr, k_all(i), Tm_all(i)));
            legend('Эксперимент', 'Аппроксимация'); grid on;
            saveas(gcf, fullfile(velocities_folder, sprintf('velocity_%d.png', U_pr)));
        catch
            fprintf('Ошибка при построении графика для U = %d%%\n', U_pr);
        end
    end
end

%% Parameter plots
valid_idx = ~isnan(k_all) & ~isnan(Tm_all);
omega_ust_rad = k_all .* voltages' * 180 / pi;

plots_data = {{voltages(valid_idx), omega_ust_rad(valid_idx), 'bo', 'Установившаяся скорость \omega_{уст}, град/с', 'omega_steady.png', true}, ...
              {voltages(valid_idx), Tm_all(valid_idx) * 1000, 'rs', 'Постоянная времени T_m, мс', 'Tm.png', false}, ...
              {voltages(valid_idx), k_all(valid_idx) * 180/pi, 'gs', 'k, град/(с·%%)', 'k.png', false}};

for p = 1:3
    figure(100 + p);
    plot(plots_data{p}{1}, plots_data{p}{2}, plots_data{p}{3}, 'MarkerSize', 10, 'MarkerFaceColor', plots_data{p}{3}(1));
    xlabel('Напряжение U, %'); ylabel(plots_data{p}{4});
    grid on;
    if plots_data{p}{6}
        hold on; pp = polyfit(plots_data{p}{1}, plots_data{p}{2}, 1);
        plot([-100, 100], polyval(pp, [-100, 100]), 'r-', 'LineWidth', 2);
        legend('Эксперимент', sprintf('y = %.2fx + %.2f', pp(1), pp(2)));
    end
    saveas(gcf, fullfile(parameters_folder, plots_data{p}{5}));
end

%% Simulink simulation
if license('test', 'Simulink')
    modelName = 'temp_motor_model';
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    if isfile([modelName '.slx'])
        delete([modelName '.slx']);
    end
    create_motor_sim_model(modelName);
    sim_results = struct();
    for i = 1:n_files
        U_pr = voltages(i);
        if ~isnan(k_all(i)) && ~isnan(Tm_all(i))
            k_sim = k_all(i);
            Tm_sim = Tm_all(i);
            U_sim = U_pr;

            % Get simulation time from data
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename);
            time_exp = data(:, 1);
            t_end = max(time_exp);

            set_param(modelName, 'StopTime', num2str(t_end));

            try
                % Run simulation
                simOut = sim(modelName);
                pause(0.3);
                if ~isfile('omega_data.mat') || ~isfile('theta_data.mat')
                    fprintf('MAT files not found\n');
                    continue;
                end
                omega_mat = load('omega_data.mat');
                theta_mat = load('theta_data.mat');
                omega_fields = fieldnames(omega_mat);
                omega_var = omega_mat.(omega_fields{1});
                theta_fields = fieldnames(theta_mat);
                theta_var = theta_mat.(theta_fields{1});
                time_sim = omega_var.Time(:);
                omega_sim = omega_var.Data(:);
                theta_sim = theta_var.Data(:);

                key = sprintf('U_%d', U_pr);
                sim_results.(key).time = time_sim;
                sim_results.(key).omega = omega_sim;
                sim_results.(key).theta = theta_sim;
                
                %%%%% Individual comparison figure
                figure(200 + i);
                
                subplot(2,1,1);
                plot(time_exp, data(:,2), 'b.', 'MarkerSize', 6, 'DisplayName', 'Эксперимент');
                hold on;
                plot(time_sim, theta_sim * 180/pi, 'r-', 'LineWidth', 2, 'DisplayName', 'Simulink');
                
                time_apr = linspace(0, t_end, 200);
                theta_apr_rad = U_pr * k_sim * (time_apr - Tm_sim * (1 - exp(-time_apr/Tm_sim)));
                theta_apr_deg = theta_apr_rad * 180 / pi;
                plot(time_apr, theta_apr_deg, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Аппроксимация');
                
                xlabel('Время, с');
                ylabel('Угол, град');
                title(sprintf('Сравнение для U = %d%% (Угол поворота)', U_pr));
                legend('Location', 'best');
                grid on;
                
                subplot(2,1,2);
                plot(time_exp, data(:,3), 'b.', 'MarkerSize', 6, 'DisplayName', 'Эксперимент');
                hold on;
                plot(time_sim, omega_sim * 180/pi, 'r-', 'LineWidth', 2, 'DisplayName', 'Simulink');
                plot(time_apr, k_sim * U_pr * (1 - exp(-time_apr/Tm_sim)) * 180/pi, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Аппроксимация');
                
                xlabel('Время, с');
                ylabel('Скорость, град/с');
                title(sprintf('Сравнение для U = %d%% (Угловая скорость)', U_pr));
                legend('Location', 'best');
                grid on;
                
                saveas(gcf, fullfile(comparison_folder, sprintf('comparison_%d.png', U_pr)));
                close(gcf);
                
                if isfile('omega_data.mat')
                    delete('omega_data.mat');
                end
                if isfile('theta_data.mat')
                    delete('theta_data.mat');
                end
                
            catch ME
                fprintf('Ошибка при симуляции: %s\n', ME.message);
            end
        end
    end
    
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
    %% TODO сравнение жксперемента и симуляции
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    figure(310);
    colors = lines(n_files);
    for j = 1:n_files
        U_pr = voltages(j);
        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename); time_exp = data(:, 1);
            key = sprintf('U_%d', U_pr);
            if isfield(sim_results, key)
                time_sim = sim_results.(key).time;
                plot(time_exp, data(:,2), '.', 'Color', colors(j,:), 'MarkerSize', 4);
                hold on;
                plot(time_sim, sim_results.(key).theta * 180/pi, '-', 'Color', colors(j,:), 'LineWidth', 1.5, ...
                     'DisplayName', sprintf('U = %d%%', U_pr));
            end
        end
    end
    xlabel('Время, с'); ylabel('Угол, град');
    title('Сравнение эксперимента и Simulink (угол)'); legend('Location', 'best'); grid on;
    saveas(gcf, fullfile(comparison_folder, 'all_angles_comparison.png')); close(gcf);
    
    figure(311);
    for j = 1:n_files
        U_pr = voltages(j);
        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename); time_exp = data(:, 1);
            key = sprintf('U_%d', U_pr);
            if isfield(sim_results, key)
                plot(time_exp, data(:,3), '.', 'Color', colors(j,:), 'MarkerSize', 4);
                hold on;
                plot(sim_results.(key).time, sim_results.(key).omega * 180/pi, '-', 'Color', colors(j,:), 'LineWidth', 1.5, ...
                     'DisplayName', sprintf('U = %d%%', U_pr));
            end
        end
    end
    xlabel('Время, с'); ylabel('Скорость, град/с');
    title('Сравнение эксперимента и Simulink (скорость)'); legend('Location', 'best'); grid on;
    saveas(gcf, fullfile(comparison_folder, 'all_velocities_comparison.png')); close(gcf);
    
else
    fprintf('Simulink не доступен, пропускаем моделирование.\n');
end

results = table(voltages', k_all, Tm_all, ke_all, km_all, ...
    'VariableNames', {'Voltage', 'k_rad_per_s_per', 'Tm_s', 'ke_V_s_per_rad', 'km_N_m_per_A'});
writetable(results, fullfile(graphs_folder, 'all_results.csv'));

function create_motor_sim_model(modelName)
    new_system(modelName);
    open_system(modelName);
    set_param(modelName, 'StopTime', '1.0', 'Solver', 'ode45');
    
    blocks = {'U', 'Gain_k', 'Sum', 'Gain_1Tm', 'Integ_omega', 'Integ_theta', 'ToFile_omega', 'ToFile_theta'};
    block_types = {'simulink/Sources/Constant', 'simulink/Math Operations/Gain', 'simulink/Math Operations/Sum', ...
                   'simulink/Math Operations/Gain', 'simulink/Continuous/Integrator', 'simulink/Continuous/Integrator', ...
                   'simulink/Sinks/To File', 'simulink/Sinks/To File'};
    params = {{}, {'Gain', 'k_sim'}, {'Inputs', '+-'}, {'Gain', '1/Tm_sim'}, ...
              {'InitialCondition', '0'}, {'InitialCondition', '0'}, ...
              {'Filename', 'omega_data.mat', 'Decimation', '1'}, ...
              {'Filename', 'theta_data.mat', 'Decimation', '1'}};
    
    for i = 1:length(blocks)
        add_block(block_types{i}, [modelName '/' blocks{i}]);
        for j = 1:2:length(params{i})
            set_param([modelName '/' blocks{i}], params{i}{j}, params{i}{j+1});
        end
    end
    
    add_line(modelName, 'U/1', 'Gain_k/1'); add_line(modelName, 'Gain_k/1', 'Sum/1');
    add_line(modelName, 'Integ_omega/1', 'Sum/2'); add_line(modelName, 'Sum/1', 'Gain_1Tm/1');
    add_line(modelName, 'Gain_1Tm/1', 'Integ_omega/1'); add_line(modelName, 'Integ_omega/1', 'Integ_theta/1');
    add_line(modelName, 'Integ_omega/1', 'ToFile_omega/1'); add_line(modelName, 'Integ_theta/1', 'ToFile_theta/1');
    save_system(modelName);
end