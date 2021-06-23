%include '/data/dart/2017/ord_prescott_comparing/Programs/formats.sas';
%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis";

/*Table 1*/

proc means data=tm.simulations    median q1 q3;
var pred age albval bili gfr bun na glucose hct pao2 ph pco2 wbc ;
run;

ods exclude all;
proc means data=tm.simulations stackodsoutput mean n;
var operative sex depression chf liver cancer_met  paralysis pulm renal
nh ed          
cardio_dx psych_dx  infection_dx gi_dx resp_dx renal_dx other_dx ;
ods output summary=freqs(drop=label);
run;
ods exclude none;

data freqs;
set freqs;
rename mean=percent n=sum;
run;

data freqs;
set freqs;
n=sum*percent;
drop sum;
percent=percent*100;
run;

proc export data=freqs
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Table 1 descriptives_categorical.csv"
dbms=csv replace;
run;

/*Assessing quality of matches*/


/*Supplemental Figure 3*/
proc sql;
create table fig3 as
select a.*, b.*
from tm.best_iteration a
left join tm.analysis_best_iteration b
on a.best_iteration=b.iteration and a.template=b.template;
quit;

data case control;
set fig3;
if case=1 then output case;
if case=0 then output control;
run;

/*keep variables of interest*/
data template;
set tm.template_cases;
keep iteration anon_hosp template_id case pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

proc sort data=template; by anon_hosp; run;

/*Join the template "case" values*/
proc sql;
create table case as
select a.*, b.*
from case a
left join template b
on a.iteration=b.iteration and a.template=b.anon_hosp and a.template_id=b.template_id;
quit;

proc sort data=case; by template; run;

proc means data=case mean std noprint;
by template;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
output out=means_case;
run;

data means_case;
set means_case;
where _STAT_ in ('MEAN', 'STD');
run; 

proc transpose data=means_case out=means_case_long;
by template;
id _stat_;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

data means_case_long;
set means_case_long;
variable=lowcase(_name_);
if variable="cardio_dx" then label="Cardiovascular diagnosis";
if variable="resp_dx" then label="Respiratory diagnosis";
if variable="infection_dx" then label="Infection diagnosis";
if variable="age" then label="Age";
if variable="renal" then label="Renal Disease";
if variable="renal_dx" then label="Renal diagnosis";
if variable="gi_dx" then label="Gastrointestinal diagnosis";
if variable="pred" then label="Predicted Mortality";
if variable="pulm" then label="Pulmonary disease";
if variable="chf" then label="CHF";
if variable="other_dx" then label="Other diagnosis";
if variable="cancer_met" then label="Cancer";
if variable="paralysis" then label="Paralysis";
if variable="nh" then label="NH admission";
if variable="sex" then label="Female";
if variable="depression" then label="Depression";
if variable="liver" then label="Liver disease";
if variable="operative" then label="Surgical";
if variable="ed" then label="ED admission";
if variable="psych_dx" then label="Psychiatric diagnosis";
if variable="albval" then label="Albumin";
if variable="bili" then label="Bilirubin";
if variable="gfr" then label="GFR";
if variable="bun" then label="BUN";
if variable="na" then label="Sodium";
if variable="glucose" then label="Glucose";
if variable="hct" then label="Hematocrit";
if variable="pao2" then label="PaO2";
if variable="ph" then label="pH";
if variable="pco2" then label="PaCO2";
if variable="wbc" then label="WBC count";

if variable in ("cancer_met"  "chf" "depression" "paralysis" "pulm" "liver" "renal") then type="Comorbidities";
if variable in ("cardio_dx" "gi_dx" "infection_dx" "psych_dx" "renal_dx" "resp_dx" "other_dx") then type="Diagnosis"; 
if variable in ("sex" "ed" "nh" "operative" "age" "pred") then type="Admission";
if variable in ("albval" "bili" "gfr" "bun" "na" "glucose" "hct" "pao2" "ph" "pco2" "wbc") then type="Labs";
drop _name_ _label_;
run;

data good;
set tm.good_matches;
keep iteration template anon_hosp template_id case pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

proc sort data=control; by template template_id; run;

proc sql;
create table control2 as
select a.*, b.*
from control a
left join good b
on a.iteration=b.iteration and a.template=b.template and a.anon_hosp=b.anon_hosp and a.template_id=b.template_id;
quit;

proc sort data=control2; by template; run;

/*Pooled means of all variables for hospitals matched to each template*/
proc means data=control2 mean std noprint;
by template;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
output out=means_control;
run;

data means_control;
set means_control;
where _STAT_ in ('MEAN', 'STD');
run; 

proc transpose data=means_control out=means_control_long;
by template;
id _stat_;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

