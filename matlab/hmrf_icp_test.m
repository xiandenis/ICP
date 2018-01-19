function [results] = hmrf_icp_test(data, angles)

switch nargin
case 0
  angles = [pi/30];
  data = 'shark';
case 1
  angles = [pi/30];
case 2
otherwise
  error('Too many arguments');
end

global cloudLoc;
axes = [0.7295   -0.4166    0.5425
        0.8532   -0.5095    0.1116
        0.6788   -0.2187   -0.7010
       -0.2478    0.7270    0.6404
       -0.7575    0.2070    0.6191
        0.9449    0.3079   -0.1111
       -0.5756   -0.3254    0.7502
        0.0405    0.9310    0.3629
        0.8946   -0.3116    0.3203
        0.5176    0.4179    0.7466
        0.8120   -0.4022   -0.4230
        0.0548   -0.8942    0.4442
       -0.6707   -0.6396    0.3755
       -0.8057    0.5299   -0.2645
       -0.9671   -0.1616    0.1965
        0.8934   -0.0745   -0.4431];

fprintf('Loading clouds and poses\n')
switch data
case 'shark'
  load_shark_data;
  load_shark_poses;
case 'desk'
  load_desk_data;
  load_desk_poses;
end
load(['../data/selected_' data '_frames.mat']);

params = icp_params;
params.h = 240;
params.w = 320;
params.debug = 1;
params.icp_iter_max = 50;
params.em_iter_max_start = 600;
params.em_iter_max = 20;
params.verbose = false;

results.params = {};
results.all = {};
results.pct = {};
results.sigma = {};
results.x84 = {};
results.dynamic = {};
results.hmrf = {};
results.goicp = {};

for angle_i=1:length(angles)
  angle = angles(angle_i);
  for frame_pair_i=1:length(selected)
    axis_i = randi(length(axes));
    axis = axes(axis_i, :)';
    t_init = eye(4);
    t_init(1:3,1:3) = aa2mat(axis, angle);
    params.t_init = t_init;

    ol = selected(frame_pair_i, 1);
    ref_frame = selected(frame_pair_i, 2);
    src_frame = selected(frame_pair_i, 3);

    c1 = downsample(unproject(getcloud(ref_frame)), 640, 480, 2);
    origin = mean(c1, 'omitnan');
    origin(4) = 0;
    c1 = c1 - origin;
    c2 = downsample(unproject(getcloud(src_frame)), 640, 480, 2);
    true_tf = inv(pmats{ref_frame})*pmats{src_frame};
    c2_t = (true_tf*c2')' - origin;
    ol = calculate_overlap(c1, c2_t);

    fprintf('%4d %4d %8.5f %8.5f %3d\n', ref_frame, src_frame, ol, angle, axis_i);

    results.params{angle_i, frame_pair_i} = ...
        [ref_frame, src_frame, ol, angle, axis_i];
    for mode = {'all' 'pct' 'sigma' 'x84' 'dynamic' 'goicp'}
      m = mode{1};
      params.mode = m;
      if strcmp(m, 'goicp')
        [tf elapsed] = goicp(c1, c2_t);
      else
        tic;
        [tf iters] = icp(c1, c2_t, params);
        elapsed = toc;
      end
      tf_log = se3log(tf);
      results.(m){angle_i, frame_pair_i} = [iters, elapsed, norm(tf_log(1:3)), norm(tf_log(4:6))];
    end
    try
      tic;
      [tf data] = hmrf_icp(c1, c2_t, params);
      elapsed = toc;
      tf_log = se3log(tf);
      results.hmrf{angle_i, frame_pair_i} = [data.icp_iters, ...
        elapsed, norm(tf_log(1:3)), norm(tf_log(4:6)), data.em_iters];
    catch ae
      results.hmrf{angle_i, frame_pair_i} = nan;
    end
  end
end
end
