%include '/data/dart/2017/ord_prescott_comparing/Programs/CCS/ccsformats.sas';

libname orig "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis";
libname tm "/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Random template id";


proc means data=orig.simulations;
var pred;
run;

%macro doests;
%do hosp=1 %to 122;
estimate "&hosp" int 1 pred 0.0376270
	|intercept 1/subject %do k=1 %to %eval(&hosp.-1); 0 %end; 1 ilink e cl;
%end;
%mend;

ods output parameterestimates=fixed solutionr=random covparms=cov estimates=estimates;
proc glimmix data=orig.simulations method=laplace noclprint;
class anon_hosp;
model mort30 (descending)= pred / link=logit dist=binary  solution cl or;
random intercept /sub= anon_hosp solution cl  g;
%doests;
run;
ods exclude none;

proc sort data=estimates; by mu; run;

data estimates;
set estimates;
hosp=_n_;
run;

/*Calculate MOR*/
data cov;
set cov;
lowerci=estimate-1.96*stderr;
upperci=estimate+1.96*stderr;
MOR=exp(0.6745*sqrt(2*estimate));
MOR_lower=exp(0.6745*sqrt(2*upperci));
MOR_upper=exp(0.6745*sqrt(2*lowerci));
run;


data estimates;
set estimates;
if statement not in (16, 24, 27, 38, 56, 70, 96, 120, 40, 46, 50, 51, 78) then rank="No Significant Difference in Mortality";
if statement in (16, 24, 27, 38, 56, 70, 96, 120) then rank="Significantly Lower Mortality";
if statement in (40, 46, 50, 51, 78) then rank="Significantly Higher Mortality";
run;

/*Compare template matching rank to number stars via regression*/
proc rank data=estimates out=ranks groups=5;
var mu;
ranks stars;
run;

data ranks;
set ranks;
stars=5-stars;
run;

proc freq data=ranks;
table rank*stars/nocol norow nopercent;
run;

/*Add a variable for the y axis so that the band will produce from 0 to 0.07 on the y-axis
--0.07 is the maximum mortality displayed*/
data estimates;
set estimates;
y1=0.07;
run;




/*ods html;*/
/*proc sgplot data=estimates;*/
/*styleattrs datacontrastcolors=(green black red) datasymbols=(circlefilled circlefilled circlefilled) datalinepatterns=(solid) ;*/
/*band y=y1 lower=24 upper=49/TRANSPARENCY=.5 fillattrs=(color=gainsboro);*/
/*band y=y1 lower=74 upper=98/TRANSPARENCY=.5 fillattrs=(color=gainsboro);*/
/*highlow x=hosp low=lowermu high=uppermu/group=rank legendlabel="95% CI" name="CI";*/
/*scatter x=hosp y=mu/group=rank jitter name="dot" ;*/
/*yaxis label="30-Day Adjusted Mortality Rate" values=(0 to  0.07 by 0.01);*/
/*xaxis display=none ;*/
/*keylegend "dot" /title="Hospital-Specific Template Matching" noborder across=1;*/
/*run;*/



data estimates2;
set estimates;
if rank='Significantly Lower Mortality' then do;
mu2=mu;
lowermu2=lowermu;
uppermu2=uppermu;
end;

if rank='Significantly Higher Mortality' then do;
mu3=mu;
lowermu3=lowermu;
uppermu3=uppermu;
end; 
run;

ods listing gpath="/data/dart/2017/ord_prescott_comparing/Programs/HospSpecific/Stratified/Revision to Medical Care/New Analysis/Graphs" style=statistical image_dpi=300 ;
ods graphics/ aTTRPRIORITY=none imagefmt=tiff imagename='Regression comparison';
options orientation=landscape ;

ods html;
proc sgplot data=estimates2;
/*styleattrs datacontrastcolors=(green black red) datasymbols=(circlefilled circlefilled circlefilled) datalinepatterns=(solid) ;*/
band y=y1 lower=24 upper=49/TRANSPARENCY=.5 fillattrs=(color=gainsboro);
band y=y1 lower=74 upper=98/TRANSPARENCY=.5 fillattrs=(color=gainsboro);


highlow x=hosp low=lowermu high=uppermu/legendlabel="95% CI" name="CI" lineattrs=(color=black thickness=1);
scatter x=hosp y=mu/ markerattrs=(color=black symbol=circlefilled size=8)  jitter name="dot" legendlabel="No Significant Difference in Mortality" ;


highlow x=hosp low=lowermu2 high=uppermu2/ legendlabel="95% CI" name="CI" lineattrs=(color=green thickness=2);
scatter x=hosp y=mu2/ markerattrs=(color=green symbol=circlefilled size=10) jitter name="dot2" legendlabel="Significantly Lower Mortality" ;

highlow x=hosp low=lowermu3 high=uppermu3/ legendlabel="95% CI" name="CI" lineattrs=(color=red thickness=2);
scatter x=hosp y=mu3/  markerattrs=(color=red symbol=circlefilled size=10) jitter name="dot3" legendlabel="Significantly Higher Mortality";

/*refline 24 49 73 98/axis=x ;*/
yaxis label="30-Day Adjusted Mortality Rate" values=(0 to  0.07 by 0.01);
xaxis display=none values=(1 to 122 by 1) ;
keylegend "dot2"  "dot" "dot3"/title="Hospital-Specific Template Matching" noborder across=1 ;
run;

/*Number of comparators for those hospitals with lower/higher/no different mortality*/

proc sql;
create table estimates as
select a.*, b.most_matches
from estimates a 
left join tm.hospital_match_counts_wide b
on a.statement=b.template;
quit;

proc means data=estimates min q1 median q3 max mean;
class rank;
var most_matches;
run;
