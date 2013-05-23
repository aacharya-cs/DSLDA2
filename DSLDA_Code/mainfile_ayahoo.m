function [] = mainfile_confdata (MAXCOUNT, MaxFun, MAXESTEPITER, MAXMSTEPITER, filename, p1, p2, p3, k2, option, troption, svmoptionval, svmcval, minvtopic, pathname, otherindex, numexp, epsilon)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% file for simulating synthetic data and checking the performance of the model on the same
% call variational_EM() directly with appropriate arguments for any other dataset
%%%%%%%%%%%
% Input:
% MAXCOUNT: maximum number of EM iteration
% MaxFun: maximum number of function evaluations for fmincon
% MAXESTEPITER: maximum number of E-step iteration
% MAXMSTEPITER: maximum number of M-step iteration
% filename: name of the file containing conference names
% p1: % of training data from source classes
% p2: % of training data from target class
% option: 1,2,3,4 -- use 4 for the model we have; 1 for unsupervised LDA, 2 for labeled LDA, 3 for Med-LDA, 5 for labeled LDA with class labels (something not proposed before)
% troption: 1 for test on training data, 0 for test on test data
% svmoptionval: should be 4 for multi-class svm
% svmcval: value of the margin error penalizer term c in svm
% pathname: path to the saved files of the form "<conference name>_train.mat" and "<conference name>_test.mat"
% otherindex: any string that distinguishes the current run from others
% minvtopic: minimum number of visual topics
%%%%%%%%%%%
% output: saved in savefilename -- look for savefilename towards end of the code
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% example input:
%% mainfile_ayahoo (2, 2, 2, 2, 'ayahoo_classnames.txt', 0.5, 0.5, 1, 10, 4, 0, 4, 1, 2, '/lusr/u/ayan/MLDisk/ayahoo_files/', '1sttry', 1, 0.8);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
format long;
warning('off');
clc;

svmperf = [];
trperf = []; 
testperf = []; 
trperfmedLDA = []; 
testperfmedLDA = [];
trperfDSLDANSLT = [];
testperfDSLDANSLT = [];
trperfDSLDAOSST = [];
testperfDSLDAOSST = [];
trperfmedLDAova = [];
testperfmedLDAova = [];

testperfDSLDANSLT.multiclassacc = 0;
testperf.multiclassacc = 0;
testperfNPDSLDA.multiclassacc = 0;
testperfmedLDA.multiclassacc = 0;
testperfDSLDAOSST.multiclassacc = 0;
testperfmedLDAova{1}.multiclassaccuracy = 0;

if(isdeployed)
    MAXCOUNT = str2num(MAXCOUNT);
    MaxFun = str2num(MaxFun);
    MAXESTEPITER = str2num(MAXESTEPITER);
    MAXMSTEPITER = str2num(MAXMSTEPITER);
    p1 = str2num(p1);
    p2 = str2num(p2);
    p3 = str2num(p3);
    k2 = str2num(k2);
    svmoptionval = str2num(svmoptionval);
    svmcval = str2num(svmcval);
    option   = str2num(option);
    troption = str2num(troption);
    minvtopic = str2num(minvtopic);
    epsilon = str2num(epsilon);
end

if(~isdeployed)
    %% these C++ files should be compiled first
    mex sum_phi.cpp;
    mex update_beta_cpp.cpp;
    mex update_phi_cpp.cpp;
    mex sum_zeta.cpp;
    mex update_lambda.cpp;
    mex update_smallphi.cpp;
    mex update_zeta.cpp; 
    addpath(genpath('/lusr/u/ayan/Documents/DSLDA_SDM/medlda/'));
    addpath(genpath('/lusr/u/ayan/Documents/DSLDA_SDM/DSLDA/liblinear-v0.1/'));
    addpath(genpath('/lusr/u/ayan/Documents/DSLDA_SDM/forconfdata/'));
    addpath(genpath('/lusr/u/ayan/Documents/DSLDA_SDM/NPDSLDA/'));
end

p    = 0.9; %(should be > 0) multiplier for Dirichlet Distribution; change this to vary initialization

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data is a structure containing the following fields:
% annotations: N*k1 binary matrix with 1 indicating presence of an annotation in a document, N indicates number of documents and k1 indicates maximum number of visible topics/annotations
% windex: an N*1 cell array with w{n} containing the indicies of the words in the vocabulary appearing in nth document.
% wcount: an N*1 cell array with w{n} containing the counts of the words in the vocabulary appearing in nth document.
% classlabels: N*1 matrix with each element indicating the class label of corresponding document
% Y: number of classes (at least one document from each of the classes should be present in the training data)
% k1: number of visible topics/annotations
% k2: number of latent topics -- note that K = k1+K2
% nwordspdoc: N*1 matrix with each element indicating the number of words in corresponding document
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% get the data in proper format
[trdata, testdata, selindex, classnames, MCMacc] = prep_ayahoo(pathname, p1, p2, p3, filename, k2, minvtopic);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%trdata
%%testdata
disp('***************SVM starts****************');
%% run SVM using the liblinear package
[svmperf] = getLiblinearperf(pathname, selindex, classnames, svmoptionval, svmcval);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% disp('***************MedLDA by Jun Zhu starts****************');
%% run SVM using the liblinear package
%% getmedLDAperf(trdata, testdata);
%% pause;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% find(trdata.classlabels==0)
%% find(testdata.classlabels==0)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('*************** medLDA-OVA starts ****************');
%% run medLDA in one-vs-all setting (with the same training and test data)
if(troption==1)  %% test on training data
    medLDAovaprobassign = zeros(length(trdata.classlabels),trdata.Y);
