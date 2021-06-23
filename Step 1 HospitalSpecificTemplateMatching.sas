OPTIONS NONOTES NOSOURCE NOSOURCE2 NOSYMBOLGEN NOMPRINT NOMLOGIC;
ods listing close;
%let iteration=1;

proc printto log="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/hospspec&iteration..log" new; run;

%include '/data/dart/2017/ord_prescott_comparing/Programs/formats.sas';
%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis";
libname coth "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified";
libname ipec "/data/dart/2017/ord_prescott_comparing/Data/IPEC";


%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

/*Create an anon hospital identifier*/
proc sql;
create table hosps as
select distinct(site)
from tm.ipec2017_filtered;
quit;

data hosps;
set hosps;
random=ranuni(654);
run;

proc sort data=hosps; by random; run;;

data hosps;
set hosps;
anon_hosp=_n_;
run;

/*Join the sta6a name*/
proc sql;
create table hosps as
select a.*, b.Official__Station_Name as sta6a_name
from hosps a
left join coth.coth b
on a.site=b.sta6a;
quit;

data tm.hospital_list;
set hosps;
run;

proc sql;
create table simulations as
select a.anon_hosp, b.*
from hosps a
left join tm.ipec2017_filtered b
on a.site=b.site;
quit;/*556341*/

/*change uppercase variables to lowercase for R*/
proc datasets lib=work nolist;
modify simulations;
rename OPERATIVE=operative;
rename AGE=age;
rename SEX=sex;
rename ED=ed;
rename INPATIENTSID=inpatientsid;
run;
quit;

data simulations;
set simulations;
if dx_category="cardio" then cardio_dx=1;else cardio_dx=0;
if dx_category="gi" then gi_dx=1;else gi_dx=0;
if dx_category="infection" then infection_dx=1;else infection_dx=0;
if dx_category="other" then other_dx=1;else other_dx=0;
if dx_category="psych" then psych_dx=1;else psych_dx=0;
if dx_category="renal" then renal_dx=1;else renal_dx=0;
if dx_category="resp" then resp_dx=1;else resp_dx=0;
run;

/*Exclude hospitalizations that are operative and psych*/
data tm.simulations;
set simulations;
if operative=1 and psych_dx=1 then delete;
run;

proc sort data=tm.simulations; by anon_hosp; run;

/*collection of all matches*/
data tm.allmatch&iteration.;
if _n_=1 then delete;
run;

data tm.matches_key&iteration.;
if _n_=1 then delete;
run;

data tm.stddiff&iteration.;
if _n_=1 then delete;
run;

data tm.template_cases&iteration.;
if _n_=1 then delete;
run;

data tm.imbalanced&iteration.;
if _n_=1 then delete;
run;

/*TEMPLATE MATCHING*/

/*The execution of the loop macro will continue on here if the psmatch worked*/
%macro continue;
/*Identify which variables are imbalanced*/
data stddiff&loop_variable.;
set stddiff&loop_variable.;
if obs='Region' then delete;
if obs='Matched' then do;
abs_stddiff=abs(stddiff);
if abs_stddiff>0.25 then imbalanced=1;
end;
run;

proc sort data=out_loop&loop_variable.; by matchid; run;

data matchid_template&loop_variable.;
set out_loop&loop_variable. (keep=template_id inpatientsid case matchid);
where case=1;
drop case;
run;

data matchid_matches&loop_variable.;
set out_loop&loop_variable. (keep=inpatientsid case matchid anon_hosp);
where case=0; drop case;
run;

proc sql;
create table matches&loop_variable. as
select a.template_id, a.matchid, a.inpatientsid as template_inpatientsid, b.inpatientsid as match_inpatientsid, b.anon_hosp as match_anon_hosp
from matchid_template&loop_variable. a
left join matchid_matches&loop_variable. b
on a.matchid=b.matchid;
quit;

/*Add the template ID to the matches*/
data out_loop&loop_variable.;
set out_loop&loop_variable.;
drop template_id;
where case=0;
run;

