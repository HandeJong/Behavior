function [ locomotor_trace, distance_moved, delta_distance ] = biobserve_import( varargin )
% Imports raw X and Y coordinates form .csv files (raw data output
% Biobserve) and produces a matrix with all x coordinates in the first and
% all y coordinates in the second collumn. The timeline (s) is in the thrird
% collumn.
%
%   Inputs:
%       input_file          - char refering to .csv file
%       
%   Output:
%       locomotor_trace     - x and y coordinates as well as timestamps
%       distance_moved      - distance moved (corrected) in #pxl
%       delta_distance      - series of delta's between each time point
%
%   Options:
%       'player'           - will open dialog box with trace
%       'movie'            - will search for a movie file with the same
%                            name and play that one as well.
%       'movement_corr'    - Manual movement correction (int pxl). Default
%                            is 3.1pxl.
%       'remove_errors'    - Will now attempt to remove tracking errors
%       'missing frames'   - Will NOT correct for missing frames
%
%   Example:
%   >> [trace, dist] = biobserve_import('filename','movement_corr',5); 
%   This will import the trace and apply a m. correction of 5 pixels.
%
%   NOTE: Video and image data are usually displayed on an inverse y-axis.
%   Thus, to plot the trace in the same orientation as it the video file
%   inverte the y axis as follows:
%   >> plot(locomotor_trace(:,1), locomotor_trace(:,2));
%   >> ax = gca; ax.YDir = 'reverse';


% Options struct
options.player = false; % no real-time presentation
options.movie = false; % no movie
options.movement_correction = 3.1; %pxl
options.remove_errors = false; % will not remove tracking errors
options.missing_frames = true; % will automatically correct for missing frames

% Deal with input arguments
input_file=varargin{1};
options.filename=input_file;
skipp=false;
for i=2:nargin
    if skipp
        skipp = ~skipp;
        continue
    end
    
    switch varargin{i}
        case 'player'
            options.player = true;
        case 'movement_corr'
            disp(['Manual movement correction ' num2str(varargin{i+1}) 'pxl'])
            options.movement_correction = varargin{i+1};
            skipp=true;
        case 'movie'
            options.player = true;
            options.movie = true;
        case 'remove_errors'
            options.remove_errors = true;
            warning('Remove errors not yet implemented.')
        case 'missing frames'
            options.missing_frames = false;
        otherwise
            if ischar(varargin{i})
                warning(['Input ' varargin{i} ' not recognized.'])
            else
                warning(['Input #' num2str(i) ' is not a valid option.'])
            end
    end  
end


%just to figure out the length of the files
if exist(input_file,'file')~=2
    disp('Unable to locate file')
    [filename, path]=uigetfile({'*.csv'},'select file','MultiSelect','off');
    input_file=[path filename];
end

% if the input file is a .csv file
if strcmp(input_file(end-3:end), '.csv')
    input_file=fopen(input_file);
    data=textscan(input_file,'%f32%s%s%f32%f32%f32%f32%f32%f32','Delimiter',',','HeaderLines',1);
    fclose(input_file);
    
    % Convert the time
    times=datenum(data{1,3},'HH:MM:SS PM');
    
elseif strcmp(input_file(end-3:end), '.xls')
    temp = xlsread(input_file);
    for i=1:9
        data{1,i} = temp(:,i);
    end
    
    % Convert the time
    times = data{3};

else
    error(['Unknown filetype: ' input_file ' please input a .csv or .xls file exported by Biobserve.'])
end


%see if we can find a movie file with the same name
if options.movie
    name_video=[options.filename(1:end-3) 'mp4'];
    if exist(name_video,'file')
        disp('Importing associated movie file')
        video=VideoReader(name_video);    
    else
        disp(['Unable to locate ' name_video  ' with the same file name.'])
        options.movie=false;
    end
end

% Grabbing the correct timestring
times = (times-times(1))*86400; %number of seconds in a day

% Grabbing the locomotor data
locomotor_trace(:,1) = cell2mat(data(1,6)); % x of body
locomotor_trace(:,2) = cell2mat(data(1,7)); % y of body

% Time trace
locomotor_trace(:,3) = times;

% Are we correcting for missing frames?
if options.missing_frames
    % Find out the (attempted) sampling rate
    real_speed=length(times)/times(end-1);
    rate=ceil(real_speed); %ceil, because round might go down if there are A LOT of missing datapoints.
    missing=((rate-real_speed)/rate)*100;
    disp(['Biobserve attempted to sample at ', num2str(rate), 'Hz']);
    disp(['Missing data points: ', num2str(missing), '%']);
else
    rate = length(times)/times(end-1);
    disp(['Biobserve sampled at ', num2str(rate), 'Hz']);
    disp('Not corrected for missing frames.')
