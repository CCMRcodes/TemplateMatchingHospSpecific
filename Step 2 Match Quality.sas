%include '/data/dart/2017/ord_prescott_comparing/Programs/formats.sas';
%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis";

/*Descriptives of the variables by hospital*/
proc sort data=tm.simulations;
by anon_hosp;
run;

ods exclude all;
proc means data=tm.simulations  stackodsoutput mean std min q1 median q3 max;
by anon_hosp;
var pred age albval bili gfr bun na glucose hct pao2 ph pco2 wbc ;
ods output summary=meanssummary(drop=label);
run;
ods exclude none;

ods exclude all;
proc means data=tm.simulations stackodsoutput mean n;
by anon_hosp;
var sex nh ed chf pulm paralysis renal liver cancer_met depression  operative 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx ;
ods output summary=freqs(drop=label);
run;
ods exclude none;

data freqs;
set freqs;
rename mean=percent n=sum;
run;

data tm.descriptives_hosp_categorical;
set freqs;
n=sum*percent;
drop sum;
percent=percent*100;
run;

data tm.descriptives_hosp_continuous;
set meanssummary;
run;

proc sort data=tm.descriptives_hosp_categorical;
by anon_hosp;
run;

/*Standardize the covariate distribution at the hospitals for Figure 2*/
data tm.descriptives_hosp_stnd;
set tm.descriptives_hosp_categorical tm.descriptives_hosp_continuous;
run;

data tm.descriptives_hosp_stnd;
set tm.descriptives_hosp_stnd;
if not missing(mean) then standardized_value=mean;
if not missing(percent) then standardized_value=percent;
run;

proc sort data=tm.descriptives_hosp_stnd; by variable; run;

proc standard data=tm.descriptives_hosp_stnd mean=0 std=1 out=tm.descriptives_hosp_stnd;
var standardized_value;
by variable;
run;

proc export data=tm.descriptives_hosp_categorical
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/descriptives_hosp_categorical.csv"
dbms=csv replace;
run;

proc export data=tm.descriptives_hosp_continuous
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/descriptives_hosp_continuous.csv"
dbms=csv replace;
run;

/*Descriptives of the variables of the cases in the template by hospital*/
proc sort data=tm.template_cases; by anon_hosp; run;

ods exclude all;
proc means data=tm.template_cases  stackodsoutput mean std min q1 median q3 max;
by anon_hosp;
var pred age ;
ods output summary=meanssummary2(drop=label);
run;
ods exclude none;

ods exclude all;
proc means data=tm.template_cases stackodsoutput mean n;
by anon_hosp;
var sex nh ed chf pulm paralysis renal liver cancer_met depression  operative
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx ;
ods output summary=freqs2(drop=label);
run;
ods exclude none;

data freqs2;
set freqs2;
rename mean=percent n=sum;
run;

data tm.descrip_template_cat;
set freqs2;
n=sum*percent;
drop sum;
percent=percent*100;
run;


data tm.descrip_template_cont;
set meanssummary2;
run;

proc sort data=tm.descrip_template_cat;
by anon_hosp;
run;

proc export data=tm.descrip_template_cat
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/descriptives_template_categorical.csv"
dbms=csv replace;
run;

proc export data=tm.descrip_template_cont
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/descriptives_template_continuous.csv"
dbms=csv replace;
run;

proc sql;
create table matches as
select a.*, b.number_imbalanced
from tm.successful_match a
left join  tm.imbalanced b
on a.iteration=b.iteration and a.template=b.template_hosp and a.anon_hosp=b.anon_hosp;
quit;

/*Investigate whether the imbalanced variables were part of the matching algorithm or not*/
data tm.stddiff;
set tm.stddiff;
variable2=lowcase(variable);
run;

data tm.stddiff;
set tm.stddiff;
if obs= "Matched" then do;
if variable2 in ("pred" "hcup_ccs" "age" "sex" "nh" "ed" "chf" "pulm" "paralysis" "renal" "liver" "cancer_met" "depression" 
"cardio_dx" "gi_dx" "infection_dx" "other_dx" "psych_dx" "renal_dx" "resp_dx" "operative" "pred_bin5"
"albval" "bili" "gfr" "bun" "na" "glucose" "hct" "pao2" "ph" "pco2" "wbc") then matched_variable=1;