proc sql;
create table out_loop&loop_variable. as
select a.*, b.template_id
from out_loop&loop_variable. a
left join matches&loop_variable. b
on a.matchid=b.matchid;
quit;

/*Accumulate results for all looped hospitals for Hospital A*/
data out_match_hospno&hospno.;
set out_match_hospno&hospno. out_loop&loop_variable.;
template=&hospno.;
run;

data matches_key_hospno&hospno.;
set matches_key_hospno&hospno. matches&loop_variable.;
template=&hospno.;
run;

/*get the anon_hosp variable to match to the stddiff dataset*/
data out_loop&loop_variable.;
set out_loop&loop_variable.;
call symputx("anonhosp", anon_hosp);
run;

data stddiff&loop_variable.;
set stddiff&loop_variable.;
anon_hosp=&anonhosp.;
run;

/*Number of variables that were imbalanced*/
proc sql;
create table imbalanced&loop_variable. as
select anon_hosp, count(imbalanced) as number_imbalanced
from stddiff&loop_variable.;
quit;

/*Combine the matches from each of the up to 121 hospitals for hospital A*/
data stddiff_hospno&hospno.;
set stddiff_hospno&hospno. stddiff&loop_variable.;
template_hosp=&hospno.;
run;

data imbalanced_hospno&hospno.;
set imbalanced_hospno&hospno. imbalanced&loop_variable.;
template_hosp=&hospno.;
run;

%mend;
/*create the template of size 500 at hospital A*/

%macro match;

%do hospno=1 %to 122;
%let seed=%eval(&iteration*&hospno.+100*&iteration.);

/*Create a dataset which contains only the hospitalizations from hospital A*/
data hosp&hospno.;
set tm.simulations;
where anon_hosp=&hospno.;
run;

proc sort data=hosp&hospno.; by operative psych_dx;run;

/*For 2 hospitals with almost exclusively psych hospitalzations (>99%),
exclude the non-psych hospitalizations from the pool*/
%if &hospno.=3 %then %do;
data hosp3;
set hosp3;
if psych_dx=0 then delete;
run;
%end;

%if &hospno.=36 %then %do;
data hosp36;
set hosp36;
if psych_dx=0 then delete;
run;
%end;

/*Stratified sampling on operative and psych diagnosis.
Allocation is proportional to the hospital rates of operative and psych*/
proc surveyselect data=hosp&hospno. n=500 out=samplesizes;
	strata operative psych_dx/alloc=proportional nosample;
run;

/*Select 500 potential templates from hosptial A of size 500. 
Allocates the 500 in proportion to the strata (operative/non-operative, psych/non-psych)*/
proc surveyselect data=hosp&hospno. noprint method = srs  n = samplesizes
   rep=500 seed=&seed. out=sim_templatecases_hospno&hospno. (rename=(replicate=template_number));
   id id id2 inpatientsid anon_hosp  mort30 pred I10_DXCCS1 age sex nh ed chf pulm paralysis renal liver cancer_met depression 
	cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5 pred_bin10 white black hispanic 
	albval bili gfr bun na glucose hct pao2 ph pco2 wbc
	dm_comp dm_uncomp hypothyroid  pud immunedef lymphoma  cancer_nonmet ra coag obesity wtloss fen anemia_cbl anemia_def 
	etoh drug psychoses valvular_d2  pulm_circ pvd htn  neuro  ;
	strata operative psych_dx;
run;

proc sort data=sim_templatecases_hospno&hospno.; by template_number; run;

/*Calculate the means of each template and of the overall population of hospital A (removed operative after stratifying)*/
proc means data=sim_templatecases_hospno&hospno. mean noprint;
var mort30 pred age chf pulm cancer_met liver depression ;
by template_number;
output out=means_hospno&hospno.;
run;

data means_hospno&hospno.;
set means_hospno&hospno.;
	where _stat_="MEAN";
	drop _TYPE_--_stat_;
run;

/*Index hospital's Population means*/
proc means data=hosp&hospno. mean noprint;
var mort30 pred age chf pulm cancer_met liver depression ;
output out=population_means_hospno&hospno.;
run;

