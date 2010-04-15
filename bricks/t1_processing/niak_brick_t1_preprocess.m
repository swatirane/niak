function [files_in,files_out,opt] = niak_brick_t1_preprocess(files_in,files_out,opt)
%
% _________________________________________________________________________
% SUMMARY NIAK_BRICK_T1_PREPROCESS
%
% Linear and non-linear coregistration of a T1 brain volume in the MNI 
% stereotaxic space, along with various preprocessing (non-uniformity
% correction, intensity normalization, brain extraction) and tissue
% classification. 
%
% SYNTAX:
% [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_T1_PREPROCESS(FILES_IN,FILES_OUT,OPT)
%
% _________________________________________________________________________
% INPUTS:
%
%   FILES_IN        
%       (string) the file name of a T1 volume.
%
%   FILES_OUT  
%       (structure) with the following fields. Note that if a field is an 
%       empty string, a default value will be used to name the outputs. If 
%       a field is ommited, the output won't be saved at all (this is 
%       equivalent to setting up the output file names to 
%       'gb_niak_omitted').
%
%
%       TRANSFORMATION_LIN 
%           (string, default <BASE_ANAT>_native2stereolin.xfm)
%           Linear transformation from native to stereotaxic space (lsq9).
%
%       TRANSFORMATION_NL 
%           (string, default <BASE_ANAT>_stereolin2stereonl.xfm)
%           Non-linear transformation from linear stereotaxic space to
%           non-linear stereotaxic space.
%
%       TRANSFORMATION_NL_GRID 
%           (string, default <BASE_ANAT>_stereolin2stereonl_grid.mnc)
%           Deformation field for the non-linear transformation.
%
%       ANAT_NUC 
%           (string, default <BASE_ANAT>_nuc_native.<EXT>)
%           t1 image partially corrected for non-uniformities (without
%           mask), in native space. Intensities have not been normalized.
%       
%       ANAT_NUC_STEREO_LIN 
%           (string, default <BASE_ANAT>_nuc_stereolin.<EXT>)
%           original t1 image transformed in stereotaxic space using the 
%           lsq9 transformation, fully corrected for non-uniformities (with mask)
%           and with intensities normalized to match the MNI template.
%
%       ANAT_NUC_STEREO_NL 
%           (string, default <BASE_ANAT>_nuc_stereonl.<EXT>)
%           original t1 image transformed in stereotaxic space using the 
%           non-linear transformation, fully corrected for non-uniformities (with
%           mask) and with intensities normalized to match the MNI template.
%       
%       MASK_NATIVE
%           (string, default <BASE_ANAT>_mask_native.<EXT>)
%           brain mask in native space.
%
%       MASK_STEREOLIN 
%           (string, default <BASE_ANAT>_mask_stereolin.<EXT>)
%           brain mask in stereotaxic (linear) space.
%
%       CLASSIFY 
%           (string, default <BASE_ANAT>_classify_stereolin.<EXT>)
%           final masked discrete tissue classification in stereotaxic
%           (linear) space.
%
%   OPT           
%       (structure) with the following fields:
%
%       N3_DISTANCE 
%           (real number, default 200 mm)  N3 spline distance in mm 
%           (suggested values: 200 for 1.5T scan; 50 for 3T scan). 
%
%       FLAG_VERBOSE 
%           (boolean, default: 1) If FLAG_VERBOSE == 1, write
%           messages indicating progress.
%
%       FLAG_TEST 
%           (boolean, default: 0) if FLAG_TEST equals 1, the brick does not 
%           do anything but update the default values in FILES_IN, 
%           FILES_OUT and OPT.
%
%       FOLDER_OUT 
%           (string, default: path of FILES_IN) If present, all default 
%           outputs will be created in the folder FOLDER_OUT. The folder 
%           needs to be created beforehand.
%               
% _________________________________________________________________________
% OUTPUT:
%
% The structures FILES_IN, FILES_OUT and OPT are updated with default
% valued. If OPT.FLAG_TEST == 0, the specified outputs are written.
%
% _________________________________________________________________________
% SEE ALSO:
% NIAK_BRICK_MASK_BRAIN_T1, NIAK_BRICK_NU_CORRECT,
% NIAK_BRICK_ANAT2STEREOLIN, NIAK_BRICK_ANAT2STEREONL,
% NIAK_BRICK_NU_CORRECT, NIAK_BRICK_INORMALIZE, NIAK_BRICK_CLASSIFY
%
% _________________________________________________________________________
% COMMENTS:
%
% NOTE 1:
%   This is essentially a NIAKified version of a small subpart of the CIVET
%   pipeline developed in the lab of Alan C. Evans, see :
%   http://wiki.bic.mni.mcgill.ca/index.php/CIVET
%   Claude Lepage, Andrew Janke and Patrick Bermudez gave precious
%   directions to NIAKify this part of the pipeline.
%   Many other people were and are still involved in the development of 
%   CIVET, including Yasser Ad-Dab'bagh, Jason Lerch and Oliver Lyttelton. 
%   See the CIVET webpage for a detailed list of contributions. 
%
% NOTE 2:
%   This brick is based on all the bricks listed in the "see also" section
%   above. Please see the help of these bricks for more details. Two PERL
%   scripts are also used and distributed with NIAK (NIAK_BESTLINREG.PL and
%   NIAK_BEST1STEPNL.PL). These scripts do not follow the MIT license 
%   typically found in NIAK. See the PERL scripts code for license 
%   information (it is a BSD-like license similar to what is used in most 
%   minc tools). 
%
% NOTE 3: 
%   Almost all of the work here (except for the brain extraction) is done
%   by a package called MINC tools that needs to be installed for NIAK to
%   work properly : 
%   http://en.wikibooks.org/wiki/MINC
%   Coregistration in particular is powered by MINCTRAC and the MNI-AUTOREG
%   package by L. Collins and coll :
%   http://en.wikibooks.org/wiki/MINC/Tools/mni_autoreg
%
% NOTE 4:
%   The flowchart of the brick is as follows :
%       2.  Non-uniformity correction in native space (without mask):
%           NIAK_BRICK_NU_CORRECT
%       1.  Brain extraction in native space:
%           NIAK_BRICK_MASK_BRAIN_T1
%       3.  Linear coregistration in stereotaxic space.
%           NIAK_BRICK_ANAT2STEREOLIN
%       4.  Non-uniformity correction based on the template mask
%           NIAK_BRICK_NU_CORRECT
%       5.  Brain extraction, combined with the template mask
%           NIAK_BRICK_MASK_BRAIN_T1
%       6.  Intensity normalization
%           NIAK_BRICK_INORMALIZE
%       7.  Non-linear coregistration in template space
%           NIAK_BRICK_ANAT2STEREONL
%       8.  Tissue classification
%           NIAK_BRICK_CLASSIFY
%
% NOTE 5:
%   The template is the so-called "mni-models_icbm152-nl-2009-1.0"
%   by Louis Collins, Vladimir Fonov and Andrew Janke. 
%   A small subset of this package is bundled in NIAK.
%   See the AUTHORS, COPYING and README files in the 
%   ~niak/template/mni-models_icbm152-nl-2009-1.0 
%   folder for details about authorship and license information (it is a 
%   BSD-like license similar to what is used in most minc tools). 
%   More infos can be found on the web :
%   http://www.bic.mni.mcgill.ca/ServicesAtlases/HomePage
%
% _________________________________________________________________________
% REFERENCES:
%
%   Regarding linear and non-linear coregistration :
%
%   D. L. Collins, P. Neelin, T. M. Peters and A. C. Evans, 
%   ``Automatic 3D Inter-Subject Registration of MR Volumetric Data in 
%   Standardized Talairach Space, Journal of Computer Assisted Tomography, 
%   18(2) pp192-205, 1994.
%
%   Collins, D.L. Evans, A.C. (1997). "ANIMAL: Validation and Applications
%   of Non-Linear Registration-Based Segmentation". "International Journal 
%   of Pattern Recognition and Artificial Intelligence", vol. 11, 
%   pp. 1271-1294.
%
%   Regarding the ICBM MNI non-linear template :
%
%   VS Fonov, AC Evans, RC McKinstry, CR Almli and DL Collins Unbiased
%   nonlinear average age-appropriate brain templates from birth to 
%   adulthood NeuroImage, Volume 47, Supplement 1, July 2009, Page S102 
%   Organization for Human Brain Mapping 2009 Annual Meeting 
%
%   Regarding the pipeline flowchart :
%
%   Zijdenbos, A.P., Forghani, R., and Evans, A.C. (2002). "Automatic
%   Pipeline Analysis of 3-D MRI Data for Clinical Trials: Application to 
%   Multiple Sclerosis". IEEE TRANSACTIONS ON MEDICAL IMAGING 21, 
%   pp. 1280-1291.
%
%   Regarding non-uniformity correction :
%
%   Sled, J.G., Zijdenbos, A.P., and Evans, A.C. (1998). "A Nonparametric
%   Method for Automatic Correction of Intensity Nonuniformity in MRI 
%   Data". IEEE Transactions on Medical Imaging 17, pp. 87-97.
%
%   Regarding brain extraction :
%
%   J. G. Park & C. Lee (2009). `Skull stripping based on region growing 
%   for magnetic resonance brain images'. NeuroImage 47(4):1394-1407.
%
%   Regarding brain tissue classification :
%
%   Tohka, J., Zijdenbos, A., and Evans, A.C. (2004). "Fast and robust
%   parameter estimation for statistical partial volume models in brain 
%   MRI". NeuroImage, 23(1), pp. 84-97.
%
%   More relevant references can be found here :
%   http://wiki.bic.mni.mcgill.ca/index.php/CIVETReferences
%
% Copyright (c) Pierre Bellec, McConnell Brain Imaging Center, 
% Montreal Neurological Institute, McGill University, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : medical imaging, T1, template, classification, coregistration,
% non-uniformities correction, brain extraction

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

%% SYNTAX
if ~exist('files_in','var')|~exist('files_out','var')|~exist('opt','var')
    error('SYNTAX: [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_T1_PREPROCESS(FILES_IN,FILES_OUT,OPT).\n Type ''help niak_brick_civet'' for more info.')
end

%% FILES_IN
if ~ischar(files_in)
    error('FILES_IN should be a string !\n')
end

%% FILES_OUT
gb_name_structure = 'files_out';
gb_list_fields = {'transformation_lin','transformation_nl','transformation_nl_grid','anat_nuc','anat_nuc_stereo_lin','anat_nuc_stereo_nl','mask_native','mask_stereolin','classify'};
gb_list_defaults = {'gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted','gb_niak_omitted'};
niak_set_defaults

%% OPTIONS
gb_name_structure = 'opt';
gb_list_fields = {'flag_test','folder_out','flag_verbose','n3_distance'};
gb_list_defaults = {0,'',1,200};
niak_set_defaults

%% Building default output names
[path_anat,name_anat,ext_anat] = fileparts(files_in.anat);

if isempty(path_anat)
    path_anat = '.';
end

if strcmp(ext_anat,gb_niak_zip_ext)
    [tmp,name_anat,ext_anat] = fileparts(name_anat);
    ext_anat = cat(2,ext_anat,gb_niak_zip_ext);
end

if isempty(opt.folder_out)
    folder_anat = path_anat;
else
    folder_anat = opt.folder_out;
end

if strcmp(files_out.transformation_lin,'')
    files_out.transformation_lin = cat(2,folder_anat,name_anat,'_native2stereolin.xfm');
end

if strcmp(files_out.transformation_nl,'')
    files_out.transformation_nl = cat(2,folder_anat,name_anat,'_stereolin2stereonl.xfm');
end

if strcmp(files_out.transformation_nl_grid,'')
    files_out.transformation_nl_grid = cat(2,folder_anat,name_anat,'_stereolin2stereonl_grid.mnc');
end

if strcmp(files_out.anat_nuc,'')
    files_out.anat_nuc = cat(2,folder_anat,name_anat,'_nuc_native',ext_anat);
end

if strcmp(files_out.anat_nuc_stereo_lin,'')
    files_out.anat_nuc_stereo_lin = cat(2,folder_anat,name_anat,'_nuc_stereolin',ext_anat);
end

if strcmp(files_out.anat_nuc_stereo_nl,'')
    files_out.anat_nuc_stereo_nl = cat(2,folder_anat,name_anat,'_nuc_stereonl',ext_anat);
end

if strcmp(files_out.mask_native,'')
    files_out.mask = cat(2,folder_anat,name_anat,'_mask_native',ext_anat);
end

if strcmp(files_out.mask_stereo,'')
    files_out.mask_stereo = cat(2,folder_anat,name_anat,'_mask_stereolin',ext_anat);
end

if strcmp(files_out.classify,'')
    files_out.classify = cat(2,folder_anat,name_anat,'_classify_stereolin',ext_anat);
end

if flag_test == 1
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The brick starts here %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

if flag_verbose
    fprintf('***********************************\nPreprocessing of a T1 brain volume\n***********************************\n');
    fprintf('Original brain volume : %s\n',files_in);
end


%% Generate template file names
% The T1 non-linear average
file_template = [gb_niak_path_niak 'template' filesep 'mni-models_icbm152-nl-2009-1.0' filesep 'mni_icbm152_t1_tal_nlin_sym_09a.mnc.gz'];
% The brain mask
file_template_mask = [gb_niak_path_niak 'template' filesep 'mni-models_icbm152-nl-2009-1.0' filesep 'mni_icbm152_t1_tal_nlin_sym_09a_mask.mnc.gz'];
% The brain mask eroded of 5 mm
file_template_mask_erode = [gb_niak_path_niak 'template' filesep 'mni-models_icbm152-nl-2009-1.0' filesep 'mni_icbm152_t1_tal_nlin_sym_09a_mask_eroded5mm.mnc.gz'];
% The brain mask dilated of 5 mm
file_template_mask_dilate = [gb_niak_path_niak 'template' filesep 'mni-models_icbm152-nl-2009-1.0' filesep 'mni_icbm152_t1_tal_nlin_sym_09a_mask_dilated5mm.mnc.gz'];

%% Generate temporary file names

path_tmp = niak_path_tmp('_',name_anat,'t1_preprocess');

anat_stereolin_raw = [path_tmp,name_anat,'_raw_stereolin' ext_anat];

anat_stereolin_nu = [path_tmp,name_anat,'_nu_stereolin' ext_anat];

anat_stereolin_mask = [path_tmp,name_anat,'_mask_stereolin' ext_anat];

if strcmp(files_out.transformation_lin,'gb_niak_omitted')
    files_out.transformation_lin = cat(2,path_tmp,name_anat,'_native2stereolin.xfm');
end

if strcmp(files_out.transformation_nl,'gb_niak_omitted')
    files_out.transformation_nl = cat(2,path_tmp,name_anat,'_stereolin2stereonl.xfm');
end

if strcmp(files_out.transformation_nl_grid,'gb_niak_omitted')
    files_out.transformation_nl_grid = cat(2,path_tmp,name_anat,'_stereolin2stereonl_grid.mnc');
end

if strcmp(files_out.anat_nuc,'gb_niak_omitted')
    files_out.anat_nuc = cat(2,path_tmp,name_anat,'_nuc_native',ext_anat);
end

if strcmp(files_out.anat_nuc_stereo_lin,'gb_niak_omitted')
    files_out.anat_nuc_stereo_lin = cat(2,path_tmp,name_anat,'_nuc_stereolin',ext_anat);
end

if strcmp(files_out.anat_nuc_stereo_nl,'gb_niak_omitted')
    files_out.anat_nuc_stereo_nl = cat(2,path_tmp,name_anat,'_nuc_stereonl',ext_anat);
end

if strcmp(files_out.mask_native,'gb_niak_omitted')
    files_out.mask = cat(2,path_tmp,name_anat,'_mask_native',ext_anat);
end

if strcmp(files_out.mask_stereo,'gb_niak_omitted')
    files_out.mask_stereo = cat(2,path_tmp,name_anat,'_mask_stereolin',ext_anat);
end

if strcmp(files_out.classify,'gb_niak_omitted')
    files_out.classify = cat(2,path_tmp,name_anat,'_classify_stereolin',ext_anat);
end


%% Apply non-uniformity correction
if flag_verbose
    fprintf('\n\n\n**********\nNon-uniformity correction in native space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp.t1 = files_in;
files_out_tmp.t1_nu = files_out.anat_nuc;
opt_tmp.arg = ['-distance ' num2str(opt.n3_distance)];
opt_tmp.flag_test = false;
niak_brick_nu_correct(files_in_tmp,files_out_tmp,opt_tmp);

%% Derive a mask of the brain
if flag_verbose
    fprintf('\n\n\n**********\nExtracting a mask of the brain in native space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp = files_out.anat_nuc;
files_out_tmp = files_out.mask_native;
opt_tmp.flag_test = false;
niak_brick_mask_brain_t1(files_in_tmp,files_out_tmp,opt_tmp);

%% Run a linear coregistration in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nLinear coregistration in stereotaxic space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp.t1 = files_out.anat_nuc;
files_in_tmp.t1_mask = files_out.mask_native;
files_out_tmp.transformation = files_in.transformation_lin;
files_out_tmp.t1_stereolin = anat_stereolin_raw;
opt_tmp.flag_test = false;
niak_brick_anat2stereolin(files_in_tmp,files_out_tmp,opt_tmp);

%% Apply non-uniformity correction in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nNon-uniformity correction in stereotaxic space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp.t1 = anat_stereolin_raw;
files_in_tmp.mask = file_template_mask_erode;
files_out_tmp.t1_nu = anat_stereolin_nu;
opt_tmp.arg = ['-distance ' num2str(opt.n3_distance)];
opt_tmp.flag_test = false;
niak_brick_nu_correct(files_in_tmp,files_out_tmp,opt_tmp);

%% Derive a mask of the brain in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nExtracting a mask of the brain in stereotaxic space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp = anat_stereolin_nu;
files_out_tmp = anat_stereolin_mask;
opt_tmp.flag_test = false;
niak_brick_mask_brain_t1(files_in_tmp,files_out_tmp,opt_tmp);

% Combine the mask with the template masks
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp{1} = anat_stereolin_mask;
files_in_tmp{2} = file_template_mask_erode;
files_in_tmp{3} = file_template_mask_dilate;
files_out_tmp = files_out.mask_stereolin;
opt_tmp.flag_test = false;
opt_tmp.operation = 'vol = vol_in{1}; vol(vol_in{2}>0) = 1; vol(vol_in{3}==0) = 0;';
niak_brick_math_vol(files_in_tmp,files_out_tmp,opt_tmp);

%% Run intensity normalization in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nIntensity normalization in stereotaxic space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp.vol = anat_stereolin_nu;
files_in_tmp.model = file_template;
files_out_tmp = files_out.anat_nuc_stereolin;
opt_tmp.flag_test = false;
niak_brick_mask_brain_t1(files_in_tmp,files_out_tmp,opt_tmp);


%% Run tissue classification in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nClassification into tissue types ...\n');
end
instr_classify = ['classify ' files_out.anat_nuc_stereolin files_out.classify];
[status,msg] = system(instr_classify);
if status~=0
    error('Classification into tissue types failed with the following error message : %s',msg);
end

%% Run a non-linear coregistration in stereotaxic space
if flag_verbose
    fprintf('\n\n\n**********\nNon-linear coregistration in stereotaxic space ...\n');
end
clear files_in_tmp files_out_tmp opt_tmp
files_in_tmp.t1 = files_out.anat_nuc_stereolin;
files_in_tmp.t1_mask = files_out.mask_stereolin;
files_out_tmp.transformation = files_out.transformation_stereonl;
files_out_tmp.t1_stereonl = files_out.anat_nuc_stereonl;
opt_tmp.flag_test = false;
niak_brick_anat2stereonl(files_in_tmp,files_out_tmp,opt_tmp);