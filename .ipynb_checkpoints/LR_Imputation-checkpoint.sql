--a) Read our data
SELECT TOP(10) * FROM recipies;

--b) Check number of missings
DECLARE @n INT
SELECT @n = COUNT(*) FROM recipies
SELECT COUNT(*) AS [n_lacks], (COUNT(*) / CAST(@n AS FLOAT ))*100 AS [prcnt_lacks] FROM recipies WHERE BoilGravity IS NULL;
--Results: 4% of all records are missings

--c) Pearson correlation coefficient 
SELECT (Avg(BoilGravity * FG) - (Avg(BoilGravity) * Avg(FG))) / (StDevP(BoilGravity) * StDevP(FG))  as PearsonCoefficient FROM recipies;
--Wniosek: Otrzymany wspó³czynnik korelacji Pearsona (0.92) wskazuje na wystêpowanie silnej zale¿noœci pomiêdzy zmienną FG i Boil Gravity

--d) Ordinary Least Squares method
DECLARE @n INT
SELECT @n = COUNT(*) FROM recipies
SELECT (@n * SUM(FG*BoilGravity) - SUM(FG) * SUM(BoilGravity)) / (@n * SUM(FG*FG) - SUM(FG) * SUM(FG)) AS M,
       AVG(BoilGravity) - AVG(FG) *
       (@n * SUM(FG*BoilGravity) - SUM(FG) * SUM(BoilGravity)) / (@n * SUM(FG*FG) - SUM(FG) * SUM(FG)) AS B INTO #regressor FROM recipies;

-- Temporary table with regression coefficients
SELECT M,B FROM #regressor

-- e) Imputation
SELECT FG, BoilGravity, r.B+rp.FG*r.M AS BG_imputed  INTO regress_impu_results FROM recipies rp, #regressor r ;
SELECT TOP(10) * FROM regress_impu_results;

-- f) Statistics of performed imputation
-- Average Error of imputation
SELECT AVG(BoilGravity - BG_imputed) FROM regress_impu_results WHERE BoilGravity IS NOT NULL;

-- Before imputation - statistics
SELECT 'przed_imp' as etap,
		COUNT(BoilGravity) AS count_bg,
		MIN(BoilGravity) as min_bg, #
		MAX(BoilGravity) AS max_bg,
		AVG(BoilGravity) AS avg_bg, 
		STDEV(BoilGravity) AS std_bg,
		(SELECT DISTINCT PERCENTILE_DISC(0.25) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as first_quantile,
		(SELECT DISTINCT PERCENTILE_DISC(0.75) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as third_quantile
INTO statistics
FROM regress_impu_results WHERE BoilGravity IS  NOT NULL;

-- After imputation - statistics
INSERT INTO statistics (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
SELECT 'imputo' as etap,
		COUNT(BG_imputed) AS count_bg,
		MIN(BG_imputed) as min_bg, 
		MAX(BG_imputed) AS max_bg,
		AVG(BG_imputed) AS avg_bg, 
		STDEV(BG_imputed) AS std_bg,
		(SELECT DISTINCT PERCENTILE_DISC(0.25) 
			WITHIN GROUP (ORDER BY BG_imputed) OVER () FROM regress_impu_results) as first_quantile,
		(SELECT DISTINCT PERCENTILE_DISC(0.75) 
			WITHIN GROUP (ORDER BY BG_imputed) OVER () FROM regress_impu_results) as third_quantile
FROM regress_impu_results WHERE BoilGravity IS NULL;

-- After imputation - statistics for all 
--g) Update of table with imputed values
UPDATE regress_impu_results SET
    BoilGravity = BG_imputed
	WHERE BoilGravity IS NULL;

INSERT INTO statistics (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
SELECT 'po_imp' as etap,
		COUNT(BoilGravity) AS count_bg, 
		MIN(BoilGravity) as min_bg, 
		MAX(BoilGravity) AS max_bg, 
		AVG(BoilGravity) AS avg_bg, 
	    STDEV(BoilGravity) AS std_bg,
		(SELECT DISTINCT PERCENTILE_DISC(0.25) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as first_quantile,
		(SELECT DISTINCT PERCENTILE_DISC(0.75) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as third_quantile
FROM regress_impu_results;

-- h) 
SELECT * FROM statistics;
--					n	     min    max		stdev	q1			q3
--przed_imputacja  70871	 0	   52,6 	1,93	1,04		1,06
--tylko braki      2990	   1,04    18,30 	 0,9	1,04		1,06
--po_imputacji	   73861	 0	   52,6		1,90	1,04	    1,063


--i) imputation using average
SELECT FG, BoilGravity INTO mean_impu_results FROM recipies;

DECLARE @mean float;
SELECT @mean = AVG(BoilGravity) FROM mean_impu_results;

UPDATE mean_impu_results SET
    BoilGravity = @mean WHERE BoilGravity IS NULL;

INSERT INTO statistics (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
SELECT 'mean_imp' as etap,
		COUNT(BoilGravity) AS count_bg, 
		MIN(BoilGravity) as min_bg, 
		MAX(BoilGravity) AS max_bg, 
		AVG(BoilGravity) AS avg_bg, 
	    STDEV(BoilGravity) AS std_bg,
		(SELECT DISTINCT PERCENTILE_DISC(0.25) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM mean_impu_results) as first_quantile,
		(SELECT DISTINCT PERCENTILE_DISC(0.75) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM mean_impu_results) as third_quantile

FROM mean_impu_results;

select top 10 * from mean_impu_results;

SELECT * FROM statistics;
--				 n	    min      max     avg     stdev	 q1		 q3				opis
				----------------------------------------------------------------------------------
-- mean imputation		73861	 0		52,6	1,35	1,89	1,04	1,06		imputacja œrednia
--after_imp		70871	 0		52,6	1,35	1,93	1,04	1,06		przed imputacją, z brakami
--only imuted		2990	1,04	18,30	1,18	0,90	1,1		1,12		statistics imputowanych jednostek - braków
--after imputation		73861	 0		52,6	1,35	1,9		1,04	1,06		statistics  wraz z imputowanymi brakami
				-----------------------------------------------------

--j) Deletion of auxiliary table
DROP TABLE regress_impu_results;
DROP TABLE mean_impu_results;
DROP TABLE #regressor;
DROP TABLE statistics;
