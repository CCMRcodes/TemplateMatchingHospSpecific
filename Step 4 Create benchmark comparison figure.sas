%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname orig "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis";
libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Random template id";

/*Event rates for the cases and matched hospitals*/

/*matched hospital rates*/
proc sql;
create table rates as
select distinct iteration, template, anon_hosp, sum(mort30) as deaths
from orig.good_matches
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
from orig.template_cases
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
left join orig.hospital_list b
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
left join orig.best_iteration b
on a.template=b.template;
quit;

/*Join the best/worse/same rankings*/
proc sql;
create table rates as
select a.*, b.rank, c.number_matches
from tm.fixed_best_caseonly b
left join rates a
on a.template_hospno=b.template and a.iteration=b.best_iteration
left join orig.best_iteration c
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

data check;
set rates;
where rank="same";
run;/*the median hosps are order=59,60,61,62,63
note that 62 is actually significantly better*/


data plot;
set rates;
where rank="better" or rank="worse" or order in(59,60,61,62,63);
run;

proc sort data=plot; by rank diff; run;

data plot;
set plot;
order2=_n_;
run;

/*Add labels to plot*/
data anno;
function="TEXT";
label="Hospitals performing better than their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=3.1;
y1=.069;
width=25;
output;

function="TEXT";
label="Hospitals performing same as their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=9.1;
y1=.069;
width=25;
output; 

function="TEXT";
label="Hospitals performing worse than their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=14.1;
y1=.069;
width=25;
output;
run;

proc means data=rates; 
var death_rate;
run;

data plot;
set plot;
if rank="better" then y1=death_rate;
if rank="same" then y2=death_rate;
if rank="worse" then y3=death_rate;
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical image_dpi=300 ;
ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Figure 2 benchmark comparison';
options orientation=landscape ;
proc sgplot data=plot sganno=anno noautolegend nocycleattrs;
refline .0384/lineattrs=(pattern=solid thickness=1 color=black);
refline 8 14/lineattrs=(pattern=thindot thickness=2) axis=x;
scatter x=order2 y=mean_match_death/yerrorlower=lower_match yerrorupper=upper_match markeroutlineattrs=(color=black) noerrorcaps markerattrs=(color=black symbol=circlefilled ) errorbarattrs=(color=black) legendlabel="Benchmark";
scatter x=order2 y=y1/ markerattrs=(color=green symbol=circlefilled)   markeroutlineattrs=(color=green) errorbarattrs=(color=green ) legendlabel="Hospital";
scatter x=order2 y=y2/markerattrs=(color=gray symbol=circlefilled)  markeroutlineattrs=(color=gray) errorbarattrs=(color=gray) legendlabel="Hospital";
scatter x=order2 y=y3/markerattrs=(color=red symbol=circlefilled)  markeroutlineattrs=(color=red) errorbarattrs=(color=red) legendlabel="Hospital";
xaxis label="Hospital" values=(1 to 18 by 1) display=(novalues);
yaxis label="Mortality within 30 days (%)" values=(0 0.02 0.04 0.06 0.08) valuesdisplay=("0%" "2%" "4%" "6%" "8%");
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical image_dpi=300 ;
ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Figure 2 benchmark comparison with error bars';
options orientation=landscape ;
proc sgplot data=plot sganno=anno noautolegend nocycleattrs;
refline .0384/lineattrs=(pattern=solid thickness=1 color=black);
refline 8 14/lineattrs=(pattern=thindot thickness=2) axis=x;
scatter x=order2 y=mean_match_death/yerrorlower=lower_match yerrorupper=upper_match markeroutlineattrs=(color=black) noerrorcaps markerattrs=(color=black symbol=circlefilled ) errorbarattrs=(color=black) legendlabel="Benchmark";
scatter x=order2 y=y1/ yerrorlower=lower yerrorupper=upper markerattrs=(color=green symbol=circlefilled)   markeroutlineattrs=(color=green) errorbarattrs=(color=green ) noerrorcaps legendlabel="Hospital";
scatter x=order2 y=y2/yerrorlower=lower yerrorupper=upper markerattrs=(color=gray symbol=circlefilled)  markeroutlineattrs=(color=gray) errorbarattrs=(color=gray) noerrorcaps legendlabel="Hospital";
scatter x=order2 y=y3/yerrorlower=lower yerrorupper=upper markerattrs=(color=red symbol=circlefilled)  markeroutlineattrs=(color=red) errorbarattrs=(color=red) noerrorcaps legendlabel="Hospital";
xaxis label="Hospital" values=(1 to 18 by 1) display=(novalues);
yaxis label="Mortality within 30 days (%)" values=(0 0.02 0.04 0.06 0.08) valuesdisplay=("0%" "2%" "4%" "6%" "8%");
run;

/*Add labels to plot*/
data anno2;
function="TEXT";
label="Hospitals performing better than their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=1;
y1=.068;
width=30;
output;

function="TEXT";
label="Hospitals performing same as their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=9;
y1=.068;
width=25;
output; 

function="TEXT";
label="Hospitals performing worse than their benchmark";
anchor='BOTTOMLEFT';
drawspace='DATAVALUE';
x1=14.5;
y1=.068;
width=30;
output;
run;

/*Annotated list*/
ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs" style=statistical image_dpi=300 ;
ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Figure 2 benchmark comparison Annotated';
options orientation=landscape ;
proc sgplot data=plot sganno=anno2 noautolegend nocycleattrs;
refline .0384/lineattrs=(pattern=solid thickness=1 color=black);
refline 8 14/lineattrs=(pattern=thindot thickness=2) axis=x;
scatter x=order2 y=mean_match_death/ yerrorlower=lower_match yerrorupper=upper_match markeroutlineattrs=(color=black) noerrorcaps markerattrs=(color=black symbol=circlefilled ) errorbarattrs=(color=black) legendlabel="Benchmark";
scatter x=order2 y=y1/ datalabel=site markerattrs=(color=green symbol=circlefilled)   markeroutlineattrs=(color=green) errorbarattrs=(color=green ) legendlabel="Hospital";
scatter x=order2 y=y2/datalabel=site markerattrs=(color=gray symbol=circlefilled)  markeroutlineattrs=(color=gray) errorbarattrs=(color=gray) legendlabel="Hospital";
scatter x=order2 y=y3/datalabel=site markerattrs=(color=red symbol=circlefilled)  markeroutlineattrs=(color=red) errorbarattrs=(color=red) legendlabel="Hospital";
xaxis label="Hospital" values=(1 to 20 by 1) display=(novalues);
yaxis label="Mortality within 30 days (%)" values=(0 0.02 0.04 0.06 0.08) valuesdisplay=("0%" "2%" "4%" "6%" "8%");
run;

data tm.annotated;
set plot;
keep site sta6a_name;
run;

proc export data=tm.annotated outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision BMJ Quality and Safety/New Analysis/Graphs/annotated.xlsx"
dbms=xlsx; run;
