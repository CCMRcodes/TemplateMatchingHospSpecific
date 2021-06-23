libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/with labs/larger template/Redone September2019";
libname p "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power";

/*data p.power_calcs1;*/
/*if _n_=1 then delete;*/
/*run;*/
/*data p.power_calcs2;*/
/*if _n_=1 then delete;*/
/*run;*/

%macro sample(n, beta, matches);

data sample;
call streaminit(65432168732);
	do sample=1 to 1000;
		do template_id=1 to &n.;
			logpred=rand("normal", -4.2983, 1.4559);
			pred=exp(logpred);
		do hospital=1 to &matches.;
			if hospital=1 then case=1;else case=0;
				eta=-4.4+11.8*pred+&beta.*case;
				mu=exp(eta)/(1+exp(eta));
				mort30=rand("Bernoulli", mu);
				output;
			end;
		end;
	end;
run;

%macro loop;
%do sample=560 %to 1000;

ods exclude all;
ods output parameterestimates=fixed1;
proc glimmix data=sample method=laplace noclprint;
where sample=&sample.;
class template_id;
model mort30 (descending)= case pred /  link=logit dist=binomial  solution cl or;
random intercept /sub= template_id solution cl  g;
run;
ods exclude none;

data fixed1;
set fixed1;
	beta=&beta.;
	matches=%sysevalf(&matches.-1);
	template_size=&n.;
	sample=&sample.;
run;

data fixed1;
set fixed1;
where effect="case";
if probt>0.05 then sig=0;
else sig=1;
run;

data p.power_calcs1;
set p.power_calcs1 fixed1;
run;

/*model with a random intercept for hospital and a random intercept for template id(i.e. like Model 2)*/
ods exclude all;
ods output parameterestimates=fixed2;
proc glimmix data=sample method=laplace noclprint;
where sample=&sample.;
class hospital template_id;
model mort30 (descending)= case pred /  link=logit dist=binomial  solution cl or;
random intercept /sub= hospital solution cl  g;
random intercept /sub= template_id solution cl  g;
run;
ods exclude none;

data fixed2;
set fixed2;
	sample=&sample.;
	beta=&beta.;
	matches=%sysevalf(&matches.-1);
	template_size=&n.;
run;

data fixed2;
set fixed2;
where effect="case";
if probt>0.05 then sig=0;
else sig=1;
run;

data p.power_calcs2;
set p.power_calcs2 fixed2;
run;

%end;
%mend;
%loop;
%mend;

/*%sample(500, .29, 6);*/
/*%sample(500, .51, 6);*/
/*%sample(500, .69, 6);*/
/*%sample(500, .85, 6);*/
/*%sample(500, .29, 37);*/
/*%sample(500, .51, 37);*/
/*%sample(500, .69, 37);*/
/*%sample(500, .85, 37);*/
/*%sample(500, .29, 61);*/
/*%sample(500, .51, 61);*/
/*%sample(500, .69, 61);*/
/*%sample(500, .85, 61);*/

/*%sample(300, .29, 6);*/
/*%sample(300, .51, 6);*/
/*%sample(300, .69, 6);*/
/*%sample(300, .85, 6);*/
/*%sample(300, .29, 37);*/
/*%sample(300, .51, 37);*/
/*%sample(300, .69, 37); */
/*%sample(300, .85, 37);*/
/*%sample(300, .29, 61);*/
/*%sample(300, .51, 61);*/
/*%sample(300, .69, 61);*/
/*%sample(300, .85, 61);*/
/**/
/*%sample(600, .29, 6);*/
/*%sample(600, .51, 6);*/
/*%sample(600, .69, 6);*/
/*%sample(600, .85, 6);*/
/*%sample(600, .29, 37);*/
/*%sample(600, .51, 37);*/
/*%sample(600, .69, 37);*/
/*%sample(600, .85, 37);*/
/*%sample(600, .29, 61);*/
/*%sample(600, .51, 61);*/
/*%sample(600, .69, 61);*/
/*%sample(600, .85, 61);*/
/**/
data p.power_calcs1;
set p.power_calcs1 p.power_calcs1b p.power_calcs1c p.power_calcs1d 
p.power_calcs1e p.power_calcs1f p.power_calcs1g p.power_calcs1h 
p.power_calcs1i p.power_calcs1j p.power_calcs1k p.power_calcs1l
p.power_calcs1m p.power_calcs1n p.power_calcs1o;
run;

data p.power_calcs2;
set p.power_calcs2 p.power_calcs2a p.power_calcs2b p.power_calcs2c p.power_calcs2d
p.power_calcs2e p.power_calcs2f p.power_calcs2g p.power_calcs2h
p.power_calcs2i p.power_calcs2j p.power_calcs2k p.power_calcs2l
p.power_calcs2m p.power_calcs2n p.power_calcs2o;
run;

proc sort data=p.power_calcs1 nodupkey; by template_size matches beta sample; run;
proc sort data=p.power_calcs2 nodupkey; by template_size matches beta sample; run;

ods exclude none;
proc freq data=p.power_calcs1;
by template_size;
table matches*beta*sig/nocol norow nopercent;
run;

proc freq data=p.power_calcs2;
by template_size;
table matches*beta*sig/nocol norow nopercent;
run;