else
    medLDAovaprobassign = zeros(length(testdata.classlabels),testdata.Y);
end

for i=1:trdata.Y
     i
     [trdataova, testdataova] = get_medLDAovadata(trdata, testdata, i);
     [trmodelmedLDAova{i}, trperfmedLDAova{i}] = variational_EM(trdataova, MAXCOUNT, MAXESTEPITER, MAXMSTEPITER, MaxFun, p, [], 3, 1, [], epsilon, svmcval);
     if(troption==1)  %% test on training data
         testdataova = trdataova;
     end
     [testmodelmedLDAova{i}, testperfmedLDAova{i}, medLDAovaprobassign(:,i)] = InferenceOnTest(trmodelmedLDAova{i}, testdataova, MAXESTEPITER, 3, p);
end
[~, tempacc] = max(medLDAovaprobassign, [], 2);
if(troption==1)
    testperfmedLDAova{1}.multiclassaccuracy = mean(tempacc==trdata.classlabels);
else
    testperfmedLDAova{1}.multiclassaccuracy = mean(tempacc==testdata.classlabels);
end
testperfmedLDAova{1}.multiclassaccuracy
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('*************** DSLDA starts ****************');
%% run DSLDA (with the same training and test data)
[trmodel, trperf] = variational_EM(trdata, MAXCOUNT, MAXESTEPITER, MAXMSTEPITER, MaxFun, p, [], 4, 1, [], epsilon, svmcval);
if(troption==1)  %% test on training data
    testdata = trdata;
end
[testmodel, testperf] = InferenceOnTest(trmodel, testdata, MAXESTEPITER, 4, p);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % 
% % 
disp('*************** DSLDA-OSST starts ****************');
%%run labeled LDA with class labels (with the same training and test data)
[trmodelDSLDAOSST, trperfDSLDAOSST] = variational_EM (trdata, MAXCOUNT, MAXESTEPITER, MAXMSTEPITER, MaxFun, p, [], 7, 1, [], epsilon, svmcval);
if(troption==1)  %% test on training data
    testdata = trdata;
end
[testmodelDSLDAOSST, testperfDSLDAOSST] = InferenceOnTest (trmodelDSLDAOSST, testdata, MAXESTEPITER, 7, p);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('*************** DSLDA-NSLT starts ****************');
%% run labeled LDA with class labels (with the same training and test data)
[trmodelDSLDANSLT, trperfDSLDANSLT] = variational_EM(trdata, MAXCOUNT, MAXESTEPITER, MAXMSTEPITER, MaxFun, p, [], 5, 1, [], epsilon, svmcval);
if(troption==1)  %% test on training data
     testdata = trdata;
end
[testmodelDSLDANSLT, testperfDSLDANSLT] = InferenceOnTest(trmodelDSLDANSLT, testdata, MAXESTEPITER, 5, p);
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('*************** medLDA-MTL starts ****************');
%% run medLDA with all the classes together (with the same training and test data)
[trmodelmedLDA, trperfmedLDA] = variational_EM(trdata, MAXCOUNT, MAXESTEPITER, MAXMSTEPITER, MaxFun, p, [], 3, 1, [], epsilon, svmcval);
if(troption==1)  %% test on training data
     testdata = trdata;
end
[testmodelmedLDA, testperfmedLDA] = InferenceOnTest(trmodelmedLDA, testdata, MAXESTEPITER, 3, p);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% modify this pathname and filename if you are running on/off condor

dirdate = date;
dirdate = regexprep(dirdate, '-', '_');
dirname = ['/lusr/u/ayan/MLDisk/ayahoo_' dirdate];
if(exist(dirname, 'dir')==0)
    system(['mkdir ' dirname]);
end
savepath = [dirname '/'];
savefilename = [savepath classnames{end} '_' num2str(minvtopic) '_' num2str(p1) '_' num2str(p2) '_' num2str(p3) '_' num2str(k2) '_' num2str(option) '_' num2str(troption) '_' num2str(svmoptionval)  '_' num2str(epsilon)];
savefilename = [savefilename '_' num2str(svmcval) '_' otherindex '_' num2str(numexp) '.mat'];
save(savefilename, 'svmperf', 'trperf', 'testperf', 'trperfmedLDA', 'testperfmedLDA', 'trperfDSLDANSLT', 'testperfDSLDANSLT', 'trperfmedLDAova', 'testperfmedLDAova', 'trperfDSLDAOSST', 'testperfDSLDAOSST');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
svmacc = sum(diag(svmperf.confmat_test))/sum(sum(svmperf.confmat_test));
B = [MCMacc*100 svmacc*100 testperfmedLDAova{1}.multiclassaccuracy*100];
B = [B testperfmedLDA.multiclassacc];
B = [B testperfDSLDAOSST.multiclassacc];
B = [B testperfDSLDANSLT.multiclassacc testperf.multiclassacc testperfNPDSLDA.multiclassacc];
% %
models = {'MCM', 'SVM', 'OVA', 'MTL', 'OSST', 'NSLT', 'DSLDA', 'NPDSLDA'};
for i=1:8
    str{i,1} = [models{i} ':' num2str(B(i))];
end

disp(str)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('**********experiments done********');

end