data population_means_hospno&hospno.;
set population_means_hospno&hospno.;
	where _stat_="MEAN";
	drop _TYPE_--_stat_;
run;

proc iml;
use means_hospno&hospno. nobs nobs;
read all var {template_number};
read all var {mort30 pred age  
	chf pulm cancer_met liver depression} 
into data[c=vnames];
close;
use population_means_hospno&hospno.;
read all var {mort30 pred age  
	chf pulm cancer_met liver depression} 
into m;
close;

center=m[:,];
level=unique(template_number);
templatemd=j(ncol(level),ncol(data)+2,.); 

do i=1 to ncol(level);
 templatemd[i,1]=level[i];
 idx=loc(template_number=level[i]);
 templatemd[i,2:ncol(data)+1]=data[idx,][:,];
end;
 
 xx=templatemd[,2:ncol(data)+1];
 cov=cov(xx)+I(8);
 templatemd[,ncol(data)+2]= mahalanobis(xx,center,cov);

names={template_number}||vnames||{distance};
create templatemd from templatemd[c=names];
append from templatemd;
close;
quit;

/*Select the template with the smallest MD*/
proc sql;
create table templatemd_hospno&hospno. as
select template_number, distance
from templatemd
having distance=min(distance);
quit;

/*Select the 500 template cases for the template with the smallest MD*/
proc sql;
create table sim_template_hospno&hospno. as
select a.* 
from templatemd_hospno&hospno. b
left join sim_templatecases_hospno&hospno. a
on a.template_number=b.template_number;
quit;/*n=500 */

proc sort data=sim_template_hospno&hospno.; by inpatientsid; run;

data sim_template_hospno&hospno. ;
set sim_template_hospno&hospno. ;
	template_hospno=&hospno.;
	template_id=_n_;
	case=1;
run;

/*All data with indicator for whether or not part of the template for hospital A (case=1 for template)*/
proc sql;
create table allpool_hospno&hospno. as
select a.*, b.case, b.template_id
from tm.simulations a
left join sim_template_hospno&hospno. b
on a.id=b.id;
quit;/*n=556341*/

/*remove patients from Hospital A (except for template cases) from the eligible pool to be matched*/
data allpool_hospno&hospno.;
set allpool_hospno&hospno.;
if case=. then case=0;
run;

data allpool_hospno&hospno.;
set allpool_hospno&hospno.;
if case=0 and anon_hosp=&hospno. then delete;
run;

/*only keep variables needed for rcbalance*/
data template;
set allpool_hospno&hospno. (keep=anon_hosp inpatientsid template_id case pred mort30 I10_DXCCS1 age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5 pred_bin10 white black hispanic albval bili gfr bun na glucose hct pao2 ph pco2 wbc
dm_comp dm_uncomp hypothyroid  pud immunedef lymphoma  cancer_nonmet ra coag obesity wtloss fen anemia_cbl anemia_def 
etoh drug psychoses valvular_d2  pulm_circ pvd htn  neuro );
hcup_ccs=I10_DXCCS1;
drop I10_DXCCS1;
run;

/*For each hospital, try to match the 500 cases from hospital A*/
data match_hosps;
set template (keep=anon_hosp case);
where case=0; run;

proc sort data=match_hosps nodupkey; by anon_hosp; run;

/*Create a variable from 1 to 121 that I can use to loop through all of the
hosps that will be matched to hospital A*/
data match_hosps;
set match_hosps;
loop_variable=_n_;
run;

proc sql;
create table template as
select a.*, b.loop_variable
from template a
left join match_hosps b
on a.anon_hosp=b.anon_hosp;
quit;

data out_match_hospno&hospno.;
if _n_=1 then delete;
run;

data stddiff_hospno&hospno.;
if _n_=1 then delete;
run;

data matches_key_hospno&hospno.;
if _n_=1 then delete;
run;

data imbalanced_hospno&hospno.;
if _n_=1 then delete;
run;


