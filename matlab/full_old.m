% Создание дерева из папок
clear all; close all; clc;
data_folder = '../data';
graphs_folder = 'graphs';
if ~exist(graphs_folder, 'dir')
    mkdir(graphs_folder);
    fprintf('Создана папка: %s\n', graphs_folder);
end
angles_folder = fullfile(graphs_folder, 'angles');
velocities_folder = fullfile(graphs_folder, 'velocities');
comparison_folder = fullfile(graphs_folder, 'comparison');
parameters_folder = fullfile(graphs_folder, 'parameters');
folders = {angles_folder, velocities_folder, comparison_folder, parameters_folder};
for i = 1:length(folders)
    if ~exist(folders{i}, 'dir')
        mkdir(folders{i});
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%TODO начало (как в методички)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

voltages = [-100, -80, -60, -40, -20, 20, 40, 60, 80, 100]; % значения напряжений
n_files = length(voltages);

J = 0.0023;
R = 6.5;    % resistance of windings (source: manufacturer specifications)
k_all = NaN(n_files, 1);
Tm_all = NaN(n_files, 1);
ke_all = NaN(n_files, 1);
km_all = NaN(n_files, 1);

%% Основной цикл обработки файлов
for i = 1:n_files
    U_pr = voltages(i);
        if U_pr < 0
        filename = fullfile(data_folder, sprintf('data%d', U_pr));
    else
        filename = fullfile(data_folder, sprintf('data%d', U_pr));
    end
    try
        data = readmatrix(filename);
        time = data(:, 1);
        angle_deg = data(:, 2);
        omega_deg = data(:, 3);

        angle_rad = angle_deg * pi / 180;
        omega_rad = omega_deg * pi / 180;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %TODO Построение графиков экспериментальных данных%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % График угла поворота
        figure(1);
        subplot(2, 5, i);
        plot(time, angle_deg, 'b-', 'LineWidth', 1.2);
        xlabel('Время, с');
        ylabel('Угол, °');
        title(sprintf('U = %d%%', U_pr));
        grid on;

        % График угловой скорости
        figure(2);
        subplot(2, 5, i);
        plot(time, omega_deg, 'b-', 'LineWidth', 1.2);
        xlabel('Время, с');
        ylabel('Скорость, рад/с');
        title(sprintf('U = %d%%', U_pr));
        grid on;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Аппроксимация по углу поворота%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        par0 = [15, 0.06]; % [k, Tm]
                fun_theta = @(par, t) U_pr * par(1) * (t - par(2) * (1 - exp(-t/par(2))));
                options = optimoptions('lsqcurvefit', 'Display', 'off', ...
                               'MaxFunctionEvaluations', 10000, ...
                               'FunctionTolerance', 1e-10);

        try
            par = lsqcurvefit(fun_theta, par0, time, angle_rad, [], [], options);
            k = par(1);
            Tm = par(2);
            k_all(i) = k;
            Tm_all(i) = Tm;
            U_max = 9.0; % В, нужно для ke а оно нужно для km
            ke = U_max / (100 * k); % В·с/рад
            km = J * R / (Tm * ke); % Н·м/А

            ke_all(i) = ke;
            km_all(i) = km;

            time_apr = linspace(0, max(time), 200);
            theta_apr_rad = fun_theta([k, Tm], time_apr);
            theta_apr_deg = theta_apr_rad * 180 / pi;

            figure(1);
            subplot(2, 5, i);
            hold on;
            plot(time_apr, theta_apr_deg, 'r-', 'LineWidth', 2);
            legend('Эксперимент', 'Аппроксимация', 'Location', 'best');

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Аппроксимация по скорости %%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            figure(2);
            subplot(2, 5, i);
            hold on;
            omega_apr_rad = k * U_pr * (1 - exp(-time_apr/Tm));
            omega_apr_deg = omega_apr_rad * 180 / pi;
            plot(time_apr, omega_apr_deg, 'r-', 'LineWidth', 2);
            legend('Эксперимент', 'Аппроксимация', 'Location', 'best');

            % Вывод результатов для отчёта
            fprintf('U = %d%%: k = %.4f рад/(с·%%), Tm = %.4f с\n', U_pr, k, Tm);
            fprintf('ke = %.4f В·с/рад, km = %.4f Н·м/А\n', ke, km);

        catch ME
            fprintf('  Ошибка аппроксимации для U = %d%%: %s\n', U_pr, ME.message);
            k_all(i) = NaN;
            Tm_all(i) = NaN;
        end

    catch ME
        fprintf('  Ошибка чтения файла %s: %s\n', filename, ME.message);
    end
