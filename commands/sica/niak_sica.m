function [res_ica]=niak_sica(data,opt)
% ICA processing of 2D dataset
%
% SYNTAX:
% RES_ICA = NIAK_DO_SICA(DATA,OPT)
% 
% _________________________________________________________________________
% INPUTS:
%
% DATA          
%       (2D matrix size n*p) with p samples of n mixed channels
% 
% OPT
%       (structure) with the following fields
%       
%       ALGO
%           (string, default 'Infomax') the type of algorithm to be used
%           for the sica decomposition. Available options : 
%           'Infomax', 'Fastica-Def', 'Fastica-Sym, 'Infomax-Prior'.
%
%       TYPE_NB_COMP
%           (integer, default 1) How to choose the number of components:
%           0 : choose directly the number of component to compute
%           1 : choose the ratio of the variance to keep 
%
%       PARAM_NB_COMP
%           If TYPE_NB_COMP = 0:
%               (integer) number of components to compute
%           If TYPE_NB_COMP = 1
%               (real value, default 0.9) ratio of the variance to keep
%
%       PRIOR
%           (matrix) Used if opt.algo = 'Infomax-Prior'. Columns are the 
%           temporal priors 
%
%       VERBOSE
%           (string, default 'on') gives progression infos (includes a 
%           graphical wait bar highly unstable in batch mode). Available
%           options : 'on' or 'off'.
%
% _________________________________________________________________________
% OUTPUTS:
%
% RES_ICA
%       (structure) with the following fields : 
%
%       S
%           (matrix) independent components matrix (the variable is an
%           upper S).
%
%       A
%           (matrix) associated factors (mixing matrix). The variable is an
%           upper A.
%
%       NBCOMP
%           (integer) number of components calculated
%
%       ALGO
%           (string) algorithm use to process ICA
%
% _________________________________________________________________________
% REFERENCES
%
% Perlbarg, V., Bellec, P., Anton, J.-L., Pelegrini-Issac, P., Doyon, J. and 
% Benali, H.; CORSICA: correction of structured noise in fMRI by automatic
% identification of ICA components. Magnetic Resonance Imaging, Vol. 25,
% No. 1. (January 2007), pp. 35-46.
%
% MJ Mckeown, S Makeig, GG Brown, TP Jung, SS Kindermann, AJ Bell, TJ
% Sejnowski; Analysis of fMRI data by blind separation into independent
% spatial components. Hum Brain Mapp, Vol. 6, No. 3. (1998), pp. 160-188.
%
% _________________________________________________________________________
% COMMENTS
%
% Core of this function is copied from the fMRlab toolbox developed at
% Stanford :
% http://www-stat.stanford.edu/wavelab/Wavelab_850/index_wavelab850.html
% The code was mainly contributed by Scott Makeig under a GNU
% license. See subfunctions for details. 
%
% The FastICA methods require the installation of the fastICA toolbox.
%
% The number of components cannot exceed the inner dimension of the data, as 
% indicated by the RANK function . This value is usually a couple of 
% components less than the actual number of time samples of the data.
%
% Copyright (c) Vincent Perlbarg, U678, LIF, Inserm, UMR_S 678, Laboratoire
% d'Imagerie Fonctionnelle, F-75634, Paris, France, 2005-2010.
% Maintainer : vperlbar@imed.jussieu.fr
% See licensing information in the code.
% Keywords : NIAK, ICA, CORSICA

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

if isfield(opt,'type_nb_comp')
    type_nb_comp = opt.type_nb_comp;
else
    type_nb_comp = 1;
    param_nb_comp = 0.9;
end

if isfield(opt,'param_nb_comp')
    param_nb_comp = opt.param_nb_comp;
end

if isfield(opt,'verbose')
    is_verbose = opt.verbose;
else
    is_verbose = 'on';
end

if isfield(opt,'algo')
    algo = opt.algo;
    if strcmp(algo,'Infomax-Prior')
        if isfield(opt,'prior')
            prior = opt.prior;
        else
            fprintf('You must specify the priors for Infomax-Prior/n');
            return
        end
    end        
else
    algo = 'Infomax';
end


