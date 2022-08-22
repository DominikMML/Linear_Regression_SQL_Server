# Linear_Regression_SQL_Server

## About the project
Linear regression imputation with assumption of Missing Completely at Random (MCAR). 
Missings are replaced by prediction using hightly-correlated explanatory variables.
Stages of processing are including:
- Determine the percentage of missing values.
- Testing the strength of dependence by calculating the Pearson correlation coefficient between the FG and Boil Gravity variables
- Determination of the structural parameters of the linear regression model using the LSM
- Calculation of the estimation error using the LR model
- Generating a summary table of data statistics from the stages before and after the emputation
- Performed imputations using the mean
- Deletion of temporary tables
