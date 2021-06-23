%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis";
libname coth "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified";
libname ipec "/data/dart/2017/ord_prescott_comparing/Data/IPEC";

/*Event rates for the cases and matched hospitals*/


/*matched hospital rates*/
proc sql;
create table rates as
select distinct iteration, template, anon_hosp, sum(mort30) as deaths
from tm.good_matches
group by iteration, template, anon_hosp;
quit;

data rates;
set rates;
match_death_rate=deaths/500;
run;

proc means data=rates n mean uclm lclm;
var match_death_rate;
class iteration template;
output out=out mean=mean_match_death lclm=lower_match uclm=upper_match n=n;
run;

data ratesb;
set out;
where not missing(template) and not missing(iteration);
run;

/*template rates*/
proc sql;
create table rates2 as
select distinct iteration, template_hospno, sum(mort30) as deaths
from tm.template_cases
group by iteration, template_hospno;
quit;

data rates2;
set rates2;
death_rate=deaths/500;
run;

/*Add identifier*/
proc sql;
create table rates2 as
select a.*, b.*
from rates2 a
left join tm.hospital_list b
on a.template_hospno=b.anon_hosp;
quit;

proc sql;
create table rates as
select a.*, b.mean_match_death, b.lower_match, b.upper_match
from rates2 a
left join ratesb b
on a.iteration=b.iteration and a.template_hospno=b.template;
quit;

data rates;
set rates;
diff=death_rate-mean_match_death;
run;

proc sql;
create table tm.fixed_best_caseonly as
select a.*, b.best_iteration
from tm.fixed_best_caseonly a
left join tm.best_iteration b
on a.template=b.template;
quit;

/*Join the best/worse/same rankings*/
proc sql;
create table rates as
select a.*, b.rank, c.number_matches
from tm.fixed_best_caseonly b
left join rates a
on a.template_hospno=b.template and a.iteration=b.best_iteration
left join tm.best_iteration c
on a.template_hospno=c.template and a.iteration=c.best_iteration;
quit;

data rates;
set rates;
lower=death_rate-1.645*sqrt(death_rate*(1-death_rate)/(500));
upper=death_rate+1.645*sqrt(death_rate*(1-death_rate)/(500));
run;

proc sort data=rates; by diff;  run;

data rates; 
set rates;
order=_n_;
run;

proc sort data=rates; by order; run;

data worse;
set rates;
where rank="worse";
run;


proc sql;
create table cases as
select a.*, b.*
from worse a
left join tm.template_cases b
on a.anon_hosp=b.anon_hosp and a.iteration=b.iteration;
quit;

proc freq data=cases;
table anon_hosp;
run;


proc sql;
create table controls as
select a.*, b.*
from worse a
left join tm.matches_key b
on a.anon_hosp=b.template and a.iteration=b.iteration;
quit;

proc freq data=controls;
table anon_hosp;
run;

proc sql;
create table controls as
select a.*, b.*
from controls a
left join tm.simulations b
on a.match_inpatientsid=b.inpatientsid;
quit;

proc freq data=controls;
table anon_hosp*mort30/nocol nopercent;
run;

proc freq data=cases;
table anon_hosp*mort30/nocol nopercent;
run; 

/*Median predicted mortality for the entire hospital system*/
proc univariate data=tm.simulations;
var pred;
run;

data cases;
set cases;
if pred>=0.013733837 then pred_group="Higher Predicted Mortality";
else if pred<0.013733837 then pred_group="Lower Predicted Mortality";

if ed=0 then ed_admission="Not ED Admission";
else if ed=1 then ed_admission="ED Admission";

if operative=0 then surgical="Non-Surgical";
else if operative=1 then surgical="Surgical";


if age<65 then age_cat="Age 18-65";
if 65<=age<85 then age_cat="Age 65-84";
if age>=85 then age_cat="Age 85+";

group="case";
run;

data controls;
set controls;
if pred>=0.013733837 then pred_group="Higher Predicted Mortality";
else if pred<0.013733837 then pred_group="Lower Predicted Mortality";

if ed=0 then ed_admission="Not ED Admission";
else if ed=1 then ed_admission="ED Admission";

