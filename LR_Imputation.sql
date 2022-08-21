-- Imputacja zmiennej BoilGravity metody imputacji regresyjnej

-- Projekt obejmuje następujące etapy:
-- Wyznaczenie odsetka brakujących wartoœci
-- Zbadanie siły zależności poprzez obliczenie wspo³czynnika korelacji Pearsona pomiêdzy zmienną FG i Boil Gravity
-- Wyznaczenie parametrów strukturalnych modelu regresji liniowej za pomocą MNK
-- Obliczenie błędu oszacowania za pomocą modelu LR
-- Wygenerowanie tabeli zbiorczej statystyk danych z etapów przed i po przeprowadzonej emputacji
-- Przeprowadzono imputacje z wykorzystaniem œredniej
-- Eliminacja tabel pomocniczych

--a) Wyœwietlenie zestawu bazy danych
SELECT TOP(10) * FROM recipies;

--b) Wyliczenie liczby braków zmiennej  BoilGravity, procent braków
DECLARE @n INT
SELECT @n = COUNT(*) FROM recipies
SELECT COUNT(*) AS [liczba brakow], (COUNT(*) / CAST(@n AS FLOAT ))*100 AS [procent braków] FROM recipies WHERE BoilGravity IS NULL;
--Wniosek: 4% wszystkich rekordów to brakujące dane

--c) Obliczenie wspó³czynnika korelacji pearsona pomiêdzy zmienną FG a BoilGravity
SELECT (Avg(BoilGravity * FG) - (Avg(BoilGravity) * Avg(FG))) / (StDevP(BoilGravity) * StDevP(FG))  as PearsonCoefficient FROM recipies;
--Wniosek: Otrzymany wspó³czynnik korelacji Pearsona (0.92) wskazuje na wystêpowanie silnej zale¿noœci pomiêdzy zmienną FG i Boil Gravity

--d) Obliczenie wspó³czynników metodą MNK y = mx + b i umieszczenie ich w tabeli regressor
DECLARE @n INT
SELECT @n = COUNT(*) FROM recipies
SELECT (@n * SUM(FG*BoilGravity) - SUM(FG) * SUM(BoilGravity)) / (@n * SUM(FG*FG) - SUM(FG) * SUM(FG)) AS M,
       AVG(BoilGravity) - AVG(FG) *
       (@n * SUM(FG*BoilGravity) - SUM(FG) * SUM(BoilGravity)) / (@n * SUM(FG*FG) - SUM(FG) * SUM(FG)) AS B INTO regressor FROM recipies;

--Weryfikacja zawartoœci tabeli regressor - czy zawiera parametry strukturalne naszego modelu regresyjnego
SELECT M,B FROM regressor

-- e) przeprowadzenie imputacji metodą regresji
SELECT FG, BoilGravity, r.B+rp.FG*r.M AS BG_imputed  INTO regress_impu_results FROM recipies rp, regressor r ;
SELECT TOP(10) * FROM regress_impu_results;

-- f) Obliczenie statystyk
-- Œredni b³ąd imputacji
SELECT AVG(BoilGravity - BG_imputed) FROM regress_impu_results WHERE BoilGravity IS NOT NULL;

-- Przed imputacją - Obliczamy statystyki dla etapu z przed przeprowadzonia imputacji
SELECT 'przed_imp' as etap,
		COUNT(BoilGravity) AS count_bg,
		MIN(BoilGravity) as min_bg, 
		MAX(BoilGravity) AS max_bg,
		AVG(BoilGravity) AS avg_bg, 
		STDEV(BoilGravity) AS std_bg,
		(SELECT DISTINCT PERCENTILE_DISC(0.25) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as first_quantile,
		(SELECT DISTINCT PERCENTILE_DISC(0.75) 
			WITHIN GROUP (ORDER BY BoilGravity) OVER () FROM regress_impu_results) as third_quantile
INTO statystyki
FROM regress_impu_results WHERE BoilGravity IS  NOT NULL;

-- Statystyki wy³ącznie wartoœci imputowanych - obliczamy statystyki dla jednostek, które zosta³y poddane imputacji - braków
INSERT INTO statystyki (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
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

-- Zmienna po imputacji - obliczamy statystyki dla wszystkich jednostek 
--g) Uzupe³nienie pustych wartoœci
UPDATE regress_impu_results SET
    BoilGravity = BG_imputed
	WHERE BoilGravity IS NULL;

INSERT INTO statystyki (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
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

-- h) Wyœwietlenie zbiorczej tabeli i wnioski
SELECT * FROM statystyki;
--					n	     min    max		stdev	q1			q3
--przed_imputacja  70871	 0	   52,6 	1,93	1,04		1,06
--tylko braki      2990	   1,04    18,30 	 0,9	1,04		1,06
--po_imputacji	   73861	 0	   52,6		1,90	1,04	    1,063


--i) imputacja za pomocą œredniej
SELECT FG, BoilGravity INTO mean_impu_results FROM recipies;


DECLARE @mean float;
SELECT @mean = AVG(BoilGravity) FROM mean_impu_results;

UPDATE mean_impu_results SET
    BoilGravity = @mean WHERE BoilGravity IS NULL;

INSERT INTO statystyki (etap, count_bg, min_bg,max_bg,avg_bg, std_bg, first_quantile, third_quantile)
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

SELECT * FROM statystyki;
--				 n	    min      max     avg     stdev	 q1		 q3				opis
				----------------------------------------------------------------------------------
--mean_imp		73861	 0		52,6	1,35	1,89	1,04	1,06		imputacja œrednia
--przed_imp		70871	 0		52,6	1,35	1,93	1,04	1,06		przed imputacją, z brakami
--imputo		2990	1,04	18,30	1,18	0,90	1,1		1,12		statystyki imputowanych jednostek - braków
--po_imp		73861	 0		52,6	1,35	1,9		1,04	1,06		statystyki  wraz z imputowanymi brakami
				-----------------------------------------------------

--j) Usuniecie tabeli pomocniczych
DROP TABLE regress_impu_results;
DROP TABLE mean_impu_results;
DROP TABLE regressor;
DROP TABLE statystyki;
