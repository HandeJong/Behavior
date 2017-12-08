function [ locomotor_trace, distance_moved ] = biobserve_import( varargin )
% Imports raw X and Y coordinates form .csv files (raw data output
% Biobserve) and produces a matrix with all x coordinates in the first and
% all y co?rdinates in the second collumn. The timeline (s) is in the thrird
% collumn.
%
%   Inputs:
%       input_file          - char refering to .csv file on path
%       
%   Output:
%       locomotor_trace     - x and y coordinates as well as time
%       distance_moved      - distance moved (corrected) in #pxl
%
%   Options:
%       'player'           - will open dialog box with trace    <- not finished yet
%       'movement_corr'    - Manual movement correction (int pxl)
%
%
%   Example:
%   >> [trace, dist]=biobserve_import('movement_corr',5); 
%   This will import the trace and apply a m correction of 5 pixels.


% Options struct
options.player=false;
options.movement_correction=3.1; %pxl

% Deal with input arguments
input_file=varargin{1};
skipp=false;
for i=2:nargin
    if skipp
        skipp = ~skipp;
        continue
    end
    
    switch varargin{i}
        case 'player'
            options.player=true;
        case 'movement_corr'
            disp(['Manual movement correction ' num2str(varargin{i+1}) 'pxl'])
            options.movement_correction=varargin{i+1};
            skipp=true;
        otherwise
            if ischar(varargin{i})
                warning(['Input ' varargin{i} ' not recognized.'])
            else
                warning(['Input #' num2str(i) ' is not a valid option.'])
            end
    end  
end


%just to figure out the length of the files
if ~isfile(input_file)
    disp('Unable to locate file')
    [filename, path]=uigetfile({'*.csv'},'select file','MultiSelect','off');
    input_file=[path filename];
end
input_file=fopen(input_file);
data=textscan(input_file,'%f32%s%s%f32%f32%f32%f32%f32%f32','Delimiter',',','HeaderLines',1);
fclose(input_file);


%getting the correct timestring
times=datenum(data{1,3},'HH:MM:SS PM');
times=(times-times(1))*86400; %number of seconds in a day
locomotor_trace(:,1)=cell2mat(data(1,6)); % x of body
locomotor_trace(:,2)=cell2mat(data(1,7)); % y of body
locomotor_trace(:,2)=locomotor_trace(:,2)*-1; % Because Bioobserve sticks to reversed Y-axis for image projection.


% Time trace
locomotor_trace(:,3)=times;


% Find out the (attempted) sampling rate
real_speed=length(times)/times(end-1);
rate=ceil(real_speed); %ceil, because round might go down if there are A LOT of missing datapoints.
interval=1/rate;
missing=((rate-real_speed)/rate)*100;


% Ouput rate and interval
disp(['Biobserve attempted to sample at ', num2str(rate), 'Hz']);
disp(['Missing data points: ', num2str(missing), '%']);


% Test the amounth of zeros and make it rate
number_of_zeros=sum(locomotor_trace(:,3)==0);
locomotor_trace(:,3)=[zeros(rate-number_of_zeros,1) 
    locomotor_trace(1:length(locomotor_trace)-rate+number_of_zeros,3)];

b=0;
for a=1:length(locomotor_trace(:,3))-1
    if locomotor_trace(a,3)==locomotor_trace(a+1,3)
        locomotor_trace(a,3)=locomotor_trace(a,3)+b*interval;
        b=b+1;
    else
        locomotor_trace(a,3)=locomotor_trace(a,3)+(1-interval);
        b=0;
    end
end
locomotor_trace(end,3)=locomotor_trace(end-1,3)+interval;


% Calculate distance moved
movement=locomotor_trace(1:end-1,1:2)-locomotor_trace(2:end,1:2);
dists=sqrt(movement(:,1).^2+movement(:,2).^2);
distance_moved=sum(dists(dists>options.movement_correction));


% Play locomotor trace if requested
if options.player
    player(locomotor_trace)
end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Sub functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function player(locomotor_trace)
    % Presents the locomotor trace playbac
    trace_figure=figure;
    trace_figure.KeyPressFcn=@key_press;

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