if variable2 not in ("pred" "hcup_ccs" "age" "sex" "nh" "ed" "chf" "pulm" "paralysis" "renal" "liver" "cancer_met" "depression" 
"cardio_dx" "gi_dx" "infection_dx" "other_dx" "psych_dx" "renal_dx" "resp_dx" "operative" "pred_bin5"
"albval" "bili" "gfr" "bun" "na" "glucose" "hct" "pao2" "ph" "pco2" "wbc") then matched_variable=0;
end;
run;

proc sort data=tm.stddiff; by anon_hosp; run;

data tm.stddiff;
set tm.stddiff;
if obs="Matched" and imbalanced=. then imbalanced=0;
if imbalanced=0 and matched_variable=1 then imbalanced_match_alg=0;
if imbalanced=1 and matched_variable=1 then imbalanced_match_alg=1;
if imbalanced=1 and matched_variable=0 then imbalanced_match_alg=0;
run;

proc sql;
create table imbalanced as
select distinct iteration, anon_hosp, template_hosp, sum(imbalanced) as number_imbalanced, sum(imbalanced_match_alg) as number_imbalanced_alg
from tm.stddiff
group by iteration, template_hosp, anon_hosp;
quit;

proc sort data=imbalanced; by iteration template_hosp anon_hosp;
run;

proc sql;
create table matches as
select a.*, b.number_imbalanced_alg, b.number_imbalanced
from matches a
left join imbalanced b
on a.iteration=b.iteration and a.template=b.template_hosp and a.anon_hosp=b.anon_hosp;
quit;

/*count of each hospital's match with 0 imbalanced*/
proc sql;
create table matches_count as
select iteration, template, sum(case when number_imbalanced_alg=0 then 1 else 0 end) as number_matches
from matches
group by iteration, template;
quit;

proc sort data=matches_count; by template descending number_matches; run;

data matches_count;
set matches_count;
by template;
if first.template then rank=0;
rank+1;
run;

/*first and second best match*/
data best;
set matches_count;
where rank=1 ;
best_iteration=iteration;
run;

data best2;
set matches_count;
where rank=2;
best_iteration2=iteration;
run;

data tm.best_iteration;
set best;
run;

data tm.best_iteration2;
set best2;
run;

data tm.allmatch;
set tm.allmatch;
drop number_imbalanced_alg number_imbalanced;
run;

/*Join the match quality to the tm.allmatch dataset*/
proc sql;
create table tm.allmatch as
select a.*, b.number_imbalanced_alg, b.number_imbalanced
from tm.allmatch a
left join matches b
on a.iteration=b.iteration and a.template=b.template and a.anon_hosp=b.anon_hosp;
quit;

/*Identify the "good matches" as defined by having no imbalanced variables from the algorithm*/
/*Keep the hospitals' "good" matches*/
data tm.good_matches;
set tm.allmatch;
where number_imbalanced_alg=0;
run;

data template;
set tm.template_cases;
if missing(template) then do;
template=template_hospno;
end;
run;

proc sort data=tm.good_matches; by iteration template; run;

data tm.good_matches;
set tm.good_matches;
case=0;
run;

data template;
set template;
case=1;
run;

data tm.analysis;
set tm.good_matches template;
run;/*17972500*/

/*now join the matches for just the best run*/
proc sql;
create table tm.analysis_best_iteration as
select a.*, b.*
from tm.best_iteration a
left join tm.analysis b
on a.template=b.template and a.best_iteration=b.iteration ;
quit;/*n=2374500*/

proc sql;
create table tm.analysis_best_iteration2 as
select a.*, b.*
from tm.best_iteration2 a
left join tm.analysis b
on a.template=b.template and a.best_iteration2=b.iteration ;
quit;/*n=2207000*/

proc sort data=tm.analysis_best_iteration; by template template_id; run; 
proc sort data=tm.analysis_best_iteration2; by template template_id; run; 

/*Counts of good matches*/
proc sql;
create table matches2 as
select distinct iteration, template, count(distinct anon_hosp) as number_hosps_matched, min(number_imbalanced) as min_imb, max(number_imbalanced) as max_imb,
median(number_imbalanced) as median_imb, min(number_imbalanced_alg) as min_imb_alg, max(number_imbalanced_alg) as max_imb_alg,median(number_imbalanced_alg) as median_imb_alg
from tm.good_matches
group by iteration, template;
quit;


