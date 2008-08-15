function [files_in,files_out,opt] = niak_brick_component_sel(files_in,files_out,opt)
%
% _________________________________________________________________________
% SUMMARY NIAK_BRICK_COMPONENT_SEL
%
% Select independent components based on spatial priors.
%
% [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_COMPONENT_SEL(FILES_IN,FILES_OUT,OPT)
%
% _________________________________________________________________________
% INPUTS
%
%  * FILES_IN  
%       (structure) with the following fields :
%
%       FMRI 
%           (string) the original fMRI 3D+t data
%
%       COMPONENT 
%           (string) a 2D text array with the temporal distribution of sICA.
%
%       MASK 
%           (string) a path to a binary mask (the spatial a priori).
%
%       TRANSFORMATION 
%           (string, default identity) a transformation from the functional 
%           space to the mask space.
%
%  * FILES_OUT 
%       (string, default <base COMPONENT>_<base MASK>_compsel.dat) A text 
%       file. First column gives the numbers of the selected components in 
%       the order of selection, and the second column gives the score of selection.
%
%  * OPT   
%       (structure) with the following fields :
%
%       NB_CLUSTER 
%           (default 0). The number of spatial clusters used in stepwise 
%           regression. If NB_CLUSTER == 0, the number of clusters is set 
%           to (nb_vox/10), where nb_vox is the number of voxels in the 
%           region.
%
%       P 
%           (real number, 0<P<1, default 0.001) the p-value of the stepwise
%           regression.
%
%       NB_SAMPS 
%           (default 10) the number of kmeans repetition.
%
%       TYPE_SCORE 
%           (string, default 'freq') Score function. 'freq' for the
%           frequency of selection of the regressor and 'inertia' for the
%           relative part of inertia explained by the clusters "selecting"
%           the regressor.
%
%       FOLDER_OUT 
%           (string, default: path of FILES_IN.SPACE) If present,
%           all default outputs will be created in the folder FOLDER_OUT.
%           The folder needs to be created beforehand.
%
%       FLAG_VERBOSE 
%           (boolean, default 1) gives progression infos
%
%       FLAG_TEST 
%           (boolean, default 0) if FLAG_TEST equals 1, the
%           brick does not do anything but update the default
%           values in FILES_IN, FILES_OUT and OPT.
%
% _________________________________________________________________________
% OUTPUTS
%
% The structures FILES_IN, FILES_OUT and OPT are updated with default
% valued. If OPT.FLAG_TEST == 0, the specified outputs are written.
%
% _________________________________________________________________________
% COMMENTS
%
% This brick is using multiple functions from the SICA toolbox, developped
% by Vincent Perlbarg, LIF Inserm U678, Faculte de medecine
% Pitie-Salpetriere, Universite Pierre et Marie Curie, France.
% E-mail: Vincent.Perlbarg@imed.jussieu.fr
%
% _________________________________________________________________________
% Copyright (c) Pierre Bellec, McConnell Brain Imaging Center,
% Montreal Neurological Institute, McGill University, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : pipeline, niak, preprocessing, fMRI

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

niak_gb_vars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Seting up default arguments %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('files_in','var')|~exist('files_out','var')|~exist('opt','var')
    error('niak:brick','syntax: [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_COMPONENT_SEL(FILES_IN,FILES_OUT,OPT).\n Type ''help niak_brick_component_sel'' for more info.')
end

%% Input files
gb_name_structure = 'files_in';
gb_list_fields = {'fmri','component','mask','transformation'};
gb_list_defaults = {NaN,NaN,NaN,'gb_niak_omitted'};
niak_set_defaults

%% Output file
if ~ischar(files_out)
    error('FILES_OUT should be a string !');
end

%% Options
gb_name_structure = 'opt';
gb_list_fields = {'ww','nb_cluster','p','nb_samps','type_score','flag_verbose','flag_test','folder_out'};
gb_list_defaults = {0,0,0.001,10,'freq',1,0,''};
niak_set_defaults

%% Parsing the input names
[path_s,name_s,ext_s] = fileparts(files_in.component(1,:));
if isempty(path_s)
    path_s = '.';
end

if strcmp(ext_s,gb_niak_zip_ext)
    [tmp,name_s,ext_s] = fileparts(name_s);
    ext_s = cat(2,ext_s,gb_niak_zip_ext);
end

[path_m,name_m,ext_m] = fileparts(files_in.mask(1,:));
if isempty(path_m)
    path_m = '.';
end

if strcmp(ext_m,gb_niak_zip_ext)
    [tmp,name_m,ext_m] = fileparts(name_m);
    ext_m = cat(2,ext_m,gb_niak_zip_ext);
end

%% Setting up default output
if isempty(opt.folder_out)
    opt.folder_out = path_s;
end

if isempty(files_out)
    files_out = cat(2,opt.folder_out,filesep,name_s,'_',name_m,'_compsel.dat');
end

if ~strcmp(opt.type_score,'freq')&~strcmp(opt.type_score,'inertia')
    error(sprintf('%s is an unknown score function type',opt.type_score));
end

if flag_test == 1
    return
end

%%%%%%%%%%%%%%%%%%%%
%% Reading inputs %%
%%%%%%%%%%%%%%%%%%%%

%% Mask of interest
if flag_verbose
    fprintf('Reading (and eventually resampling) the mask of interest ...\n');
end

file_mask_tmp = niak_file_tmp('_mask_roi.mnc');
if strcmp(files_in.transformation,'gb_niak_omitted');
    instr_res = sprintf('mincresample %s %s -clobber -like %s -nearest_neighbour',files_in.mask,file_mask_tmp,files_in.fmri);
else
    instr_res = sprintf('mincresample %s %s -clobber -like %s -nearest_neighbour -transform %s -invert_transformation',files_in.mask,file_mask_tmp,files_in.fmri,files_in.transformation);
end

if flag_verbose
    system(instr_res)
else
    [succ,msg] = system(instr_res);
    if succ~=0
        error(masg);
    end
end
[hdr_roi,mask_roi] = niak_read_vol(file_mask_tmp);
mask_roi = mask_roi>0.9;
delete(file_mask_tmp);


%% Extracting time series in the mask
if flag_verbose
    fprintf('Extracting time series in the mask ...\n');
end
[hdr_func,vol_func] = niak_read_vol(files_in.fmri);
mask_roi = mask_roi & niak_mask_brain(mean(abs(vol_func),4));
tseries_roi = niak_build_tseries(vol_func,mask_roi);
[nt,nb_vox] = size(tseries_roi);
clear vol_func

%% Temporal sica components
A = load(files_in.component);
nb_comp = size(A,2);

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  Stepwise regression %%
%%%%%%%%%%%%%%%%%%%%%%%%%%

if flag_verbose
    fprintf('\n*********\nPerforming stepwise regression\n*********\n\n');
end

if nb_vox == 0
    
    %% There is no functional data in the mask, no component is selected...
    num_comp = 1:nb_comp;
    score = zeros(size(num_comp));
    
else

    %% Selecting number of spatial classes
    if nb_cluster == 0
        nb_cluster = floor(nb_vox/10); % default value for the number of clusters.
        opt.nb_cluster = nb_cluster;
    end

    %% Computing score and score significance
    sigs{1} = niak_correct_mean_var(tseries_roi,'mean_var');
    tseries_ica = niak_correct_mean_var(A,'mean_var');
    [intersec,selecVector,selecInfo] = st_automatic_selection(sigs,tseries_ica,opt.p,opt.nb_samps,opt.nb_cluster,opt.type_score,0,'off');

    %% Reordering scores
    [score,num_comp] = sort(selecVector',1,'descend');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Writting the results of component selection %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[hf,msg] = fopen(files_out,'w');

if hf == -1
    error(msg);
end

for num_l = 1:length(score)
    fprintf(hf,'%i %1.12f \n',num_comp(num_l),score(num_l));
end

fclose(hf)