proc sql;
create table power as
select template_size, matches, beta, mean(sig) as power
from p.power_calcs1
group by template_size, matches, beta;
quit;

data power;
set power;
if beta=0.29 then SMR=1.33;
if beta=0.51 then SMR=1.67;
if beta=0.69 then SMR=2.0;
if beta=0.85 then SMR=2.33;
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/reset=index  aTTRPRIORITY=none imagefmt=tiff imagename='Model 1 Template size vs. number of matches';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= template_size group=matches;
xaxis label="Template Size";
yaxis label="Number of Matches";
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/reset=index  aTTRPRIORITY=none imagefmt=tiff imagename='Model 1 SMR vs. Template size';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= SMR group=template_size;
xaxis label="Standardized Mortality Ratio";
yaxis label="Template Size";
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/reset=index  aTTRPRIORITY=none imagefmt=tiff imagename='Model 1 SMR vs. number of matches';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= SMR group=matches;
xaxis label="Standardized Mortality Ratio";
yaxis label="Number of Matches";
run;

proc sql;
create table power as
select template_size, matches, beta, mean(sig) as power
from p.power_calcs2
group by template_size, matches, beta;
quit;

data power;
set power;
if beta=0.29 then SMR=1.33;
if beta=0.51 then SMR=1.67;
if beta=0.69 then SMR=2.0;
if beta=0.85 then SMR=2.33;
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/ reset=index aTTRPRIORITY=none imagefmt=tiff imagename='Model 2 Template size vs. number of matches';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= template_size group=matches;
xaxis label="Template Size";
yaxis label="Number of Matches";
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/reset=index  aTTRPRIORITY=none imagefmt=tiff imagename='Model 2 SMR vs. Template size';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= SMR group=template_size;
xaxis label="Standardized Mortality Ratio";
yaxis label="Template Size";
run;

ods html close;
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/Power/Graphs" style=mystyle image_dpi=300 ;
ods graphics/reset=index  aTTRPRIORITY=none imagefmt=tiff imagename='Model 2 SMR vs. number of matches';
options orientation=landscape ;
proc sgplot data=power;
vbox power/category= SMR group=matches;
xaxis label="Standardized Mortality Ratio";
yaxis label="Number of Matches";
run;


/*%macro sample(n, beta, matches);*/
/*/*minimum number of matches*/*/
/*data sample;*/
/*call streaminit(65432168732);*/
/*	do sample=1 to 1000;*/
/*		do hospital=1 to &matches.;*/
/*			if hospital=1 then case=1;*/
/*	else case=0;*/
/*			do template_id=1 to &n.;*/
/*				eta=-4+&beta.*case;*/
/*				mu=exp(eta)/(1+exp(eta));*/
/*				mort30=rand("Bernoulli", mu);*/
/*				output;*/
/*			end;*/
/*		end;*/
/*	end;*/
/*run;*/
/**/
/*%macro loop;*/
/*%do sample=1 %to 1000;*/
/*ods output parameterestimates=fixed;*/
/*proc glimmix data=sample method=laplace noclprint;*/
/*where sample=&sample.;*/
/*class template_id;*/
/*model mort30 (descending)= case /  link=logit dist=binomial  solution cl or;*/
/*random intercept /sub= template_id solution cl  g;*/
/*run;*/
/**/
/*data fixed;*/
/*set fixed;*/
/*	beta=&beta.;*/
/*	matches=%sysevalf(&matches.-1);*/
/*	template_size=&n.;*/
/*run;*/
/**/
/*data fixed;*/
/*set fixed;*/
/*where effect="case";*/
/*if probt>0.05 then sig=0;*/
/*else sig=1;*/
/*run;*/
/**/
/*data tm.power_calcs;*/
/*set tm.power_calcs fixed;*/
/*run;*/
/**/
/*%end;*/
/*%mend;*/
/*%loop;*/
/*%mend;
/*%sample(500, .29, 6);*/
/*%sample(500, .51, 6);*/
/*%sample(500, .69, 6);*/
/*%sample(500, .85, 6);*/
/*%sample(500, .29, 37);*/
/*%sample(500, .51, 37);*/
/*%sample(500, .69, 37);*/
/*%sample(500, .85, 37);*/
/*%sample(500, .29, 61);*/
/*%sample(500, .51, 61);*/
/*%sample(500, .69, 61);*/
/*%sample(500, .85, 61);*/

/*proc sort data=tm.power_calcs ; by template_size matches beta; run;*/
/*proc freq data=tm.power_calcs;*/
/*by template_size;*/
/*table matches*beta*sig;*/
/*run;*/

/*Original power calcs that were included in Table 2 of the paper*/
/*data p.power_original;*/
/*set tm.power_calcs;*/
/*where template_size=500;*/
/*run;*/

/*Table 2*/
/*proc freq data=p.power_original;*/
/*table matches*beta*sig;*/
/*run;*/
/**/
/*data mortality;*/
/*set tm.simulations;*/
/*keep pred;*/
/*run;*/
/**/
/*data mortality;*/
/*set mortality;*/
/*logpred=log(pred);*/
/*run;*/
/**/
/*proc means data=mortality mean std var;*/
/*var logpred;*/
/*run;*/

/*Observed effects of predicted mortality, case and intercept*/
/*proc means data=tm.fixed_best;*/
/*var Estimate;*/
/*class effect;*/
/*run;*/