end

% Calculate and siplay the interval
interval = 1/rate;
disp(['The interval is ' num2str(interval) 's'])

% Test the amounth of zeros and make it rate
number_of_zeros=sum(locomotor_trace(:,3)==0);
if number_of_zeros<round(rate)
    locomotor_trace(:,3)=[zeros(round(rate)-number_of_zeros,1) 
        locomotor_trace(1:length(locomotor_trace)-round(rate)+number_of_zeros,3)];
end

b=0;
for a = 1:length(locomotor_trace(:,3))-1
    if locomotor_trace(a,3)==locomotor_trace(a+1,3)
        locomotor_trace(a,3) = locomotor_trace(a,3)+b*interval;
        b = b+1;
    else
        locomotor_trace(a,3) = locomotor_trace(a,3)+(1-interval);
        b = 0;
    end
end
locomotor_trace(end,3) = locomotor_trace(end-1,3)+interval;


% Calculate distance moved
movement = locomotor_trace(1:end-1,1:2)-locomotor_trace(2:end,1:2);
dists = sqrt(movement(:,1).^2+movement(:,2).^2);
delta_distance = dists;
delta_distance(dists<options.movement_correction) = 0;
distance_moved = sum(delta_distance);


% Play locomotor trace if requested
if options.movie
    player(locomotor_trace, video)
elseif options.player
    player(locomotor_trace)
end

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Sub functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function player(locomotor_trace, video)
    % Presents the locomotor trace playback
    trace_figure=figure;
    trace_figure.KeyPressFcn=@key_press;

    % If a video is suplied, play that one as well.
    if nargin>1
        projection=image(readFrame(video));
        locomotor_trace(:,2)=locomotor_trace(:,2)*-1; % Working with reveresed y axis
        hold on
        ax = gca; ax.YDir = 'reverse';
        data.projection=projection; % For access by the key_press function
        data.video=video;
    end
    
    % Initial drawing of trace
    presented_trace=plot(locomotor_trace(1,1), locomotor_trace(1,2));
    axis equal
    ylim([min(locomotor_trace(:,2)), max(locomotor_trace(:,2))]);
    xlim([min(locomotor_trace(:,1)), max(locomotor_trace(:,1))]);
    hold on
    xlabel('px')
    ylabel('px')
    disp('Press space to start, use +/- to change  playback speed');
    
    % A small rectangle representing the  mouse itself
    mouse_size=10; % adjust here
    mouse=rectangle('Position',...
        [locomotor_trace(1,1)-0.5*mouse_size,...
         locomotor_trace(1,2)-0.5*mouse_size,...
         mouse_size, mouse_size],...
         'FaceColor',[1 0.5 0]);
    
    % Struct for key press control
    data.trace=locomotor_trace;
    data.playing=false;
    data.speed=1;
    data.c_time=0;
    data.t_correction=0;
    data.plot_handle=presented_trace;
    data.mouse_handle=mouse;

    % Store data in figure
    trace_figure.UserData=data;
end


function key_press(scr, ev)
    % Key press callback
    
    
    % Get data
    data=scr.UserData;
    locomotor_trace=data.trace;
    
    
    % Deal with input keystrokes
    switch ev.Character
        
        case ' ' % play/pause
            if ~data.playing
                scr.UserData.playing=true;
                scr.UserData.start_time=tic;
                try
                    while scr.UserData.c_time<=locomotor_trace(end,3) && scr.UserData.playing
                        scr.UserData.c_time=toc(scr.UserData.start_time)*scr.UserData.speed+scr.UserData.t_correction;
                        [~, index]=min(abs(locomotor_trace(:,3)-scr.UserData.c_time));
                        
                        % Plot trace
                        scr.UserData.plot_handle.XData=locomotor_trace(1:index,1);
                        scr.UserData.plot_handle.YData=locomotor_trace(1:index,2);
                        
                        % Plot mouse
                        scr.UserData.mouse_handle.Position(1)=locomotor_trace(index,1);
                        scr.UserData.mouse_handle.Position(2)=locomotor_trace(index,2);
                        
                        drawnow();
                    end
                catch
                    disp('Playback ended by user.');
                end
            else
                scr.UserData.t_correction=scr.UserData.c_time;
                scr.UserData.playing=false;
            end
            
        case '+'
            scr.UserData.speed=scr.UserData.speed*2;
            scr.UserData.t_correction=scr.UserData.c_time;
            scr.UserData.start_time=tic;
            
        case '-'
            scr.UserData.speed=scr.UserData.speed/2;
            scr.UserData.t_correction=scr.UserData.c_time;
            scr.UserData.start_time=tic;
        
        otherwise
            disp('Key not recognized. use space to pause and +/- to speed up/down');
    end
    
end