data means_control_long;
set means_control_long;
variable=lowcase(_name_);
if variable="cardio_dx" then label="Cardiovascular diagnosis";
if variable="resp_dx" then label="Respiratory diagnosis";
if variable="infection_dx" then label="Infection diagnosis";
if variable="age" then label="Age";
if variable="renal" then label="Renal Disease";
if variable="renal_dx" then label="Renal diagnosis";
if variable="gi_dx" then label="Gastrointestinal diagnosis";
if variable="pred" then label="Predicted Mortality";
if variable="pulm" then label="Pulmonary disease";
if variable="chf" then label="CHF";
if variable="other_dx" then label="Other diagnosis";
if variable="cancer_met" then label="Cancer";
if variable="paralysis" then label="Paralysis";
if variable="nh" then label="NH admission";
if variable="sex" then label="Female";
if variable="depression" then label="Depression";
if variable="liver" then label="Liver disease";
if variable="operative" then label="Surgical";
if variable="ed" then label="ED admission";
if variable="psych_dx" then label="Psychiatric diagnosis";
if variable="albval" then label="Albumin";
if variable="bili" then label="Bilirubin";
if variable="gfr" then label="GFR";
if variable="bun" then label="BUN";
if variable="na" then label="Sodium";
if variable="glucose" then label="Glucose";
if variable="hct" then label="Hematocrit";
if variable="pao2" then label="PaO2";
if variable="ph" then label="pH";
if variable="pco2" then label="PaCO2";
if variable="wbc" then label="WBC count";

if variable in ("cancer_met"  "chf" "depression" "paralysis" "pulm" "liver" "renal") then type="Comorbidities";
if variable in ("cardio_dx" "gi_dx" "infection_dx" "psych_dx" "renal_dx" "resp_dx" "other_dx") then type="Diagnosis"; 
if variable in ("sex" "ed" "nh" "operative" "age" "pred") then type="Admission";
if variable in ("albval" "bili" "gfr" "bun" "na" "glucose" "hct" "pao2" "ph" "pco2" "wbc") then type="Labs";
drop _name_ _label_;
run;

proc sql;
create table stddiff as
select a.*, b.mean as case_mean 
from means_control_long a
left join means_case_long b
on a.template=b.template and a.variable=b.variable;
quit;

data stddiff;
set stddiff;
abs_stddiff=abs(case_mean-mean)/std;
group="After";
run;


/*Before matching*/
data simulations;
set tm.simulations;
keep anon_hosp pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

proc sql;
create table before as
select distinct anon_hosp
from control;
quit;

/*all hospitalizations for the comparison hospitals*/
proc sql;
create table before_case as
select a.*, b.*
from before a
left join simulations b
on a.anon_hosp=b.anon_hosp;
quit;

proc sort data=simulations; by anon_hosp; run;

%macro before;
data before_control;
set simulations;
%do anon_hosp=1 %to 122;
case_hosp=&anon_hosp;
if anon_hosp ne &anon_hosp then output;
%end;
run;
%mend;
%before;

proc sort data=before_control; by case_hosp anon_hosp; run;

data means_before;
if _n_=1 then delete;
run;

%macro before;
%do case_hosp=1 %to 122;
/*Pooled means of all variables for hospitals matched to each template*/
proc means data=simulations mean std noprint;
where &case_hosp. ne anon_hosp;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
output out=means_before&case_hosp.;
run;


data means_before&case_hosp.;
set  means_before&case_hosp.;
case_hosp=&case_hosp.;
run;


data means_before;
set means_before means_before&case_hosp.;
run;

%end;

%mend;
%before;

data means_before;
set means_before;
where _STAT_ in ('MEAN', 'STD');
run; 

proc transpose data=means_before out=means_before_long;
by case_hosp;
id _stat_;
var pred  age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;
run;

data means_before_long;
set means_before_long;
variable=lowcase(_name_);
if variable="cardio_dx" then label="Cardiovascular diagnosis";
if variable="resp_dx" then label="Respiratory diagnosis";
if variable="infection_dx" then label="Infection diagnosis";
if variable="age" then label="Age";
if variable="renal" then label="Renal Disease";
if variable="renal_dx" then label="Renal diagnosis";
if variable="gi_dx" then label="Gastrointestinal diagnosis";
if variable="pred" then label="Predicted Mortality";
if variable="pulm" then label="Pulmonary disease";
if variable="chf" then label="CHF";
if variable="other_dx" then label="Other diagnosis";
if variable="cancer_met" then label="Cancer";
if variable="paralysis" then label="Paralysis";
if variable="nh" then label="NH admission";
if variable="sex" then label="Female";
if variable="depression" then label="Depression";
if variable="liver" then label="Liver disease";
if variable="operative" then label="Surgical";
if variable="ed" then label="ED admission";
if variable="psych_dx" then label="Psychiatric diagnosis";
if variable="albval" then label="Albumin";
if variable="bili" then label="Bilirubin";
if variable="gfr" then label="GFR";
if variable="bun" then label="BUN";
if variable="na" then label="Sodium";
if variable="glucose" then label="Glucose";
if variable="hct" then label="Hematocrit";
if variable="pao2" then label="PaO2";
if variable="ph" then label="pH";
if variable="pco2" then label="PaCO2";
if variable="wbc" then label="WBC count";

