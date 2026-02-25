*******************************************************
* Hill-Burton data task (state-year allocations), 1947–1964
* Author: Maria Luiza Sena Gomes da Costa
*
* Inputs:
*   - pcinc.csv  : BEA per-capita personal income (1943–1962)
*   - pop.csv    : BEA population (1947–1964)
*   - hbpr.txt   : Hill-Burton Project Register (project-level)
*
* Outputs:
*   - hill_burton_state_panel.dta : final labeled state-year panel
*   - fig_actual_vs_predicted.png : scatterplot
*   - results.txt                 : regression + summary stats
*******************************************************

clear all
set more off

*******************************************************
* Clean state names
*******************************************************
capture program drop _clean_state
program define _clean_state
    replace state = strtrim(state)
end

*******************************************************
* 1) Income: pcinc.csv -> state(fips)-year long + smoothed
*******************************************************

import delimited using "pcinc.csv", varnames(1) clear

rename areaname state
rename fips fips_str
drop if state == "United States"
_clean_state

* Keep only from 1-56, since the rest are regions (not states) 
destring fips_str, gen(fips) force
keep if inrange(fips,1,56)

* Drop Alaska (2), DC (11), Hawaii (15)
drop if inlist(fips,2,11,15)

* Rename year columns explicitly 
rename v4  inc1943
rename v5  inc1944
rename v6  inc1945
rename v7  inc1946
rename v8  inc1947
rename v9  inc1948
rename v10 inc1949
rename v11 inc1950
rename v12 inc1951
rename v13 inc1952
rename v14 inc1953
rename v15 inc1954
rename v16 inc1955
rename v17 inc1956
rename v18 inc1957
rename v19 inc1958
rename v20 inc1959
rename v21 inc1960
rename v22 inc1961
rename v23 inc1962

* Ensure consistent numeric type for reshape
foreach v of varlist inc1943-inc1962 {
    capture confirm string variable `v'
    if !_rc {
        destring `v', replace force ignore(",")
    }
    recast double `v'
}

reshape long inc, i(state fips) j(year)
rename inc pcinc
keep if inrange(year,1943,1962)
recast int year

* Extend panel to 1964 so we can compute smoothed income for 1963-64
tsset fips year, yearly
tsappend, add(2)   // adds 1963 and 1964
bys fips (year): replace state = state[_n-1] if missing(state)

* Smoothed income for allocation year y uses years y-4, y-3, y-2
gen pcinc_smoothed = (L4.pcinc + L3.pcinc + L2.pcinc)/3

keep if inrange(year,1947,1964)

* National average of the smoothed state per capita income variable by year
bys year: egen nat_avg_pcinc = mean(pcinc_smoothed)

* Index number for each state*year
gen index = pcinc_smoothed / nat_avg_pcinc

* Allotment percentage for each state*year
gen allot_pct = 1 - 0.5*index

* Enforce minimum and maximum requirements for allotment percentage
replace allot_pct = 0.33 if allot_pct < 0.33
replace allot_pct = 0.75 if allot_pct > 0.75

tempfile inc_panel
save `inc_panel', replace

*******************************************************
* 2) Population: pop.csv -> long 1947-1964
*******************************************************

import delimited using "pop.csv", varnames(1) clear

rename areaname state
rename fips fips_str
_clean_state

destring fips_str, gen(fips) force
keep if inrange(fips,1,56)
drop if inlist(fips,2,11,15)

* Rename year columns by extracting 4-digit year from variable labels
ds
local allvars `r(varlist)'
foreach v of local allvars {
    if inlist("`v'","state","fips_str","fips") continue
    local lab : variable label `v'
    local lab = subinstr(`"`lab'"', `"""', "", .)
    local lab = strtrim(`"`lab'"')
    if regexm(`"`lab'"', "(19[0-9]{2})") {
        local yr = regexs(1)
        capture rename `v' pop`yr'
    }
}

* Ensure required pop vars exist
capture confirm variable pop1947
if _rc {
    di as error "Population rename failed (pop1947 missing). Run: describe (pop.csv) and paste output."
    exit 198
}

foreach v of varlist pop1947-pop1964 {
    capture confirm string variable `v'
    if !_rc {
        destring `v', replace force ignore(",")
    }
    recast double `v'
}

reshape long pop, i(state fips) j(year)
keep if inrange(year,1947,1964)
recast int year

tempfile pop_panel
save `pop_panel', replace