end


saveas(figure(1), fullfile(graphs_folder, 'all_angles.png'));
saveas(figure(2), fullfile(graphs_folder, 'all_velocities.png'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%TODO Индивидуальные графики для каждого напряжения%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1:n_files
    U_pr = voltages(i);

    if ~isnan(k_all(i)) && ~isnan(Tm_all(i))
        %для угла
        figure(10 + i);
        if U_pr < 0
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
        else
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
        end

        try
            data = readmatrix(filename);
            time = data(:, 1);
            angle_deg = data(:, 2);

            plot(time, angle_deg, 'b-', 'LineWidth', 1.2);
            hold on;

            time_apr = 0:0.01:max(time);
            theta_apr_rad = U_pr * k_all(i) * (time_apr - Tm_all(i) * (1 - exp(-time_apr/Tm_all(i))));
            theta_apr_deg = theta_apr_rad * 180 / pi;
            plot(time_apr, theta_apr_deg, 'r-', 'LineWidth', 2);

            xlabel('Время, с');
            ylabel('Угол поворота, град');
            title(sprintf('U = %d%% , k = %.3f, Tm = %.3f с', U_pr, k_all(i), Tm_all(i)));
            legend('Эксперимент', 'Аппроксимация');
            grid on;

            saveas(gcf, fullfile(angles_folder, sprintf('angle_%d.png', U_pr)));

        catch
            fprintf('  Не удалось построить график для U = %d%%\n', U_pr);
        end
        %для скорости
        figure(20 + i);

        try
            data = readmatrix(filename);
            time = data(:, 1);
            omega_deg = data(:, 3);

            plot(time, omega_deg, 'b-', 'LineWidth', 1.2);
            hold on;

            time_apr = 0:0.01:max(time);
            omega_apr_rad = k_all(i) * U_pr * (1 - exp(-time_apr/Tm_all(i)));
            omega_apr_deg = omega_apr_rad * 180 / pi;
            plot(time_apr, omega_apr_deg, 'r-', 'LineWidth', 2);

            xlabel('Время, с');
            ylabel('Угловая скорость, град/с');
            title(sprintf('U = %d%% , k = %.3f, Tm = %.3f с', U_pr, k_all(i), Tm_all(i)));
            legend('Эксперимент', 'Аппроксимация');
            grid on;

            saveas(gcf, fullfile(velocities_folder, sprintf('velocity_%d.png', U_pr)));

        catch
            fprintf('  Не удалось построить график скорости для U = %d%%\n', U_pr);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%TODO Построение графиков для параметров
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
valid_idx = ~isnan(k_all) & ~isnan(Tm_all);
omega_ust_rad = k_all.* voltages' * 180 / pi; % в град/с

% График установившейся скорости
figure(101);

% Сортируем данные по возрастанию напряжения для корректного соединения линиями
[~, sort_idx] = sort(voltages(valid_idx));
x_sorted = voltages(valid_idx);
y_omega = omega_ust_rad(valid_idx);
y_Tm = Tm_all(valid_idx) * 1000;
y_k = k_all(valid_idx) * 180/pi;

plot(voltages(valid_idx), omega_ust_rad(valid_idx), 'b-o', ...
     'MarkerSize', 8, 'MarkerFaceColor', 'b', 'LineWidth', 1.5);
hold on;

p = polyfit(voltages(valid_idx), omega_ust_rad(valid_idx), 1);
x_fit = [-100, 100];
y_fit = polyval(p, x_fit);
plot(x_fit, y_fit, 'r-', 'LineWidth', 2);

xlabel('Напряжение U, %');
ylabel('Установившаяся скорость \omega_{уст}, град/с');
title('Зависимость установившейся скорости от напряжения');
legend('Эксперимент', sprintf('Линейная аппроксимация: y = %.2fx + %.2f', p(1), p(2)));
grid on;
saveas(gcf, fullfile(parameters_folder, 'omega_steady.png'));

% График Tm
figure(102);
plot(voltages(valid_idx), Tm_all(valid_idx) * 1000, 'r-s', ...
     'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);
xlabel('Напряжение U, %');
ylabel('Постоянная времени T_m, мс');
title('Зависимость постоянной времени от напряжения');
grid on;
saveas(gcf, fullfile(parameters_folder, 'Tm.png'));

% График k
figure(103);
plot(voltages(valid_idx), k_all(valid_idx) * 180/pi, 'g-s', ...
     'MarkerSize', 8, 'MarkerFaceColor', 'g', 'LineWidth', 1.5);
xlabel('Напряжение U, %');
ylabel('k, град/(с·%%)');
title('Зависимость коэффициента k от напряжения');
grid on;
saveas(gcf, fullfile(parameters_folder, 'k.png'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TODO   Запуск Simulink модели с результатами в MAT файлы    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

            % Получаем время моделирования из данных
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename);
            time_exp = data(:, 1);
            t_end = max(time_exp);

            set_param(modelName, 'StopTime', num2str(t_end));

            try
                % Запуск симуляции
                simOut = sim(modelName);
                pause(0.3);
                if ~isfile('omega_data.mat') || ~isfile('theta_data.mat')
                    fprintf('MAT файлы не найдены\n');
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

                if U_pr < 0
                    key = sprintf('U_m%d', abs(U_pr));
                else
                    key = sprintf('U_%d', U_pr);
                end
                sim_results.(key).time = time_sim;
                sim_results.(key).omega = omega_sim;
                sim_results.(key).theta = theta_sim;

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %TODO График из данных+ апроксимация+ моделирование (comparison)
                figure(200 + i);

                subplot(2,1,1);
                plot(time_exp, data(:,2), 'b-', 'LineWidth', 1.2, 'DisplayName', 'Эксперимент');
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
                plot(time_exp, data(:,3), 'b-', 'LineWidth', 1.2, 'DisplayName', 'Эксперимент');
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
    %% TODO сравнение эксперемента и симуляции
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    figure(310);
    colors = lines(n_files);

    for j = 1:n_files
        U_pr = voltages(j);

        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename);
            time_exp = data(:, 1);

            if U_pr < 0
                key = sprintf('U_m%d', abs(U_pr));
            else
                key = sprintf('U_%d', U_pr);
            end
            if isfield(sim_results, key)
                time_sim = sim_results.(key).time;
                theta_sim = sim_results.(key).theta;

                plot(time_exp, data(:,2), '-', 'Color', colors(j,:), 'LineWidth', 1.2);
                hold on;
            end
        end
    end
    % Аппроксимация одним цветом для всех
    for j = 1:n_files
        U_pr = voltages(j);
        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            if U_pr < 0
                key = sprintf('U_m%d', abs(U_pr));
            else
                key = sprintf('U_%d', U_pr);
            end
            if isfield(sim_results, key)
                time_sim = sim_results.(key).time;
                theta_sim = sim_results.(key).theta;
                plot(time_sim, theta_sim * 180/pi, '-k', 'LineWidth', 0.4); hold on;
            end
        end
    end
    % Легенда: эксперимент по напряжениям + одна аппроксимация
    all_labels = arrayfun(@(v) sprintf('U = %d%%', v), voltages, 'UniformOutput', false);
    all_labels{end+1} = 'Аппроксимация';
    legend(all_labels, 'Location', 'best');
    xlabel('Время, с');
    ylabel('Угол, град');
    title('Сравнение эксперимента и Simulink для всех напряжений (угол поворота)');
    grid on;
    saveas(gcf, fullfile(comparison_folder, 'all_angles_comparison.png'));
    close(gcf);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Velocity comparison
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    figure(311);
    colors = lines(n_files);

    for j = 1:n_files
        U_pr = voltages(j);
        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            filename = fullfile(data_folder, sprintf('data%d', U_pr));
            data = readmatrix(filename);
            time_exp = data(:, 1);
            if U_pr < 0
                key = sprintf('U_m%d', abs(U_pr));
            else
                key = sprintf('U_%d', U_pr);
            end
            if isfield(sim_results, key)
                time_sim = sim_results.(key).time;
                omega_sim = sim_results.(key).omega;
                plot(time_exp, data(:,3), '-', 'Color', colors(j,:), 'LineWidth', 1.2);
                hold on;
            end
        end
    end
    % Аппроксимация одним цветом для всех
    for j = 1:n_files
        U_pr = voltages(j);
        if ~isnan(k_all(j)) && ~isnan(Tm_all(j))
            if U_pr < 0
                key = sprintf('U_m%d', abs(U_pr));
            else
                key = sprintf('U_%d', U_pr);
            end
            if isfield(sim_results, key)
                time_sim = sim_results.(key).time;
                omega_sim = sim_results.(key).omega;
                plot(time_sim, omega_sim * 180/pi, '-k', 'LineWidth', 0.7); hold on;
            end
        end
    end
    % Легенда
    all_labels_v = arrayfun(@(v) sprintf('U = %d%%', v), voltages, 'UniformOutput', false);
    all_labels_v{end+1} = 'Аппроксимация';
    legend(all_labels_v, 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(comparison_folder, 'all_velocities_comparison.png'));
    close(gcf);

else
    fprintf('Simulink не доступен, пропускаем моделирование.\n');
end

results = table(voltages', k_all, Tm_all, ke_all, km_all, ...
    'VariableNames', {'Voltage', 'k_rad_per_s_per', 'Tm_s', 'ke_V_s_per_rad', 'km_N_m_per_A'});
writetable(results, fullfile(graphs_folder, 'all_results.csv'));

%% TODO Модель симулинк

function create_motor_sim_model(modelName)
    new_system(modelName);
    open_system(modelName);
    try
        set_param(modelName, 'StopTime', '1.0');
        set_param(modelName, 'Solver', 'ode45');
        add_block('simulink/Sources/Constant', [modelName '/U']);
        set_param([modelName '/U'], 'Value', 'U_sim');
        add_block('simulink/Math Operations/Gain', [modelName '/Gain_k']);
        set_param([modelName '/Gain_k'], 'Gain', 'k_sim');
        add_block('simulink/Math Operations/Sum', [modelName '/Sum']);
        set_param([modelName '/Sum'], 'Inputs', '+-');
        add_block('simulink/Math Operations/Gain', [modelName '/Gain_1Tm']);
        set_param([modelName '/Gain_1Tm'], 'Gain', '1/Tm_sim');
        add_block('simulink/Continuous/Integrator', [modelName '/Integ_omega']);
        set_param([modelName '/Integ_omega'], 'InitialCondition', '0');
        add_block('simulink/Continuous/Integrator', [modelName '/Integ_theta']);
        set_param([modelName '/Integ_theta'], 'InitialCondition', '0');
        add_block('simulink/Sinks/To File', [modelName '/ToFile_omega']);
        set_param([modelName '/ToFile_omega'], 'Filename', 'omega_data.mat');
        set_param([modelName '/ToFile_omega'], 'Decimation', '1');
        add_block('simulink/Sinks/To File', [modelName '/ToFile_theta']);
        set_param([modelName '/ToFile_theta'], 'Filename', 'theta_data.mat');
        set_param([modelName '/ToFile_theta'], 'Decimation', '1');
        add_line(modelName, 'U/1', 'Gain_k/1');
        add_line(modelName, 'Gain_k/1', 'Sum/1');
        add_line(modelName, 'Integ_omega/1', 'Sum/2');
        add_line(modelName, 'Sum/1', 'Gain_1Tm/1');
        add_line(modelName, 'Gain_1Tm/1', 'Integ_omega/1');
        add_line(modelName, 'Integ_omega/1', 'Integ_theta/1');
        add_line(modelName, 'Integ_omega/1', 'ToFile_omega/1');
        add_line(modelName, 'Integ_theta/1', 'ToFile_theta/1');
        save_system(modelName);

    catch ME
        fprintf('ОШИБКА при создании модели: %s\n', ME.message);
        if bdIsLoaded(modelName)
            close_system(modelName, 0);
        end
        rethrow(ME);
    end
end