if operative=0 then surgical="Non-Surgical";
else if operative=1 then surgical="Surgical";


if age<65 then age_cat="Age 18-65";
if 65<=age<85 then age_cat="Age 65-84";
if age>=85 then age_cat="Age 85+";

group="control";
run;

data case40 case46 case50 case51 case78;
set cases;
if anon_hosp=40 then output case40;
if anon_hosp=46 then output case46;
if anon_hosp=50 then output case50;
if anon_hosp=51 then output case51;
if anon_hosp=78 then output case78;
run;

data control40 control46 control50 control51 control78;
set controls;
if anon_hosp=40 then output control40;
if anon_hosp=46 then output control46;
if anon_hosp=50 then output control50;
if anon_hosp=51 then output control51;
if anon_hosp=78 then output control78;
run;

proc freq data=case40;
table age_cat*mort30/nocol nopercent out=a; 
table surgical*mort30/nocol nopercent out=b; 
table pred_group*mort30/nocol nopercent out=c; 
table pred_bin5*mort30/nocol nopercent; 
table ed_admission*mort30/nocol nopercent out=d; 
run;

data out;
set a b c d;
/*where mort30=1;*/
run;

proc freq data=control40;
table age_cat*mort30/nocol nopercent out=a; 
table surgical*mort30/nocol nopercent out=b; 
table pred_group*mort30/nocol nopercent out=c; 
table pred_bin5*mort30/nocol nopercent; 
table ed_admission*mort30/nocol nopercent out=d; 
run;

data out2;
set a b c d;
/*where mort30=1;*/
run;


data hosp1;
set control40 case40;
run;
data hosp2;
set control46 case46;
run;
data hosp3;
set control50 case50;
run;
data hosp4;
set control51 case51;
run;
data hosp5;
set control78 case78;
run;
/**/
/*%macro subgroup;*/
/*%do hosp=1 %to 5;*/
/**/
/*proc sort data=hosp&hosp.; by age_cat; run;*/
/**/
/*ods output relativerisks=relrisk;*/
/*proc freq data=hosp&hosp.;*/
/*by age_cat;*/
/*table group*mort30/oddsratio;*/
/*run;*/
/**/
/*proc sort data=hosp&hosp.; by surgical; run;*/
/**/
/*ods output relativerisks=relrisk2;*/
/*proc freq data=hosp&hosp.;*/
/*by surgical;*/
/*table group*mort30/oddsratio;*/
/*run;*/
/**/
/*proc sort data=hosp&hosp.; by ed_admission; run;*/
/**/
/*ods output relativerisks=relrisk3;*/
/*proc freq data=hosp&hosp.;*/
/*by ed_admission;*/
/*table group*mort30/oddsratio;*/
/*run;*/
/**/
/**/
/*proc sort data=hosp&hosp.; by pred_group; run;*/
/**/
/*ods output relativerisks=relrisk4;*/
/*proc freq data=hosp&hosp.;*/
/*by pred_group;*/
/*table group*mort30/oddsratio;*/
/*run;*/
/**/
/*data relrisk;*/
/*set relrisk;*/
/*rename age_cat=variable;*/
/*run;*/
/*data relrisk2;*/
/*set relrisk2;*/
/*rename surgical=variable;*/
/*run;*/
/*data relrisk3;*/
/*set relrisk3;*/
/*rename ed_admission=variable;*/
/*run;*/
/*data relrisk4;*/
/*set relrisk4;*/
/*rename pred_group=variable;*/
/*run;*/
/**/
/*data or&hosp.;*/
/*set relrisk4 relrisk3 relrisk2  relrisk;*/
/*where statistic="Odds Ratio";*/
/*OR=1/value;*/
/*lower=1/lowercl;*/
/*upper=1/uppercl;*/
/*run;*/
/**/
/*ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Graphs" style=statistical image_dpi=300 ;*/
/*ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Subgroup Forest Hospital &hosp.';*/
/*options orientation=landscape ;*/
/*proc sgplot data=or&hosp.;*/
/*scatter x=or y=variable/xerrorlower=lower xerrorupper=upper markerattrs=(color=black symbol=squarefilled size=8) errorbarattrs=(color=black) noerrorcaps;*/
/*refline 1/axis=x;*/
/*xaxis label="Odds Ratio (95% CI) of Case Hospital vs. Matched Controls"; */
/*yaxis label="Subgroup";*/
/*run;*/
/**/
/*%end;*/
/*%mend;*/
/**/
/*%subgroup;*/

