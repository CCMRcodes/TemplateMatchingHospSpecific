%include '/data/dart/2017/ord_prescott_comparing/Programs/formats.sas';
%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/with labs/larger template/Redone September2019";

proc sql;
create table matches as
select distinct iteration, template, count(distinct anon_hosp) as number_hosps_matched, anon_hosp
from tm.good_matches
group by iteration, template;
quit;

proc sql;
create table rec as
select a.*, b.best_iteration
from matches  a
left join tm.best_iteration b
on a.template=b.template;
quit;

data rec;
set rec;
where iteration=best_iteration;
run;

proc sort data=rec; by template anon_hosp; run;

proc sort data=rec; by anon_hosp template; run;

data a;
set rec (keep=template number_hosps_matched);
run;

proc sort data=a nodupkey; by template; run;

data b;
set rec;
by anon_hosp;
if first.anon_hosp then serve_match=0;
serve_match+1;
run;

proc sql;
create table b as
select distinct anon_hosp, max(serve_match) as serve_match
from b
group by anon_hosp;
quit;


proc sql;
create table ab as
select a.*, b.serve_match
from a a
left join b b
on a.template=b.anon_hosp;
quit;

data ab;
set ab;
if missing(serve_match) then serve_match=0;
run;


/*proc sgplot data=ab;*/
/*scatter x=number_hosps_matched y=serve_match;*/
/*xaxis label="Number of hospital matches" values=(0 to 122);*/
/*yaxis label="Number of times hospital served as match" values=(0 to 122);*/
/*run;*/

data tm.recip;
set rec;
run;

proc sort data=tm.recip; by template anon_hosp;run;

/*proc export data=tm.recip outfile="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/with labs/larger template/Redone September2019/recip.csv"*/
/*dbms=csv; run;*/



data test;
set tm.recip;
keep template anon_hosp a b;
a=template;
b=anon_hosp;
run;

data test2;
set tm.recip;
keep template anon_hosp a b;
a=anon_hosp;
b=template;
run;

data both;
set test(keep=a b) test2(keep=a b);
run;


data both;
set both;
total=a+b;
run;

proc sort data=both; by a b; run;

proc sql;
create table both as
select a.*, b.number_hosps_matched
from both a
left join ab b
on a.a=b.template;
quit;

proc sort data=both; by number_hosps_matched a; run;

data both;
set both;
drop order;
run;

data both;
set both;
by number_hosps_matched a;
retain order;
if a ne lag(a) then order+1;
run;

proc sql;
create table key as
select distinct order, a as b
from both;
quit;

proc sql;
create table both as
select a.*, b.order as order2
from both a
left join key b
on a.b=b.b;
quit;

proc sort data=both; by order; run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Output/Hospital Specific/Graphs" style=statistical image_dpi=300 ;
ods graphics/ width=30in height=30in aTTRPRIORITY=none imagefmt=tiff imagename='Figure Reciprocal Matches Heat Map 2';
proc sgplot data=both;
heatmap x=order y=order2/discretex discretey colormodel=(gray black);
xaxis display=(nolabel) discreteorder=data values=(1 to 122 by 1);
yaxis display=(nolabel) discreteorder=data values=(1 to 122 by 1);
run;