if variable in ("cancer_met"  "chf" "depression" "paralysis" "pulm" "liver" "renal") then type="Comorbidities";
if variable in ("cardio_dx" "gi_dx" "infection_dx" "psych_dx" "renal_dx" "resp_dx" "other_dx") then type="Diagnosis"; 
if variable in ("sex" "ed" "nh" "operative" "age" "pred") then type="Admission";
if variable in ("albval" "bili" "gfr" "bun" "na" "glucose" "hct" "pao2" "ph" "pco2" "wbc") then type="Labs";
drop _name_ _label_;
run;

proc sort data=means_before_long; by case_hosp variable; run;

proc sql;
create table stddiff2 as
select a.*, b.template, b.mean as case_mean 
from means_before_long a
left join means_case_long b
on a.case_hosp=b.template and a.variable=b.variable;
quit;

data stddiff2;
set stddiff2;
abs_stddiff=abs(case_mean-mean)/std;
group="Before";
run;

data stddiff;
set stddiff;
if missing(abs_stddiff) and mean(0) then abs_stddiff=0;
run;

data fig3;
set stddiff2 stddiff;
drop case_hosp;
run;

proc sort data=fig3; by template  descending type descending label; run;

proc transpose data=fig3 out=wide;
by template  descending type descending label;
id group;
var  abs_stddiff;
run;

data wide;
set wide;
diff=before-after;
run;

proc means data=wide mean noprint;
by template; 
var diff;
output out=improve;
run;

data improve;
set improve;
where _stat_='MEAN';
run;

proc sql;
create table wide as
select a.*, b.diff as mean_improve
from wide a
left join improve b
on a.template=b.template;
quit;

proc sort data=wide; by mean_improve; run;

proc means data=wide min median max ;
var mean_improve;
run;

proc sql;
create table check as
select template, sum(before) as before, sum(after) as after
from wide
group by template; quit;

data check;
set check;
diff=before-after;
run;

proc means data=check min max;
var diff; run;


ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical;
ods graphics/ imagefmt=tiff imagename='Supp Figure 3 C Smallest Improvement';
options orientation=landscape;
ods graphics on/attrpriority=none width=16in height=10in;
proc sgplot data=fig3;
where template=17;
styleattrs datacontrastcolors=(black black) datasymbols=(Circle CircleFilled);
scatter x=abs_stddiff y=label/group=group markerattrs=(size=12);
refline 0.25/axis=x LINEATTRS=(pattern=dash);
yaxis display=(nolabel);
xaxis display=(nolabel)  values=(0 to 1 by 0.25);
keylegend /location=inside position=bottomright across=1 title='';
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical;
ods graphics/ imagefmt=tiff imagename='Supp Figure 3 B Median Improvement';
options orientation=landscape;
ods graphics on/attrpriority=none width=16in height=10in;
proc sgplot data=fig3;
where template=33;
styleattrs datacontrastcolors=(black black) datasymbols=(Circle CircleFilled);
scatter x=abs_stddiff y=label/group=group markerattrs=(size=12);
refline 0.25/axis=x LINEATTRS=(pattern=dash);
yaxis display=(nolabel);
xaxis display=(nolabel)  values=(0 to 1 by 0.25);
keylegend /location=inside position=bottomright across=1 title='';
run;

data fig3;
set fig3;
if abs_stddiff>1.2 then abs_stddiff2=1.2;
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical;
ods graphics/ imagefmt=tiff imagename='Supp Figure 3 A Largest Improvement';
options orientation=landscape;
ods graphics on/attrpriority=none width=16in height=10in;
proc sgplot data=fig3;
where template=8;
symbolchar name=arrow char='21A6'x/scale=2;
styleattrs datacontrastcolors=(black black) datasymbols=(Circle CircleFilled);
scatter x=abs_stddiff y=label/group=group markerattrs=(size=12) name="one";
scatter x=abs_stddiff2 y=label/group=group markerattrs=(size=18 symbol=arrow);
refline 0.25/axis=x LINEATTRS=(pattern=dash);
yaxis display=(nolabel);
xaxis display=(nolabel) values=(0 to 1.25 by 0.25);
keylegend "one" /location=inside position=bottomright across=1 title='';
run;

proc means data=fig3 sum;
by template;
var abs_stddiff;
class group;
run;

proc sql;
create table sum as
select template, group, sum(abs_stddiff) as sum
from fig3
group by template, group;
quit;

proc transpose data=sum out=sum2;
by template;
var sum;
id group;
run;

data sum2;
set sum2;
diff=before-after;
run;

proc means data=sum2 min median max;
var diff;
run;

