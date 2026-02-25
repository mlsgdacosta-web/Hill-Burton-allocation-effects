# Hill-Burton Allocation Formula Replication (1947–1964)

This project replicates the statutory formula used to allocate federal Hill-Burton hospital construction funds across U.S. states and evaluates whether the formula predicts actual funding allocations.

## Project Objective

The Hill-Burton Act distributed federal hospital construction funds using a formula based on:

- State per capita income  
- State population  
- National appropriations  
- Minimum and maximum allotment constraints  

This repository:

- Reconstructs predicted state-level allocations from the historical formula  
- Builds a balanced state-year panel (48 states, 1947–1964)  
- Compares predicted allocations to actual funding  
- Assesses whether statutory minimum and maximum allotment rules were binding  

## Data Sources

The analysis uses three primary datasets:

- BEA Per Capita Income (1943–1962)  
- BEA Population Data (1947–1964)  
- Hill-Burton Project Register (state-year funding data)  
- National federal appropriations (1947–1964)

All monetary values are treated as current dollars.

## Allocation Formula 

For each state-year:

1. Compute a 3-year average (“smoothed”) per capita income.  
2. Calculate the national average smoothed income (excluding AK, HI, DC).  
3. Compute an income index:

   income_index = state_smoothed_income / national_smoothed_income

4. Construct the allotment percentage:

   A = 1 - 0.5 × income_index

5. Impose bounds:

   0.33 ≤ A ≤ 0.75

6. Compute weighted population:

   weighted_pop = A² × population

7. Compute state allocation share:

   share = weighted_pop / sum(weighted_pop across states)

8. Compute predicted allocation:

   predicted = share × national_appropriation

9. Impose funding minimums:
   - $100,000 in 1948  
   - $200,000 in 1949–1964  

## Outputs

The project produces:

- A balanced state-year panel dataset  
- Predicted vs. actual funding comparison  
- A summary statistics table  
- A visualization of predicted vs. actual allocations  
- An empirical assessment of whether minimum/maximum allotment percentages bind  

## Why This Project Matters

This project evaluates whether a nonlinear statutory allocation rule meaningfully shaped federal funding outcomes.

It demonstrates:

- Panel data construction  
- Historical policy formula replication  
- Nonlinear constraint evaluation  
- Empirical validation of rule-based allocation  

## How to Run

1. Place input files in the working directory:
   - pcinc.csv
   - pop.csv
   - hbpr.txt

2. Run the provided script to:
   - Construct the balanced panel  
   - Generate predicted allocations  
   - Merge actual funding  
   - Produce summary outputs  

## Repository Structure

├── data/  
│   ├── pcinc.csv  
│   ├── pop.csv  
│   └── hbpr.txt  
├── code/  
│   └── hill_burton_allocation.R  
├── output/  
│   ├── final_panel.csv  
│   └── figures/  
└── README.md  

## Reference

Federal Security Agency (1946). Promulgation of state allotment percentages under Hospital Survey and Construction Act. Federal Register: 31 August 1946.