if type_nb_comp == 1 %energie  conserver sans gui
        
    covarianceMatrix = cov(data', 1);
    [E, D] = eig(covarianceMatrix);
    [eigenval,index] = sort(diag(D));
    index=rot90(rot90(index));
    eigenvalues=rot90(rot90(eigenval))';
    eigenvectors=E(:,index);
	
    r = rank(data);
	for i=1:r
	    ener_ex(i) = sum(eigenvalues(1:i))/sum(eigenvalues);
	end
	nbcomp = min(find(floor(ener_ex - ones(1,r)*param_nb_comp)>=0));
elseif type_nb_comp==0 %param=nbcomp
    if param_nb_comp == -1
        covarianceMatrix = cov(data', 1);
        [E, D] = eig(covarianceMatrix);
        [eigenval,index] = sort(diag(D));
        eigenvalues=rot90(rot90(eigenval))';
        nsamp = size(data,2);
        [nbcomp] = st_estimate_ncomps(eigenvalues,nsamp);
    else
        nbcomp = param_nb_comp;
    end
end
nbcomp = min(nbcomp,rand(data));
varData = (1/(size(data,1)-1))*sum((data').^2,2);
residus = [];

if strcmp(algo,'Infomax')
    %[weights,sphere,residus] = runica(data,'sphering','off','ncomps',nbcomp,'pca',nbcomp,'verbose','on','maxsteps',300);
    [weights,sphere] = niak_sub_runica(data,'sphering','off','ncomps',nbcomp,'pca',nbcomp,'verbose',is_verbose,'maxsteps',300);
    W=weights*sphere;
    a = pinv(W);
    IC=W*data;
    s=IC';
    for num_comp = 1:size(a,2)
        C = s(:,num_comp)*a(:,num_comp)';
        var_C=(1/(size(C,2)-1))*sum(C.^2,2);
        varCompRatio(:,num_comp) = var_C./varData;
        contrib(num_comp) = mean(varCompRatio(:,num_comp));
    end
elseif strcmp(algo,'Fastica-Def')
    [IC,a,W] = fastica(data,'numOfIC',nbcomp,'approach','defl');
    IC=W*data;
    s=IC';
    for num_comp = 1:size(a,2)
        C = s(:,num_comp)*a(:,num_comp)';
        var_C=(1/(size(C,2)-1))*sum(C.^2,2);
        varCompRatio(:,num_comp) = var_C./varData;
        contrib(num_comp) = mean(varCompRatio(:,num_comp));
    end
elseif strcmp(algo,'Fastica-Sym')
    [IC,a,W] = fastica(data,'numOfIC',nbcomp,'approach','symm');
    IC=W*data;
    s=IC';
    for num_comp = 1:size(a,2)
        C = s(:,num_comp)*a(:,num_comp)';
        var_C=(1/(size(C,2)-1))*sum(C.^2,2);
        varCompRatio(:,num_comp) = var_C./varData;
        contrib(num_comp) = mean(varCompRatio(:,num_comp));
    end
end

contrib = contrib(:);
[sortcontrib,index]=sort(contrib);
s = s(:,index(end:-1:1));
a = a(:,index(end:-1:1));
contrib = sortcontrib(end:-1:1);

residus = data - a*s';

res_ica.composantes = s;
clear s
res_ica.poids = a;
clear a
res_ica.nbcomp = nbcomp;
res_ica.algo = algo;
%res_ica.varatio = varCompRatio;
res_ica.contrib = contrib;
res_ica.residus = residus';

%% Subfunctions 

% runica() - Perform Independent Component Analysis (ICA) decomposition
%            of psychophysiological data using the infomax ICA algorithm of
%            Bell & Sejnowski (1995) with the natural gradient feature
%            of Amari, Cichocki & Yang, the extended-ICA algorithm
%            of Lee, Girolami & Sejnowski, PCA dimension reduction,
%            and/or specgram() preprocessing (suggested by M. Zibulevsky).
%
% Usage:
%         >> [weights,sphere] = runica(data);
%         >> [weights,sphere,residus] = runica(data,'Key1',Value1',...);
% Input:
%    data     = input data (chans,frames*epochs).
%               Note that if data consists of multiple discontinuous epochs,
%               each epoch should be separately baseline-zero'd using
%                  >> data = rmbase(data,frames,basevector);
%
% Optional keywords:
% 'ncomps'    = [N] number of ICA components to compute (default -> chans)
%               using rectangular ICA decomposition
% 'pca'       = [N] decompose a principal component     (default -> 0=off)
%               subspace of the data. Value is the number of PCs to retain.
% 'sphering'  = ['on'/'off'] flag sphering of data      (default -> 'on')
% 'weights'   = [W] initial weight matrix               (default -> eye())
%                            (Note: if 'sphering' 'off', default -> spher())
% 'lrate'     = [rate] initial ICA learning rate (<< 1) (default -> heuristic)
% 'block'     = [N] ICA block size (<< datalength)      (default -> heuristic)
% 'anneal'    = annealing constant (0,1] (defaults -> 0.90, or 0.98, extended)
%                         controls speed of convergence
% 'annealdeg' = [N] degrees weight change for annealing (default -> 70)
% 'stop'      = [f] stop training when weight-change < this (default -> 1e-6)
% 'maxsteps'  = [N] max number of ICA training steps    (default -> 512)
% 'bias'      = ['on'/'off'] perform bias adjustment    (default -> 'on')
% 'momentum'  = [0<f<1] training momentum               (default -> 0)
% 'extended'  = [N] perform tanh() "extended-ICA" with sign estimation
%               every N training blocks. If N < 0, fix number of sub-Gaussian
%               components to -N [faster than N>0]      (default|0 -> off)
% 'specgram'  = [srate loHz hiHz frames winframes] decompose a complex time/frequency
%               transform of the data (Note: winframes must divide frames)
%                            (defaults [srate 0 srate/2 size(data,2) size(data,2)])
% 'posact'    = make all component activations net-positive(default 'on'}
% 'verbose'   = give ascii messages ('on'/'off')        (default -> 'on')
%
% Outputs: [RO: output in reverse order of projected mean variance
%                        unless starting weight matrix passed ('weights' above)]
% weights     = ICA weight matrix (comps,chans)     [RO]
% sphere      = data sphering matrix (chans,chans) = spher(data)
%               Note that unmixing_matrix = weights*sphere {sphering off -> eye(chans)}
% activations = activation time courses of the output components (ncomps,frames*epochs)
% bias        = vector of final (ncomps) online bias [RO]    (default = zeros())
% signs       = extended-ICA signs for components    [RO]    (default = ones())
%                   [ -1 = sub-Gaussian; 1 = super-Gaussian]
% lrates      = vector of learning rates used at each training step
%
% Authors: Scott Makeig with contributions from Tony Bell, Te-Won Lee,
% Tzyy-Ping Jung, Sigurd Enghoff, Michael Zibulevsky, CNL/The Salk Institute,
% La Jolla, 1996-

% Uses: posact()

% Reference (please cite):
%
% Makeig, S., Bell, A.J., Jung, T-P and Sejnowski, T.J.,
% "Independent component analysis of electroencephalographic data,"
% In: D. Touretzky, M. Mozer and M. Hasselmo (Eds). Advances in Neural
% Information Processing Systems 8:145-151, MIT Press, Cambridge, MA (1996).
%
% Toolbox Citation:
%
% Makeig, Scott et al. "EEGLAB: ICA Toolbox for Psychophysiological Research".
% WWW Site, Swartz Center for Computational Neuroscience, Institute of Neural
% Computation, University of San Diego California
% <www.sccn.ucsd.edu/eeglab/>, 2000. [World Wide Web Publication].
%
% For more information:
% http://www.sccn.ucsd.edu/eeglab/icafaq.html - FAQ on ICA/EEG
% http://www.sccn.ucsd.edu/eeglab/icabib.html - mss. on ICA & biosignals
% http://www.cnl.salk.edu/~tony/ica.html - math. mss. on ICA

% Copyright (C) 1996 Scott Makeig et al, SCCN/INC/UCSD, scott@sccn.ucsd.edu
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Log: runica.m,v $
% Revision 1.3  2003/01/15 22:08:21  arno
% typo
%
% Revision 1.2  2002/10/23 18:09:54  arno
% new interupt button
%
% Revision 1.1  2002/04/05 17:36:45  jorn
% Initial revision
%

%%%%%%%%%%%%%%%%%%%%%%%%%%% Edit history %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  runica()  - by Scott Makeig with contributions from Tony Bell, Te-Won Lee
%              Tzyy-Ping Jung, Sigurd Enghoff, Michael Zibulevsky et al.
%                            CNL / Salk Institute 1996-00
%  04-30-96 built from icatest.m and ~jung/.../wtwpwica.m -sm
%  07-28-97 new runica(), adds bias (default on), momentum (default off),
%           extended-ICA (Lee & Sejnowski, 1997), cumulative angledelta
%           (until lrate drops), keywords, signcount for speeding extended-ICA
%  10-07-97 put acos() outside verbose loop; verbose 'off' wasn't stopping -sm
%  11-11-97 adjusted help msg -sm
%  11-30-97 return eye(chans) if sphering 'off' or 'none' (undocumented option) -sm
%  02-27-98 use pinv() instead of inv() to rank order comps if ncomps < chans -sm
%  04-28-98 added 'posact' and 'pca' flags  -sm
%  07-16-98 reduced length of randperm() for kurtosis subset calc. -se & sm
%  07-19-98 fixed typo in weights def. above -tl & sm
%  12-21-99 added 'specgram' option suggested by Michael Zibulevsky, UNM -sm
%  12-22-99 fixed rand() sizing inefficiency on suggestion of Mike Spratling, UK -sm
%  01-11-00 fixed rand() sizing bug on suggestion of Jack Foucher, Strasbourg -sm
%  12-18-00 test for existence of Sig Proc Tlbx function 'specgram'; improve
%           'specgram' option arguments -sm
%  01-25-02 reformated help & license -ad
%  01-25-02 lowered default lrate and block -ad
%  12-07-06 compute the residuals of the PCA analysis and set them as a
%           return argument - Pierre Bellec
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [weights,sphere,residus,CP] = niak_sub_runica(data,p1,v1,p2,v2,p3,v3,p4,v4,p5,v5,p6,v6,p7,v7,p8,v8,p9,v9,p10,v10,p11,v11,p12,v12,p13,v13,p14,v14,p15,v15)

if nargin < 1
    help runica
    return
end

[chans frames] = size(data); % determine the data size
urchans = chans;  % remember original data channels
datalength = frames;
if chans<2
    fprintf('\nrunica() - data size (%d,%d) too small.\n\n', chans,frames);
    return
end
%
%%%%%%%%%%%%%%%%%%%%%% Declare defaults used below %%%%%%%%%%%%%%%%%%%%%%%%
%
MAX_WEIGHT           = 1e8;       % guess that weights larger than this have blown up
DEFAULT_STOP         = 0.00001;  % stop training if weight changes below this
DEFAULT_ANNEALDEG    = 60;        % when angle change reaches this value,
DEFAULT_ANNEALSTEP   = 0.90;      %     anneal by multiplying lrate by this
DEFAULT_EXTANNEAL    = 0.98;      %     or this if extended-ICA
DEFAULT_MAXSTEPS     = 512;       % ]top training after this many steps
DEFAULT_MOMENTUM     = 0.0;       % default momentum weight

DEFAULT_BLOWUP       = 1000000000.0;   % = learning rate has 'blown up'
DEFAULT_BLOWUP_FAC   = 0.8;       % when lrate 'blows up,' anneal by this fac
DEFAULT_RESTART_FAC  = 0.9;       % if weights blowup, restart with lrate
% lower by this factor
MIN_LRATE            = 0.000001;  % if weight blowups make lrate < this, quit
MAX_LRATE            = 0.1;       % guard against uselessly high learning rate
DEFAULT_LRATE        = 0.00065/log(chans);
% heuristic default - may need adjustment
%   for large or tiny data sets!
% DEFAULT_BLOCK        = floor(sqrt(frames/4));  % heuristic default
DEFAULT_BLOCK        = min(floor(5*log(frames)),0.3*frames); % heuristic
% - may need adjustment!
% Extended-ICA option:
DEFAULT_EXTENDED     = 0;         % default off
DEFAULT_EXTBLOCKS    = 1;         % number of blocks per kurtosis calculation
DEFAULT_NSUB         = 1;         % initial default number of assumed sub-Gaussians
% for extended-ICA
DEFAULT_EXTMOMENTUM  = 0.5;       % momentum term for computing extended-ICA kurtosis
MAX_KURTSIZE         = 6000;      % max points to use in kurtosis calculation
MIN_KURTSIZE         = 2000;      % minimum good kurtosis size (flag warning)
SIGNCOUNT_THRESHOLD  = 25;        % raise extblocks when sign vector unchanged
% after this many steps
SIGNCOUNT_STEP       = 2;         % extblocks increment factor

DEFAULT_SPHEREFLAG   = 'on';      % use the sphere matrix as the default
%   starting weight matrix
DEFAULT_PCAFLAG      = 'off';     % don't use PCA reduction
DEFAULT_POSACTFLAG   = 'on';      % use posact()
DEFAULT_VERBOSE      = 1;         % write ascii info to calling screen
DEFAULT_BIASFLAG     = 1;         % default to using bias in the ICA update rule
%
%%%%%%%%%%%%%%%%%%%%%%% Set up keyword default values %%%%%%%%%%%%%%%%%%%%%%%%%
%
if nargout < 2,
    fprintf('runica() - needs at least two output arguments.\n');
    return
end
epochs = 1;							 % do not care how many epochs in data

pcaflag    = DEFAULT_PCAFLAG;
sphering   = DEFAULT_SPHEREFLAG;     % default flags
posactflag = DEFAULT_POSACTFLAG;
verbose    = DEFAULT_VERBOSE;

block      = DEFAULT_BLOCK;          % heuristic default - may need adjustment!
lrate      = DEFAULT_LRATE;
annealdeg  = DEFAULT_ANNEALDEG;
annealstep = 0;                      % defaults declared below
nochange   = DEFAULT_STOP;
momentum   = DEFAULT_MOMENTUM;
maxsteps   = DEFAULT_MAXSTEPS;

weights    = 0;                      % defaults defined below
ncomps     = chans;
biasflag   = DEFAULT_BIASFLAG;

extended   = DEFAULT_EXTENDED;
extblocks  = DEFAULT_EXTBLOCKS;
kurtsize   = MAX_KURTSIZE;
signsbias  = 0.02;                   % bias towards super-Gaussian components
extmomentum= DEFAULT_EXTMOMENTUM;    % exp. average the kurtosis estimates
nsub       = DEFAULT_NSUB;
wts_blowup = 0;                      % flag =1 when weights too large
wts_passed = 0;                      % flag weights passed as argument
prior_flag = 0;
%
%%%%%%%%%% Collect keywords and values from argument list %%%%%%%%%%%%%%%
%

if (nargin> 1 & rem(nargin,2) == 0)
    fprintf('runica(): Even number of input arguments???')
    return
end
for i = 3:2:nargin % for each Keyword
    Keyword = eval(['p',int2str((i-3)/2 +1)]);
    Value = eval(['v',int2str((i-3)/2 +1)]);
    if ~ischar(Keyword)
        fprintf('runica(): keywords must be strings')
        return
    end
    Keyword = lower(Keyword); % convert upper or mixed case to lower

    if strcmp(Keyword,'weights') | strcmp(Keyword,'weight')
        if ischar(Value)
            fprintf(...
                'runica(): weights value must be a weight matrix or sphere')
            return
        else
            weights = Value;
            wts_passed =1;
        end
    elseif strcmp(Keyword,'ncomps')
        if ischar(Value)
            fprintf('runica(): ncomps value must be an integer')
            return
        end
        if ncomps < urchans & ncomps ~= Value
            fprintf('runica(): Use either PCA or ICA dimension reduction');
            return
        end
        ncomps = Value;
        if ~ncomps,
            ncomps = chans;
        end
    elseif strcmp(Keyword,'pca')
        if ncomps < urchans & ncomps ~= Value
            fprintf('runica(): Use either PCA or ICA dimension reduction');
            return
        end
        if ischar(Value)
            fprintf(...
                'runica(): pca value should be the number of principal components to retain')
            return
        end
        pcaflag = 'on';
        ncomps = Value;
        if ncomps >= chans | ncomps < 1,
            fprintf('runica(): pca value must be in range [1,%d]\n',chans-1)
            return
        end
        chans = ncomps;
    elseif strcmp(Keyword,'posact')
        if ~ischar(Value)
            fprintf('runica(): posact value must be on or off')
            return
        else
            Value = lower(Value);
            if ~strcmp(Value,'on') & ~strcmp(Value,'off'),
                fprintf('runica(): posact value must be on or off')
                return
            end
            posactflag = Value;
        end
    elseif strcmp(Keyword,'lrate')
        if ischar(Value)
            fprintf('runica(): lrate value must be a number')
            return
        end
        lrate = Value;
        if lrate>MAX_LRATE | lrate <0,
            fprintf('runica(): lrate value is out of bounds');
            return
        end
        if ~lrate,
            lrate = DEFAULT_LRATE;
        end
    elseif strcmp(Keyword,'block') | strcmp(Keyword,'blocksize')
        if ischar(Value)
            fprintf('runica(): block size value must be a number')
            return
        end
        block = Value;
        if ~block,
            block = DEFAULT_BLOCK;
        end
    elseif strcmp(Keyword,'stop') | strcmp(Keyword,'nochange') ...
            | strcmp(Keyword,'stopping')
        if ischar(Value)
            fprintf('runica(): stop wchange value must be a number')
            return
        end
        nochange = Value;
    elseif strcmp(Keyword,'maxsteps') | strcmp(Keyword,'steps')
        if ischar(Value)
            fprintf('runica(): maxsteps value must be an integer')
            return
        end
        maxsteps = Value;
        if ~maxsteps,
            maxsteps   = DEFAULT_MAXSTEPS;
        end
        if maxsteps < 0
            fprintf('runica(): maxsteps value (%d) must be a positive integer',maxsteps)
            return
        end
    elseif strcmp(Keyword,'anneal') | strcmp(Keyword,'annealstep')
        if ischar(Value)
            fprintf('runica(): anneal step value (%2.4f) must be a number (0,1)',Value)
            return
        end
        annealstep = Value;
        if annealstep <=0 | annealstep > 1,
            fprintf('runica(): anneal step value (%2.4f) must be (0,1]',annealstep)
            return
        end
    elseif strcmp(Keyword,'annealdeg') | strcmp(Keyword,'degrees')
        if ischar(Value)
            fprintf('runica(): annealdeg value must be a number')
            return
        end
        annealdeg = Value;
        if ~annealdeg,
            annealdeg = DEFAULT_ANNEALDEG;
        elseif annealdeg > 180 | annealdeg < 0
            fprintf('runica(): annealdeg (%3.1f) is out of bounds [0,180]',...
                annealdeg);
            return

        end
    elseif strcmp(Keyword,'momentum')
        if ischar(Value)
            fprintf('runica(): momentum value must be a number')
            return
        end
        momentum = Value;
        if momentum > 1.0 | momentum < 0
            fprintf('runica(): momentum value is out of bounds [0,1]')
            return
        end
    elseif strcmp(Keyword,'sphering') | strcmp(Keyword,'sphereing') ...
            | strcmp(Keyword,'sphere')
        if ~ischar(Value)
            fprintf('runica(): sphering value must be on, off, or none')
            return
        else
            Value = lower(Value);
            if ~strcmp(Value,'on') & ~strcmp(Value,'off') & ~strcmp(Value,'none'),
                fprintf('runica(): sphering value must be on or off')
                return
            end
            sphering = Value;
        end
    elseif strcmp(Keyword,'bias')
        if ~ischar(Value)
            fprintf('runica(): bias value must be on or off')
            return
        else
            Value = lower(Value);
            if strcmp(Value,'on')
                biasflag = 1;
            elseif strcmp(Value,'off'),
                biasflag = 0;
            else
                fprintf('runica(): bias value must be on or off')
                return
            end
        end
    elseif strcmp(Keyword,'specgram') | strcmp(Keyword,'spec')

        if ~exist('specgram') < 2 % if ~exist or defined workspace variable
            fprintf(...
                'runica(): MATLAB Sig. Proc. Toolbox function "specgram" not found.\n')
            return
        end
        if ischar(Value)
            fprintf('runica(): specgram argument must be a vector')
            return
        end
        srate = Value(1);
        if (srate < 0)
            fprintf('runica(): specgram srate (%4.1f) must be >=0',srate)
            return
        end
        if length(Value)>1
            loHz = Value(2);
            if (loHz < 0 | loHz > srate/2)
                fprintf('runica(): specgram loHz must be >=0 and <= srate/2 (%4.1f)',srate/2)
                return
            end
        else
            loHz = 0; % default
        end
        if length(Value)>2
            hiHz = Value(3);
            if (hiHz < loHz | hiHz > srate/2)
                fprintf('runica(): specgram hiHz must be >=loHz (%4.1f) and <= srate/2 (%4.1f)',loHz,srate/2)
                return
            end
        else
            hiHz = srate/2; % default
        end
        if length(Value)>3
            Hzframes = Value(5);
            if (Hzframes<0 | Hzframes > size(data,2))
                fprintf('runica(): specgram frames must be >=0 and <= data length (%d)',size(data,2))
                return
            end
        else
            Hzframes = size(data,2); % default
        end
        if length(Value)>4
            Hzwinlen = Value(4);
            if rem(Hzframes,Hzwinlen) % if winlen doesn't divide frames
                fprintf('runica(): specgram Hzinc must divide frames (%d)',Hzframes)
                return
            end
        else
            Hzwinlen = Hzframes; % default
        end
        Specgramflag = 1; % set flag to perform specgram()

    elseif strcmp(Keyword,'extended') | strcmp(Keyword,'extend')
        if ischar(Value)
            fprintf('runica(): extended value must be an integer (+/-)')
            return
        else
            extended = 1;      % turn on extended-ICA
            extblocks = fix(Value); % number of blocks per kurt() compute
            if extblocks < 0
                nsub = -1*fix(extblocks);  % fix this many sub-Gauss comps
            elseif ~extblocks,
                extended = 0;             % turn extended-ICA off
            elseif kurtsize>frames,   % length of kurtosis calculation
                kurtsize = frames;
                if kurtsize < MIN_KURTSIZE
                    fprintf(...
                        'runica() warning: kurtosis values inexact for << %d points.\n',...
                        MIN_KURTSIZE);
                end
            end
        end
    elseif strcmp(Keyword,'verbose')
        if ~ischar(Value)
            fprintf('runica(): verbose flag value must be on or off')
            return
        elseif strcmp(Value,'on'),
            verbose = 1;
        elseif strcmp(Value,'off'),
            verbose = 0;
        else
            fprintf('runica(): verbose flag value must be on or off')
            return
        end
    else
        fprintf('runica(): unknown flag')
        return
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%% Initialize weights, etc. %%%%%%%%%%%%%%%%%%%%%%%%
%
if ~annealstep,
    if ~extended,
        annealstep = DEFAULT_ANNEALSTEP;     % defaults defined above
    else
        annealstep = DEFAULT_EXTANNEAL;       % defaults defined above
    end
end % else use annealstep from commandline

if ~annealdeg,
    annealdeg  = DEFAULT_ANNEALDEG - momentum*90; % heuristic
    if annealdeg < 0,
        annealdeg = 0;
    end
end
if ncomps >  chans | ncomps < 1
    fprintf('runica(): number of components must be 1 to %d.\n',chans);
    return
end

if weights ~= 0,                    % initialize weights
    % starting weights are being passed to runica() from the commandline
    if verbose,
        fprintf('Using starting weight matrix named in argument list ...\n')
    end
    if  chans>ncomps & weights ~=0,
        [r,c]=size(weights);
        if r~=ncomps | c~=chans,
            fprintf(...
                'runica(): weight matrix must have %d rows, %d columns.\n', ...
                chans,ncomps);
            return;
        end
    end
end;
%
%%%%%%%%%%%%%%%%%%%%% Check keyword values %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
if frames<chans,
    fprintf('runica(): data length (%d) < data channels (%d)!\n',frames,chans)
    return
elseif block < 2,
    fprintf('runica(): block size %d too small!\n',block)
    return
elseif block > frames,
    fprintf('runica(): block size exceeds data length!\n');
    return
elseif floor(epochs) ~= epochs,
    fprintf('runica(): data length is not a multiple of the epoch length!\n');
    return
elseif nsub > ncomps
    fprintf('runica(): there can be at most %d sub-Gaussian components!\n',ncomps);
    return
end;
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Process the data %%%%%%%%%%%%%%%%%%%%%%%%%%
%




if verbose,
    h = waitbar(0,'Performing sica...Please wait...');
    waitbar(1/(maxsteps+2),h)
    fprintf( ...
        '\nInput data size [%d,%d] = %d channels, %d frames.\n', ...
        chans,frames,chans,frames);
    if strcmp(pcaflag,'on')
        fprintf('After PCA dimension reduction,\n  finding ');
    else
        fprintf('Finding ');
    end
    if ~extended
        fprintf('%d ICA components using logistic ICA.\n',ncomps);
    else % if extended
        fprintf('%d ICA components using extended ICA.\n',ncomps);
        if extblocks > 0
            fprintf(...
                'Kurtosis will be calculated initially every %d blocks using %d data points.\n',...
                extblocks,     kurtsize);
        else
            fprintf(...
                'Kurtosis will not be calculated. Exactly %d sub-Gaussian components assumed.\n',...
                nsub);
        end
    end
    fprintf('Initial learning rate will be %g, block size %d.\n',lrate,block);
    if momentum>0,
        fprintf('Momentum will be %g.\n',momentum);
    end
    fprintf( ...
        'Learning rate will be multiplied by %g whenever angledelta >= %g deg.\n', ...
        annealstep,annealdeg);
    fprintf('Training will end when wchange < %g or after %d steps.\n', ...
        nochange,maxsteps);
    if biasflag,
        fprintf('Online bias adjustment will be used.\n');
    else
        fprintf('Online bias adjustment will not be used.\n');
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%%% Remove overall row means %%%%%%%%%%%%%%%%%%%%%%%%
%
if verbose,
    fprintf('Removing mean of each channel ...\n');
end
means = mean(data');
data = data - means'*ones(1,frames);      % subtract row means


if verbose,
    fprintf('Final training data range: %g to %g\n', ...
        min(min(data)),max(max(data)));
end
%
%%%%%%%%%%%%%%%%%%% Perform PCA reduction %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
if strcmp(pcaflag,'on')
    fprintf('    Reducing the data to %d principal dimensions...\n',ncomps);

    covarianceMatrix = cov(data');
    [E, D] = eig(covarianceMatrix);
    [eigenval,index] = sort(diag(D));
    index=rot90(rot90(index));
    eigenvalues=rot90(rot90(eigenval))';
    eigenvectors=E(:,index);
    residus = eigenvectors(:,ncomps+1:end)*eigenvectors(:,ncomps+1:end)'*data;
    data = eigenvectors(:,1:ncomps)'*data;

    %    [pc,coeff,sigma] = runpca(data);
    %    data = coeff(:,1:ncomps)'*data;
    %    residus = pc(:,ncomps+1:end) * coeff(:,ncomps+1:end)';


    % make data its projection onto the ncomps-dim principal subspace
end
%
%%%%%%%%%%%%%%%%%%% Perform specgram transformation %%%%%%%%%%%%%%%%%%%%%%%
%
if exist('Specgramflag') == 1
    % [P F T] = SPECGRAM(A,NFFT,Fs,WINDOW,NOVERLAP) % MATLAB Sig Proc Toolbox
    % Hzwinlen =  fix(srate/Hzinc); % CHANGED FROM THIS 12/18/00 -sm

    Hzfftlen = 2^(ceil(log(Hzwinlen)/log(2)));   % make FFT length next higher 2^k
    Hzoverlap = 0; % use sequential windows
    %
    % Get freqs and times from 1st channel analysis
    %
    [tmp,freqs,tms] = specgram(data(1,:),Hzfftlen,srate,Hzwinlen,Hzoverlap);

    fs = find(freqs>=loHz & freqs <= hiHz);
    if isempty(fs)
        fprintf('runica(): specified frequency range too narrow!\n');
        return
    end;

    specdata = reshape(tmp(fs,:),1,length(fs)*size(tmp,2));
    specdata = [real(specdata) imag(specdata)];
    % fprintf('   size(fs) = %d,%d\n',size(fs,1),size(fs,2));
    % fprintf('   size(tmp) = %d,%d\n',size(tmp,1),size(tmp,2));
    %
    % Loop through remaining channels
    %
    for ch=2:chans
        [tmp] = specgram(data(ch,:),Hzwinlen,srate,Hzwinlen,Hzoverlap);
        tmp = reshape((tmp(fs,:)),1,length(fs)*size(tmp,2));
        specdata = [specdata;[real(tmp) imag(tmp)]]; % channels are rows
    end
    %
    % Print specgram confirmation and details
    %
    fprintf(...
        'Converted data to %d channels by %d=2*%dx%d points spectrogram data.\n',...
        chans,2*length(fs)*length(tms),length(fs),length(tms));
    if length(fs) > 1
        fprintf(...
            '   Low Hz %g, high Hz %g, Hz incr %g, window length %d\n',freqs(fs(1)),freqs(fs(end)),freqs(fs(2))-freqs(fs(1)),Hzwinlen);
    else
        fprintf(...
            '   Low Hz %g, high Hz %g, window length %d\n',freqs(fs(1)),freqs(fs(end)),Hzwinlen);
    end
    %
    % Replace data with specdata
    %
    data = specdata;
    datalength=size(data,2);
end
%
%%%%%%%%%%%%%%%%%%% Perform sphering %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%

if strcmp(sphering,'on'), %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if verbose,
        fprintf('Computing the sphering matrix...\n');
    end
    sphere = 2.0*inv(sqrtm(cov(data'))); % find the "sphering" matrix = spher()
    if ~weights,
        if verbose,
            fprintf('Starting weights are the identity matrix ...\n');
        end
        weights = eye(ncomps,chans); % begin with the identity matrix
    else % weights given on commandline
        if verbose,
            fprintf('Using starting weights named on commandline ...\n');
        end
    end
    if verbose,
        fprintf('Sphering the data ...\n');
    end
    data = sphere*data;      % actually decorrelate the electrode signals

elseif strcmp(sphering,'off') %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~weights
        if verbose,
            fprintf('Using the sphering matrix as the starting weight matrix ...\n');
            fprintf('Returning the identity matrix in variable "sphere" ...\n');
        end
        sphere = 2.0*inv(sqrtm(cov(data'))); % find the "sphering" matrix = spher()
        weights = eye(ncomps,chans)*sphere; % begin with the identity matrix
        sphere = eye(chans);                 % return the identity matrix
    else % weights ~= 0
        if verbose,
            fprintf('Using starting weights named on commandline ...\n');
            fprintf('Returning the identity matrix in variable "sphere" ...\n');
        end
        sphere = eye(chans);                 % return the identity matrix
    end
elseif strcmp(sphering,'none')
    sphere = eye(chans);                     % return the identity matrix
    if ~weights
        if verbose,
            fprintf('Starting weights are the identity matrix ...\n');
            fprintf('Returning the identity matrix in variable "sphere" ...\n');
        end
        weights = eye(ncomps,chans); % begin with the identity matrix
    else % weights ~= 0
        if verbose,
            fprintf('Using starting weights named on commandline ...\n');
            fprintf('Returning the identity matrix in variable "sphere" ...\n');
        end
    end
    sphere = eye(chans,chans);
    if verbose,
        fprintf('Returned variable "sphere" will be the identity matrix.\n');
    end
end
%
%%%%%%%%%%%%%%%%%%%%%%%% Initialize ICA training %%%%%%%%%%%%%%%%%%%%%%%%%
%
lastt=fix((datalength/block-1)*block+1);
BI=block*eye(ncomps,ncomps);
delta=zeros(1,chans*ncomps);
changes = [];
degconst = 180./pi;
startweights = weights;
prevweights = startweights;
oldweights = startweights;
prevwtchange = zeros(chans,ncomps);
oldwtchange = zeros(chans,ncomps);
lrates = zeros(1,maxsteps);
onesrow = ones(1,block);
bias = zeros(ncomps,1);
signs = ones(1,ncomps);    % initialize signs to nsub -1, rest +1
for k=1:nsub
    signs(k) = -1;
end
if extended & extblocks < 0 & verbose,
    fprintf('Fixed extended-ICA sign assignments:  ');
    for k=1:ncomps
        fprintf('%d ',signs(k));
    end; fprintf('\n');
end
signs = diag(signs); % make a diagonal matrix
oldsigns = zeros(size(signs));;
signcount = 0;              % counter for same-signs
signcounts = [];
urextblocks = extblocks;    % original value, for resets
old_kk = zeros(1,ncomps);   % for kurtosis momemtum
%
%%%%%%%% ICA training loop using the logistic sigmoid %%%%%%%%%%%%%%%%%%%
%
if verbose,
    fprintf('Beginning ICA training ...');
    if extended,
        fprintf(' first training step may be slow ...\n');
    else
        fprintf('\n');
    end
end
step=0;
laststep=0;
blockno = 1;  % running block counter for kurtosis interrupts

if verbose
    waitbar(2/(maxsteps+2),h)
end
while step < maxsteps, %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    permute=randperm(datalength); % shuffle data order at each step

    for t=1:block:lastt, %%%%%%%%% ICA Training Block %%%%%%%%%%%%%%%%%%%
        pause(0);
        if ~isempty(get(0, 'currentfigure')) & strcmp(get(gcf, 'tag'), 'stop')
            close; error('USER ABORT');
        end;
        if biasflag
            u=weights*data(:,permute(t:t+block-1)) + bias*onesrow;
        else
            u=weights*data(:,permute(t:t+block-1));
        end
        if ~extended
            %%%%%%%%%%%%%%%%%%% Logistic ICA weight update %%%%%%%%%%%%%%%%%%%
            y=1./(1+exp(-u));                                                %
            weights=weights+lrate*(BI+(1-2*y)*u')*weights;                   %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        else % extended-ICA
            %%%%%%%%%%%%%%%%%%% Extended-ICA weight update %%%%%%%%%%%%%%%%%%%
            y=tanh(u);                                                       %
            weights = weights + lrate*(BI-signs*y*u'-u*u')*weights;          %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        if biasflag
            if ~extended
                %%%%%%%%%%%%%%%%%%%%%%%% Logistic ICA bias %%%%%%%%%%%%%%%%%%%%%%%
                bias = bias + lrate*sum((1-2*y)')'; % for logistic nonlin. %
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            else % extended
                %%%%%%%%%%%%%%%%%%% Extended-ICA bias %%%%%%%%%%%%%%%%%%%%%%%%%%%%
                bias = bias + lrate*sum((-2*y)')';  % for tanh() nonlin.   %
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
        end

        if momentum > 0 %%%%%%%%% Add momentum %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            weights = weights + momentum*prevwtchange;
            prevwtchange = weights-prevweights;
            prevweights = weights;
        end %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if max(max(abs(weights))) > MAX_WEIGHT
            wts_blowup = 1;
            change = nochange;
        end
        if extended & ~wts_blowup
            %
            %%%%%%%%%%% Extended-ICA kurtosis estimation %%%%%%%%%%%%%%%%%%%%%
            %
            if extblocks > 0 & rem(blockno,extblocks) == 0,
                % recompute signs vector using kurtosis
                if kurtsize < frames % 12-22-99 rand() size suggestion by M. Spratling
                    rp = fix(rand(1,kurtsize)*datalength);  % pick random subset
                    % Accout for the possibility of a 0 generation by rand
                    ou = find(rp == 0);
                    while ~isempty(ou) % 1-11-00 suggestion by J. Foucher
                        rp(ou) = fix(rand(1,length(ou))*datalength);
                        ou = find(rp == 0);
                    end
                    partact=weights*data(:,rp(1:kurtsize));
                else                                        % for small data sets,
                    partact=weights*data;                   % use whole data
                end
                m2=mean(partact'.^2).^2;
                m4= mean(partact'.^4);
                kk= (m4./m2)-3.0;                           % kurtosis estimates
                if extmomentum
                    kk = extmomentum*old_kk + (1.0-extmomentum)*kk; % use momentum
                    old_kk = kk;
                end
                signs=diag(sign(kk+signsbias));             % pick component signs
                if signs == oldsigns,
                    signcount = signcount+1;
                else
                    signcount = 0;
                end
                oldsigns = signs;
                signcounts = [signcounts signcount];
                if signcount >= SIGNCOUNT_THRESHOLD,
                    extblocks = fix(extblocks * SIGNCOUNT_STEP);% make kurt() estimation
                    signcount = 0;                             % less frequent if sign
                end                                         % is not changing
            end % extblocks > 0 & . . .
        end % if extended %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        blockno = blockno + 1;
        if wts_blowup
            break
        end
    end % training block %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~wts_blowup
        oldwtchange = weights-oldweights;
        step=step+1;
        %
        %%%%%%% Compute and print weight and update angle changes %%%%%%%%%
        %
        lrates(1,step) = lrate;
        angledelta=0.;
        delta=reshape(oldwtchange,1,chans*ncomps);
        change=delta*delta';
    end
    %
    %%%%%%%%%%%%%%%%%%%%%% Restart if weights blow up %%%%%%%%%%%%%%%%%%%%
    %
    if wts_blowup | isnan(change)|isinf(change),  % if weights blow up,
        fprintf('');
        step = 0;                          % start again
        change = nochange;
        wts_blowup = 0;                    % re-initialize variables
        blockno = 1;
        lrate = lrate*DEFAULT_RESTART_FAC; % with lower learning rate
        weights = startweights;            % and original weight matrix
        oldweights = startweights;
        change = nochange;
        oldwtchange = zeros(chans,ncomps);
        delta=zeros(1,chans*ncomps);
        olddelta = delta;
        extblocks = urextblocks;
        prevweights = startweights;
        prevwtchange = zeros(chans,ncomps);
        lrates = zeros(1,maxsteps);
        bias = zeros(ncomps,1);
        if extended
            signs = ones(1,ncomps);    % initialize signs to nsub -1, rest +1
            for k=1:nsub
                signs(k) = -1;
            end
            signs = diag(signs); % make a diagonal matrix
            oldsigns = zeros(size(signs));;
        end
        if lrate> MIN_LRATE
            r = rank(data);
            if r<ncomps
                fprintf('Data has rank %d. Cannot compute %d components.\n',...
                    r,ncomps);
                return
            else
                fprintf(...
                    'Lowering learning rate to %g and starting again.\n',lrate);
            end
        else
            fprintf( ...
                'runica(): QUITTING - weight matrix may not be invertible!\n');
            return;
        end
    else % if weights in bounds
        %
        %%%%%%%%%%%%% Print weight update information %%%%%%%%%%%%%%%%%%%%%%
        %
        if step> 2
            angledelta=acos((delta*olddelta')/sqrt(change*oldchange));
        end
        if verbose,
            if step > 2,
                if ~extended,
                    fprintf(...
                        'step %d - lrate %5f, wchange %7.6f, angledelta %4.1f deg\n', ...
                        step,lrate,change,degconst*angledelta);
                else
                    fprintf(...
                        'step %d - lrate %5f, wchange %7.6f, angledelta %4.1f deg, %d subgauss\n',...
                        step,lrate,change,degconst*angledelta,(ncomps-sum(diag(signs)))/2);
                end
            elseif ~extended
                fprintf(...
                    'step %d - lrate %5f, wchange %7.6f\n',step,lrate,change);
            else
                fprintf(...
                    'step %d - lrate %5f, wchange %7.6f, %d subgauss\n',...
                    step,lrate,change,(ncomps-sum(diag(signs)))/2);
            end % step > 2
        end; % if verbose
        if verbose
            waitbar((2+step)/(maxsteps+2),h)
        end

        %
        %%%%%%%%%%%%%%%%%%%% Save current values %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        changes = [changes change];
        oldweights = weights;
        %
        %%%%%%%%%%%%%%%%%%%% Anneal learning rate %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        if degconst*angledelta > annealdeg,
            lrate = lrate*annealstep;          % anneal learning rate
            olddelta   = delta;                % accumulate angledelta until
            oldchange  = change;               %  annealdeg is reached
        elseif step == 1                     % on first step only
            olddelta   = delta;                % initialize
            oldchange  = change;
        end
        %
        %%%%%%%%%%%%%%%%%%%% Apply stopping rule %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        if step >2 & change < nochange,      % apply stopping rule
            laststep=step;
            step=maxsteps;                  % stop when weights stabilize
        elseif change > DEFAULT_BLOWUP,      % if weights blow up,
            lrate=lrate*DEFAULT_BLOWUP_FAC;    % keep trying
        end;                                 % with a smaller learning rate



    end; % end if weights in bounds

end; % end training %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~laststep
    laststep = step;
end;
lrates = lrates(1,1:laststep);           % truncate lrate history vector
%
%%%%%%%%%%%%%% Orient components towards max positive activation %%%%%%
%
if strcmp(posactflag,'on')
    [activations,winvout,weights] = posact(data,weights);
    % changes signs of activations and weights to make activations
    % net rms-positive
else
    activations = weights*data;
end
%
%%%%%%%%%%%%%% If pcaflag, compose PCA and ICA matrices %%%%%%%%%%%%%%%
%
if strcmp(pcaflag,'on')
    fprintf('    Composing the eigenvector, weights, and sphere matrices\n');
    fprintf('        into a single rectangular weights matrix; sphere=eye(%d)\n'...
        ,chans);
    %weights= weights*sphere*eigenvectors(:,1:ncomps)';
    weights= weights*sphere*eigenvectors(:,1:ncomps)';
    sphere = eye(urchans);
end
%
%%%%%% Sort components in descending order of max projected variance %%%%
%
if verbose,
    fprintf(...
        'Sorting components in descending order of mean projected variance ...\n');
end
if wts_passed == 0
    %
    %%%%%%%%%%%%%%%%%%%% Find mean variances %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    meanvar  = zeros(ncomps,1);      % size of the projections
    if ncomps == urchans % if weights are square . . .
        winv = inv(weights*sphere);
    else
        fprintf('    Using pseudo-inverse of weight matrix to rank order component projections.\n');
        winv = pinv(weights*sphere);
    end
    for s=1:ncomps
        if verbose,
            fprintf('%d ',s);         % construct single-component data matrix
        end
        % project to scalp, then add row means
        compproj = winv(:,s)*activations(s,:);
        meanvar(s) = mean(sum(compproj.*compproj)/(size(compproj,1)-1));
        % compute mean variance
    end                                         % at all scalp channels
    if verbose,
        fprintf('\n');
    end
    %
    %%%%%%%%%%%%%% Sort components by mean variance %%%%%%%%%%%%%%%%%%%%%%%%
    %
    [sortvar, windex] = sort(meanvar);
    windex = windex(ncomps:-1:1); % order large to small
    meanvar = meanvar(windex);
    %
    %%%%%%%%%%%%%%%%%%%%% Filter data using final weights %%%%%%%%%%%%%%%%%%
    %
    if nargout>2, % if activations are to be returned
        if verbose,
            fprintf('Permuting the activation wave forms ...\n');
        end
        activations = activations(windex,:);
    else
        clear activations
    end
    weights = weights(windex,:);% reorder the weight matrix
    bias  = bias(windex);		% reorder them
    signs = diag(signs);        % vectorize the signs matrix
    signs = signs(windex);      % reorder them

else
    fprintf('Components not ordered by variance.\n');
end


%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% end %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
if verbose
    waitbar(1,h)
    close(h);
end
return

if nargout > 6
    u=weights*data + bias*ones(1,frames);
    y = zeros(size(u));
    for c=1:chans
        for f=1:frames
            y(c,f) = 1/(1+exp(-u(c,f)));
        end
    end
end

% posact() - Make runica() activations all RMS-positive.
%            Adjust weights and inverse weight matrix accordingly.
%
% Usage: >> [actout,winvout,weightsout] = posact(data,weights,sphere) 
%
% Inputs:
%    data        = runica() input data
%    weights     = runica() weights
%    sphere      = runica() sphere {default|0 -> eye()}
%
% Outputs:
%    actout      = activations reoriented to be RMS-positive
%    winvout     = inv(weights*sphere) reoriented to match actout
%    weightsout  = weights reoriented to match actout (sphere unchanged)
%
% Author: Scott Makeig, SCCN/INC/UCSD, La Jolla, 11/97 

% Copyright (C) 11/97 Scott Makeig, SCCN/INC/UCSD, scott@sccn.ucsd.edu
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Log: posact.m,v $
% Revision 1.1  2002/04/05 17:36:45  jorn
% Initial revision
%

% 01-25-02 reformated help & license, added links -ad 

function [actout,winvout,weightsout] = posact(data,weights,sphere)

if nargin < 2
   help posact
   return
end
if nargin < 3
   sphere = 0;
end

[chans,frames]=size(data);
[r,c]=size(weights);
if sphere == 0
  sphere = eye(chans);
end
[sr,sc] = size(sphere);
if sc~= chans
   fprintf('posact(): Sizes of sphere and data do not agree.\n')
   return
elseif c~=sr
   fprintf('posact(): Sizes of weights and sphere do not agree.\n')
   return
end

activations = weights*sphere*data;

if r==c
  winv = inv(weights*sphere);
else
  winv = pinv(weights*sphere);
end

[rows,cols] = size(activations);

actout = activations;
winvout = winv;

fprintf('    Inverting negative activations: ');
for r=1:rows,
        pos = find(activations(r,:)>=0);
        posrms = sqrt(sum(activations(r,pos).*activations(r,pos))/length(pos));
        neg = find(activations(r,:)<0);
        negrms = sqrt(sum(activations(r,neg).*activations(r,neg))/length(neg));
        if negrms>posrms
            fprintf('-');   
            actout(r,:) = -1*activations(r,:);
            winvout(:,r) = -1*winv(:,r);
        end
        fprintf('%d ',r);
end
fprintf('\n');

if nargout>2
  if r==c,
    weightsout = inv(winvout);
  else
    weightsout = pinv(winvout);
  end
  if nargin>2 % if sphere submitted
    weightsout = weightsout*inv(sphere); % separate out the sphering
  end
end