proc sort data=matches2; by template iteration; run;

proc transpose data=matches2 out=matches_wide prefix=iteration;
by template;
id iteration;
run;

data tm.matches_wide;
set matches_wide;
rename _name_=variable;
run;

data tm.matches_wide;
set tm.matches_wide;
if variable="number_hosps_matched" then do;
most_matches=max(iteration1, iteration2, iteration3, iteration4, iteration5, iteration6, iteration7, iteration8, iteration9, iteration10);
fewest_matches=min(iteration1, iteration2, iteration3, iteration4, iteration5, iteration6, iteration7, iteration8, iteration9, iteration10);
end;
run;

/*Median number of matches, each run*/
proc means data=tm.matches_wide  median q1 q3 min max maxdec=0;
where variable="number_hosps_matched";
var iteration1--fewest_matches;
run;


data check;
set tm.matches_wide;
where most_matches>=20;
run;

data tm.hospital_match_counts_wide;
set tm.matches_wide;
where variable="number_hosps_matched";
diff=most_matches-fewest_matches;
run;

proc means data=tm.hospital_match_counts_wide min q1 median q3 max maxdec=3;
var diff;
run;

proc export data=tm.hospital_match_counts_wide
outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/matches_wide_withlabs500.csv"
dbms=csv replace;
run;

/*best match*/
data best;
set tm.best_iteration;
best=number_matches;
run;

proc sort data=best; by best; run;

data best;
set best;
rank=_n_;
run;

/*SUPPLEMENTAL FIGURE 2*/
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical;
ods graphics/ imagefmt=tiff imagename='Supp Figure 2 match histogram';
options orientation=landscape;
proc sgplot data=best;
histogram best/ scale=count;
xaxis label="Number of matches";
yaxis label="Number of hospitals";
run;

/*Hardest to match vs. Easiest to Match*/
data best;
set best;
if rank<=10 then group ="Fewest";
if 113<=rank<=122 then group="Most";
run;

data hard_easy;
set best;
where group in ("Fewest", "Most");
run;

proc sql;
create table hard_easy as
select a.*, b.variable, b.standardized_value
from hard_easy a 
left join tm.descriptives_hosp_stnd b
on a.template=b.anon_hosp;
quit;

data hard_easy;
set hard_easy;
keep group variable standardized_value;
run;

DATA hard_easy;
SET hard_easy;
variable=lowcase(variable);
run;

proc sort data=hard_easy; by group variable; run;

proc sql;
create table hard_easy as
select group, variable, mean(standardized_value) as z
from hard_easy
group by group, variable;
quit;

proc sort data=hard_easy; by variable; run;

proc transpose data=hard_easy out=hard_easy;
var z;
by variable;
id group;
run; 

data hard_easy;
set hard_easy;
diff=Fewest-Most;
run;

proc sort data=hard_easy; by diff; run;

/*Standardized value of each variable*/
data hard_easy;
set hard_easy;
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
run;

proc sort data=hard_easy; by diff; run;

/*Supplemental FIGURE 4*/
data sganno;
retain function 'text' x1space 'datavalue' y1space 'datapercent'
rotate 60 anchor "right" width 100 ;
length textcolor $20;
set hard_easy;
if type="Admission" then textcolor="black";
if type="Comorbidities" then textcolor="purple";
if type="Diagnosis" then textcolor="green"; 
if type="Labs" then textcolor="gray";
label=label;
xc1=label;
y1=-5;
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical ;
ods graphics/ imagefmt=tiff imagename='Supp Figure 4 least vs most matched hospital z scores best run';
options orientation=landscape;
proc sgplot data=hard_easy sganno=sganno pad=(bottom=32% left=5%);
series x=label y=fewest /curvelabel="Fewest Matches" curvelabelpos=end curvelabelloc=outside lineattrs=(pattern=solid color=blue);
series x=label y=most/curvelabel="Most Matches" curvelabelpos=end curvelabelloc=outside lineattrs=(pattern=solid color=crimson);
yaxis label="Standardized variable value";
xaxis display=(nolabel novalues) ;
run;

