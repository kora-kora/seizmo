function [results]=cmb_outliers(results)
%CMB_OUTLIERS    Outlier analysis of core-diffracted data
%
%    Usage:    results=cmb_outliers(results)
%
%    Description:
%     RESULTS=CMB_OUTLIERS(RESULTS) presents the user with a series of
%     menus and plots for clustering data and for removing outliers from
%     the RESULTS struct generated by either CMB_1ST_PASS or CMB_2ND_PASS.
%     The returned struct is similar to the input one, except there are a
%     few more fields: .USERCLUSTER, .CLUSTER, .OUTLIERS, and
%     .ADJUSTCLUSTERS.  Also plots and info are saved during the analysis
%     by the user.
%
%    Notes:
%     - Although you can adjust the ground units of the data, this does not
%       alter the arr, pol, amp measurements from the 1stPass.  Thus
%       redoing the 1stPass is likely necessary for records that have had
%       their ground units changed.  You can timeshift & polarity flip
%       those records to get around this if you do not care about the
%       1stPass meausurements.
%
%    Examples:
%
%    See also: PREP_CMB_DATA, CMB_1ST_PASS, CMB_2ND_PASS, SLOWDECAYPAIRS,
%              SLOWDECAYPROFILES, MAP_CMB_PROFILES

%     Version History:
%        Dec. 12, 2010 - added docs
%        Jan.  6, 2011 - catch empty axis handle breakage
%        Jan. 13, 2011 - output ground units in .adjustclusters field
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Jan. 13, 2011 at 13:35 GMT

% todo:
% - save adjustclusters axes (when it exports them)

% check nargin
error(nargchk(1,1,nargin));

% check results
reqfields={'useralign' 'filter' 'usersnr' 'tt_start' ...
    'corrections' 'phase' 'runname' 'dirname'};
if(~isstruct(results) || any(~isfield(results,reqfields)))
    error('seizmo:cmb_outliers:badInput',...
        ['RESULTS must be a struct with the fields:\n' ...
        sprintf('''%s'' ',reqfields{:}) '!']);
end

% loop over each event
for i=1:numel(results)
    % display name
    disp(results(i).runname);
    
    % abandon events we skipped
    if(isempty(results(i).useralign))
        continue;
    end
    
    % cluster analysis
    [results(i).usercluster,ax]=usercluster(results(i).useralign.data,...
        results(i).useralign.xc.cg(:,:,1),...
        [],[],[],[],'normstyle','single');
    if(any(ishandle(ax)))
        fh=unique(cell2mat(get(ax(ishandle(ax)),'parent')));
        for j=1:numel(fh)
            saveas(fh(j),[results(i).runname '_usercluster_' num2str(j) '.fig']);
            close(fh(j));
        end
    end
    
    % advanced clustering
    [results(i).useralign.data,results(i).usercluster,...
        results(i).useralign.solution.arr,...
        results(i).useralign.solution.pol,...
        results(i).adjustclusters.units]=adjustclusters(...
        results(i).useralign.data,results(i).usercluster,...
        results(i).useralign.solution.arr,...
        results(i).useralign.solution.pol);
    
    % loop over good clusters
    results(i).outliers=true(size(results(i).useralign.solution.arr));
    dd=getheader(results(i).useralign.data,'gcarc');
    arr=results(i).useralign.solution.arr;
    carr=arr-results(i).corrections.ellcor...
        -results(i).corrections.crucor.prem...
        -results(i).corrections.mancor.hmsl06p.upswing;
    arrerr=results(i).useralign.solution.arrerr;
    amp=results(i).useralign.solution.amp;
    camp=amp./results(i).corrections.geomsprcor;
    amperr=results(i).useralign.solution.amperr;
    for j=find(results(i).usercluster.good(:)')
        sj=num2str(j);
        % loop until user is happy overall with this cluster
        happyoverall=false;
        while(~happyoverall)
            % get cluster info
            good=find(results(i).usercluster.T==j);
            pop=numel(good);
            
            % preallocate struct
            results(i).cluster(j).arrcut=struct('bad',[],'cutoff',[]);
            results(i).cluster(j).errcut=struct('bad',[],'cutoff',[]);
            results(i).cluster(j).ampcut=struct('bad',[],'cutoff',[]);

            % loop until happy with arrivals
            happy=false; cnt=0;
            while(~happy && pop>2)
                choice=menu(['Cut relative arrival outliers for cluster ' sj '?'],'Yes','No');
                switch choice
                    case 1 % YES
                        cnt=cnt+1;
                        [bad,cutoff,ax]=arrcut(dd(good),carr(good),[],1,arrerr(good));
                        good(bad)=[];
                        pop=numel(good);
                        results(i).cluster(j).arrcut.bad{cnt}=bad;
                        results(i).cluster(j).arrcut.cutoff(cnt)=cutoff;
                        if(ishandle(ax))
                            saveas(get(ax,'parent'),...
                                [results(i).runname '_cluster_' sj '_arrcut_' num2str(cnt) '.fig']);
                            close(get(ax,'parent'));
                        end
                    case 2 % NO
                        happy=true;
                end
            end

            % loop until happy with arrival errors
            happy=false; cnt=0;
            while(~happy && pop>2)
                choice=menu(['Cut relative arrival error outliers for cluster ' sj '?'],'Yes','No');
                switch choice
                    case 1 % YES
                        cnt=cnt+1;
                        [bad,cutoff,ax]=errcut(dd(good),arrerr(good));
                        good(bad)=[];
                        pop=numel(good);
                        results(i).cluster(j).errcut.bad{cnt}=bad;
                        results(i).cluster(j).errcut.cutoff(cnt)=cutoff;
                        if(ishandle(ax))
                            saveas(get(ax,'parent'),...
                                [results(i).runname '_cluster_' sj '_errcut_' num2str(cnt) '.fig']);
                            close(get(ax,'parent'));
                        end
                    case 2 % NO
                        happy=true;
                end
            end

            % loop until happy with amplitudes
            happy=false; cnt=0;
            while(~happy && pop>2)
                choice=menu(['Cut relative amplitude outliers for cluster ' sj '?'],'Yes','No');
                switch choice
                    case 1 % YES
                        cnt=cnt+1;
                        [bad,cutoff,ax]=ampcut(dd(good),camp(good),[],1,amperr(good));
                        good(bad)=[];
                        pop=numel(good);
                        results(i).cluster(j).ampcut.bad{cnt}=bad;
                        results(i).cluster(j).ampcut.cutoff(cnt)=cutoff;
                        if(ishandle(ax))
                            saveas(get(ax,'parent'),...
                                [results(i).runname '_cluster_' sj '_ampcut_' num2str(cnt) '.fig']);
                            close(get(ax,'parent'));
                        end
                    case 2 % NO
                        happy=true;
                end
            end

            % user can ask to redo the outlier elimination here
            choice=menu('Redo outlier removal for this cluster?','Yes','No');
            switch choice
                case 1 % YES
                    % do nothing
                case 2 % NO
                    if(pop>2)
                        results(i).outliers(good)=false;
                    else
                        % not enough so kill cluster
                        results(i).usercluster.good(j)=false;
                    end
                    happyoverall=true;
            end
        end
    end
    
    % save results
    tmp=results(i);
    save([results(i).runname '_outliers_results.mat'],'-struct','tmp');
end

end