%macro subgroup;
%do hosp=2 %to 5;

ods output onewayfreqs=n;
proc freq data=hosp&hosp.;
where group="case";
table group pred_group ed_admission surgical age_cat;
run;

data n;
set n;
variable=pred_group;
if missing(variable) then variable=surgical;
if missing(variable) then variable=ed_admission;
if missing(variable) then variable=age_cat;
if missing(variable) then variable="Overall";
run;

data n;
set n;
keep variable Frequency;
run;


proc sort data=hosp&hosp.; by age_cat; run;

ods output relativerisks=relrisk crosstabfreqs=events;
proc freq data=hosp&hosp.;
by age_cat;
table group*mort30/oddsratio;
run;

proc sort data=hosp&hosp.; by surgical; run;

ods output relativerisks=relrisk2 crosstabfreqs=events2;
proc freq data=hosp&hosp.;
by surgical;
table group*mort30/oddsratio;
run;

proc sort data=hosp&hosp.; by ed_admission; run;

ods output relativerisks=relrisk3 crosstabfreqs=events3;
proc freq data=hosp&hosp.;
by ed_admission;
table group*mort30/oddsratio;
run;

proc sort data=hosp&hosp.; by pred_group; run;

ods output relativerisks=relrisk4 crosstabfreqs=events4;
proc freq data=hosp&hosp.;
by pred_group;
table group*mort30/oddsratio;
run;

/*Overall OR*/
ods output relativerisks=relrisk5 crosstabfreqs=events5;
proc freq data=hosp&hosp.;
table group*mort30/oddsratio;
run;

data relrisk;
set relrisk;
rename age_cat=variable;
run;
data relrisk2;
set relrisk2;
rename surgical=variable;
run;
data relrisk3;
set relrisk3;
rename ed_admission=variable;
run;
data relrisk4;
set relrisk4;
rename pred_group=variable;
run;
data relrisk5;
set relrisk5;
variable="Overall";
run;

data or1;
set relrisk4 relrisk3 relrisk2  relrisk relrisk5;
where statistic="Odds Ratio";
OR=1/value;
lower=1/lowercl;
upper=1/uppercl;
run;

proc sort data=or1; by variable; run;

proc sort data=n; by variable; run;
data or1;
merge or1 n;
by variable;
run;


data events;
set events;
where group="case" and mort30=1;
run;
data events2;
set events2;
where group="case" and mort30=1;
run;
data events3;
set events3;
where group="case" and mort30=1;
run;
data events4;
set events4;
where group="case" and mort30=1;
run;
data events5;
set events5;
where group="case" and mort30=1;
variable="Overall";
run;

data events;
set events;
keep age_cat Frequency;
rename age_cat=variable
Frequency=deaths;
run;
data events2;
set events2;
keep surgical Frequency;
rename surgical=variable
Frequency=deaths;
run;
data events3;
set events3;
keep ed_admission Frequency;
rename ed_admission=variable
Frequency=deaths;
run;
data events4;
set events4;
keep pred_group Frequency;
rename pred_group=variable
Frequency=deaths;
run;
data events5;
set events5;
keep Frequency variable;
rename Frequency=deaths;
run;

data deaths1;
set events4 events3 events2 events events5;
run;

proc sort data=or1; by variable; run;

proc sort data=deaths1; by variable; run;

proc sql;
create table more_or1 as
select a.*, b.deaths 
from or1 a
left join deaths1 b
on a.variable=b.variable;
quit;

data more_or1;
set more_or1;
if variable="Overall" then do;
variable2="Overall";
or2=or;
or=.;
lower2=lower;
upper2=upper;
end;
Number="N";
N_Deaths="Deaths";
run;

data more_or1;
set more_or1;


if variable="Lower Predicted Mortality" then obsid=1;
if variable="Higher Predicted Mortality" then obsid=2;