%macro loop;
%do loop_variable=1 %to 121;

data loop_thru;
set template;
where case=1 or loop_variable=&loop_variable.;
run;

proc psmatch data=loop_thru region=allobs;
class case cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx pred_bin5 
sex hcup_ccs nh ed chf pulm paralysis operative renal liver cancer_met depression;
psmodel case(treated='1')=pred hcup_ccs age sex nh ed chf pulm paralysis renal liver cancer_met depression 
cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5
albval bili gfr bun na glucose hct pao2 ph pco2 wbc;

match distance=lps method=optimal(k=1) exact=(cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx operative pred_bin5) caliper=.;

/*assess variable differences between the treated and control groups 
for all obs in the support region (binary or continuous only)*/
assess var=(pred age sex nh ed chf pulm paralysis renal liver cancer_met depression
white black hispanic albval bili gfr bun na glucose hct pao2 ph pco2 wbc
dm_comp dm_uncomp hypothyroid  pud immunedef lymphoma  cancer_nonmet ra coag obesity wtloss fen anemia_cbl anemia_def 
etoh drug psychoses valvular_d2  pulm_circ pvd htn  neuro  cardio_dx gi_dx infection_dx other_dx psych_dx renal_dx resp_dx) /plots=none weight=none;

output out(obs=match)=out_loop&loop_variable. matchid=MatchID;
ods output stddiff=stddiff&loop_variable.;/*output the standardized mean difference between the template and the matched cases*/
run;

/*If the match was successful, then execute the rest of the program (%continue macro above)*/
data _null_;
set sashelp.vtable (where=(libname="WORK" and memname="OUT_LOOP&loop_variable."));
if nobs>0 then call execute('%continue');
run;

proc datasets;
delete out_loop&loop_variable. stddiff&loop_variable. matches&loop_variable. loop_thru matchid_matches&loop_variable. matchid_template&loop_variable. imbalanced&loop_variable.;
run;

%end;
%mend;
%loop;

proc sort data=out_match_hospno&hospno.; by descending case template_id anon_hosp; run;

data out_match_hospno&hospno.;
set out_match_hospno&hospno.;
iteration=&iteration.;
run;

data matches_key_hospno&hospno.;
set matches_key_hospno&hospno.;
iteration=&iteration.;
run;

data stddiff_hospno&hospno.;
set stddiff_hospno&hospno.;
iteration=&iteration.;
run;

data imbalanced_hospno&hospno.;
set imbalanced_hospno&hospno.;
iteration=&iteration.;
run;

data sim_template_hospno&hospno.;
set sim_template_hospno&hospno.;
iteration=&iteration.;
run;

/*Combine the results for all 122 hospital A's*/
data tm.allmatch&iteration. (compress=yes);
set tm.allmatch&iteration. out_match_hospno&hospno.;
run;

data tm.matches_key&iteration. (compress=yes);
set tm.matches_key&iteration. matches_key_hospno&hospno.;
run;

data tm.stddiff&iteration. (compress=yes);
set tm.stddiff&iteration. stddiff_hospno&hospno.;
run;

data tm.imbalanced&iteration. (compress=yes);
set tm.imbalanced&iteration. imbalanced_hospno&hospno.;
run;

data tm.template_cases&iteration.;
set tm.template_cases&iteration. sim_template_hospno&hospno.;
run;

proc datasets;
delete template sim_template_hospno&hospno. allpool_hospno&hospno. hosp_hospno&hospno. imbalanced_hospno&hospno. hosp&hospno.
match_hosps means_hospno&hospno. population_means_hospno&hospno. cases matches templatemd_hospno&hospno. templatemd samplesizes
out_match_hospno&hospno. matches_key_hospno&hospno. stddiff_hospno&hospno. sim_templatecases_hospno&hospno.;
run;

%end;
%mend;

%match;

/*Which hospitals were successfully matched to hospital A (indexed by variable "template")?*/
proc sql;
create table tm.successful_match&iteration. as
select distinct iteration, template, anon_hosp
from tm.allmatch&iteration.;
quit;