*******************************************************
* 3) Merge income + population and compute allocation share
*******************************************************

use `inc_panel', clear
merge 1:1 fips year using `pop_panel'
* Keep matched only; if not matched, diagnose 
capture assert _merge==3
if _rc {
    di as error "Income-population merge mismatch. Tabulating _merge:"
    tab year _merge
    list state fips year in 1/200 if _merge!=3, sepby(year)
    exit 459
}
drop _merge

* Weighted population for each state*year
gen wt_pop = (allot_pct^2) * pop

* State allocation share for each state*year
bys year: egen total_wt_pop = total(wt_pop)
gen alloc_share = wt_pop / total_wt_pop

*******************************************************
* 4) Appropriations and predicted funding
*******************************************************

* Annual national Hill-Burton federal appropriations for 1948-1972
preserve
clear
input year appropr
1947 75000000
1948 75000000
1949 75000000
1950 150000000
1951 85000000
1952 82500000
1953 75000000
1954 65000000
1955 96000000
1956 109800000
1957 123800000
1958 120000000
1959 185000000
1960 185000000
1961 185000000
1962 209728000
1963 220000000
1964 220000000
end
recast int year
tempfile appr
save `appr', replace
restore

merge m:1 year using `appr'
capture assert _merge==3
if _rc {
    di as error "Appropriations merge mismatch. Tabulating years:"
    tab year _merge
    list state fips year in 1/200 if _merge!=3, sepby(year)
    exit 459
}
drop _merge

* Predicted Hill-Burton allocation for each state*year
gen predicted = alloc_share * appropr

* Enforce minimum requirements for predicted allocations
replace predicted = 100000 if year==1948 & predicted < 100000
replace predicted = 200000 if year>=1949 & predicted < 200000

tempfile pred_panel
save `pred_panel', replace

*******************************************************
* 5) Actual Hill-Burton funds: hbpr.txt -> state-year totals
*******************************************************

import delimited using "hbpr.txt", delimiter(tab) varnames(1) clear

* Lower-case all variable names to avoid capitalization issues
ds
foreach v of varlist _all {
    local low = lower("`v'")
    if "`v'" != "`low'" {
        rename `v' `low'
    }
}

rename hillburtonfunds hbf_raw

* hbpr years are 2-digit (47..). Convert to 4-digit.
destring year, replace force
gen year_full = cond(year<100, 1900+year, year)
drop year
rename year_full year
recast int year
_clean_state

tostring hbf_raw, replace
replace hbf_raw = subinstr(hbf_raw, ",", "", .)
replace hbf_raw = subinstr(hbf_raw, char(34), "", .)
destring hbf_raw, gen(hbfunds) force

collapse (sum) hbfunds, by(state year)

tempfile hb_stateyear
save `hb_stateyear', replace

*******************************************************
* 6) Final merge predicted + actual + output files
*******************************************************

use `pred_panel', clear

* Keep only predicted panel observations; bring in actuals when available.
merge 1:1 state year using `hb_stateyear', keep(master match) nogen
replace hbfunds = 0 if missing(hbfunds)

* Restrict to task panel (1947-1964) and drop any accidental using-only spillovers
keep if inrange(year,1947,1964)
drop if missing(fips)

* Ensure unique panel keys
isid fips year
gen stateyear = lower(state) + " " + string(year)

label var predicted "Predicted Hill-Burton funds (formula)"
label var hbfunds   "Actual Hill-Burton funds (HBPR sum)"
label var allot_pct "Allotment percentage (bounded)"

keep state year stateyear predicted hbfunds allot_pct fips

* Balance checks: 48 states x 18 years = 864
count
assert _N == 48*18
bys year: assert _N == 48

* Final ordering: alphabetical by state within each year
sort year state

*Save final data set panel
save "hill_burton_state_panel.dta", replace

* Outputs for item 3
twoway (scatter hbfunds predicted, msize(vsmall)) ///
       (function y=x, range(predicted)), ///
       legend(off) ///
       ytitle("Actual Hill-Burton funds") ///
       xtitle("Predicted Hill-Burton funds") ///
       title("Actual vs. Predicted Hill-Burton Funding, 1947-1964")
graph export "fig_actual_vs_predicted.png", replace width(2000)

log using "results.txt", replace text
di "Correlation:"
corr hbfunds predicted
di ""
di "Regression: hbfunds on predicted"
reg hbfunds predicted
log close

*******************************************************
* End
*******************************************************