if variable="Age 18-65" then obsid=3;
if variable="Age 65-84" then obsid=4;
if variable="Age 85+" then obsid=5;

if variable="ED Admission" then obsid=6;
if variable="Not ED Admission" then obsid=7;


if variable="Surgical" then obsid=8;
if variable="Non-Surgical" then obsid=9;

if variable="Overall" then obsid=10;

run;

proc sort data=more_or1; by  descending obsid; run;

/* Add sequence numbers to each observation */                                                                                       
data more_or1;                                                                                                                           
   set more_or1 end=last;                                                                                                                
   retain fmtname 'Ordering' type 'n';                                                                                                     
   variablevalue=_n_;                                                                                                                      
   if variable2='Overall' then variablevalue2=1;                                                                                              
   else variablevalue2 = .;                                                                                                                
                                                                                                                                        
/* Output values and formatted strings to data set */                                                                                   
   label=variable;                                                                                                                         
   start=variablevalue;                                                                                                                    
   end=variablevalue;                                                                                                                      
   output;                                                                                                                              
   if last then do;                                                                                                                     
      hlo='O';                                                                                                                          
      label='Other';                                                                                                                    
   end;                                                                                                                                 
run;                                                                                                                                    
                                                                                                                                        
/* Create the format from the data set */                                                                                                                                                                                                                                      
proc format library=work cntlin=more_or1;                                                                                                
run;   

data more_or1;
format variablevalue variablevalue2 ordering.;
drop fmtname type label start end hlo pct;   
set more_or1;
if variablevalue=1 then variablevalue=.;

 /* Compute top and bottom offsets */                                                                                                    
   if _n_ = 10 then do;                                                                                                                  
      pct=0.75/10;                                                                                                                        
      call symputx("pct", pct);                                                                                                             
      call symputx("pct2", 2*pct);                                                                                                          
/*      call symputx("count", nobs);                                                                                                          */
   end;
run;

/*ods graphics / reset width=600px height=400px;*/
/*ods  show;*/
/*ods html;*/

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Graphs" style=statistical image_dpi=300 ;
ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Subgroup Forest Hospital Example Hosp &hosp.';
options orientation=landscape ;

proc sgplot data=more_or1 noautolegend;
scatter x=or2 y=variablevalue2/xerrorlower=lower xerrorupper=upper markerattrs=(color=red symbol=diamondfilled size=10) errorbarattrs=(color=red) noerrorcaps ;
scatter x=or y=variablevalue/xerrorlower=lower xerrorupper=upper markerattrs=(color=black symbol=squarefilled size=10) errorbarattrs=(color=black) noerrorcaps;
scatter x=Number y=variablevalue/markerchar=frequency x2axis markercharattrs=(Family="Arial" Size=10);
scatter x=N_Deaths y=variablevalue/markerchar=deaths x2axis markercharattrs=(Family="Arial" Size=10);

scatter x=Number y=variablevalue2/markerchar=frequency x2axis markercharattrs=(Family="Arial" Size=10 weight=bold);
scatter x=N_Deaths y=variablevalue2/markerchar=deaths x2axis markercharattrs=(Family="Arial" Size=10 weight=bold);

refline 1 10/axis=x;
yaxis label="Subgroup" display=(noticks) offsetmin=0.1 offsetmax=0.05 values=(1 to 10 by 1); 
xaxis offsetmin=0 offsetmax=0.35 min=0.1 max=10 minor label="Odds Ratio (95% CI) of Case Hospital vs. Matched Controls" ;  
x2axis offsetmin=.7 display=(noticks nolabel);
run;
%end;
%mend;

%subgroup;
/*ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Graphs" style=statistical image_dpi=300 ;*/
/*ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Subgroup Forest Hospital &hosp.';*/
/*options orientation=landscape ;*/
/*proc sgplot data=or&hosp.;*/
/*scatter x=or y=variable/xerrorlower=lower xerrorupper=upper markerattrs=(color=black symbol=squarefilled size=8) errorbarattrs=(color=black) noerrorcaps;*/
/*refline 1/axis=x;*/
/*xaxis label="Odds Ratio (95% CI) of Case Hospital vs. Matched Controls"; */
/*yaxis label="Subgroup";*/
/*run;*/