/*get the real site number for the template and matched sites*/
proc sql;
create table tm.successful_match&iteration. as
select a.*, b.site as template_site, b.sta6a_name as template_name
from tm.successful_match&iteration. a
left join hosps b
on a.template=b.anon_hosp;
quit;

proc sql;
create table tm.successful_match&iteration. as
select a.*, b.site as matched_site, b.sta6a_name as matched_name
from tm.successful_match&iteration. a
left join hosps b
on a.anon_hosp=b.anon_hosp;
quit;

proc sort data=tm.successful_match&iteration.; by template_site; run;

proc sql;
create table counts as
select iteration, template_site, count(anon_hosp) as number_hosps_matched
from tm.successful_match&iteration.
group by iteration, template_site;
quit;

/*Add in 0's for any hospitals that were unable to match to any others*/
proc sql;
create table counts as
select a.anon_hosp, a.site, a.sta6a_name, b.*
from hosps a
left join counts b
on a.site=b.template_site;
quit;

data tm.hospital_match_counts&iteration.;
set counts;
if missing(number_hosps_matched) then number_hosps_matched=0;
if missing(template_site) then template_site=site;
drop site;
run;

proc sort data=tm.hospital_match_counts&iteration.; by anon_hosp; run;

/*Combine all iterations*/
data tm.allmatch (compress=yes);
set tm.allmatch1 tm.allmatch2  tm.allmatch3  tm.allmatch4  tm.allmatch5
tm.allmatch6 tm.allmatch7  tm.allmatch8  tm.allmatch9  tm.allmatch10;
run;

data tm.hospital_match_counts (compress=yes);
set tm.hospital_match_counts1 tm.hospital_match_counts2 tm.hospital_match_counts3 tm.hospital_match_counts4 tm.hospital_match_counts5
tm.hospital_match_counts6 tm.hospital_match_counts7 tm.hospital_match_counts8 tm.hospital_match_counts9 tm.hospital_match_counts10;
run;

data tm.imbalanced (compress=yes);
set tm.imbalanced1 tm.imbalanced2 tm.imbalanced3 tm.imbalanced4 tm.imbalanced5
tm.imbalanced6 tm.imbalanced7 tm.imbalanced8 tm.imbalanced9 tm.imbalanced10;
run;

data tm.matches_key (compress=yes);
set tm.matches_key1 tm.matches_key2 tm.matches_key3 tm.matches_key4 tm.matches_key5
tm.matches_key6 tm.matches_key7 tm.matches_key8 tm.matches_key9 tm.matches_key10;
run;

data tm.stddiff (compress=yes);
set tm.stddiff1 tm.stddiff2 tm.stddiff3 tm.stddiff4 tm.stddiff5
tm.stddiff6 tm.stddiff7 tm.stddiff8 tm.stddiff9 tm.stddiff10;
run;

data tm.successful_match (compress=yes);
set tm.successful_match1 tm.successful_match2 tm.successful_match3 tm.successful_match4 tm.successful_match5
tm.successful_match6 tm.successful_match7 tm.successful_match8 tm.successful_match9 tm.successful_match10;
run;

data tm.template_cases (compress=yes);
set tm.template_cases1 tm.template_cases2 tm.template_cases3 tm.template_cases4 tm.template_cases5
tm.template_cases6 tm.template_cases7 tm.template_cases8 tm.template_cases9 tm.template_cases10;
run;

data tm.imbalanced;
set tm.imbalanced;
drop template;
run;

proc sort data=tm.allmatch; by iteration template anon_hosp;run;
proc sort data=tm.imbalanced nodupkey; by iteration template_hosp anon_hosp;run;
proc sort data=tm.matches_key; by iteration template match_anon_hosp;run;
proc sort data=tm.stddiff; by iteration template_hosp anon_hosp;run;
proc sort data=tm.successful_match; by iteration template anon_hosp;run;
proc sort data=tm.template_cases; by iteration anon_hosp;run;
proc sort data=tm.hospital_match_counts; by anon_hosp iteration;run;
