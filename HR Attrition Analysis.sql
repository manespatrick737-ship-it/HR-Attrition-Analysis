SELECT * FROM hr_attrition;

-- Removing duplicates (No Duplicate Records)
-- Standardized the Data (Standardized the 'Age' Column Name
-- Null Values (No Null Values)
-- Drop Columns (No Columns need to drop)

CREATE TABLE hr_attrition_staging
SELECT * FROM hr_attrition;


-- Checking of duplicates
WITH staging AS 
(
SELECT 
*,
ROW_NUMBER() OVER(PARTITION BY Attrition, BusinessTravel, Department, DistanceFromHome, Education, EducationField, EmployeeNumber, HourlyRate) as row_num
FROM hr_attrition_staging
)
SELECT *
FROM staging
WHERE row_num > 1;

SELECT * FROM hr_attrition_staging;

-- Standardized the Data
ALTER TABLE hr_attrition_staging
CHANGE `ï»¿Age` Age INT;

SELECT * FROM hr_attrition_staging


-- Attrition Heat Map
WITH total_num_employees AS
(
SELECT
Department, 
COUNT(*) AS total_employees
FROM hr_attrition_staging
GROUP BY 1
), 
num_of_attrition AS 
(
SELECT
Department,
COUNT(*) as total_attrition
FROM hr_attrition_staging
WHERE Attrition = 'Yes'
GROUP BY 1
)
SELECT
total_num_employees.Department, 
total_num_employees.total_employees,
num_of_attrition.total_attrition,
ROUND(((num_of_attrition.total_attrition / total_num_employees.total_employees) * 100.0),2) as attrition_rate
FROM total_num_employees
JOIN num_of_attrition
ON total_num_employees.Department = num_of_attrition.Department
ORDER BY 4 DESC;


-- Promotion Gap
WITH att_last_promotion AS
(
SELECT
JobRole,
ROUND(AVG(YearsSinceLastPromotion),2) as attrition_avg_last_promotion
FROM hr_attrition_staging
WHERE Attrition = 'Yes'
GROUP BY 1
ORDER BY 2 DESC
), stayed_last_promotion AS
(
SELECT
JobRole,
ROUND(AVG(YearsSinceLastPromotion),2) as stayed_avg_last_promotion
FROM hr_attrition_staging
WHERE Attrition = 'No'
GROUP BY 1
ORDER BY 2 DESC
)
SELECT
a.JobRole,
a.attrition_avg_last_promotion,
s.stayed_avg_last_promotion,
ROUND(a.attrition_avg_last_promotion - s.stayed_avg_last_promotion, 2) AS promotion_lag
FROM att_last_promotion a
JOIN stayed_last_promotion s 
ON a.JobRole = s.JobRole
ORDER BY 4 DESC; 


-- High Earner Churn
SELECT
EmployeeNumber,
JobRole,
Department,
TotalWorkingYears,
MonthlyIncome
FROM hr_attrition_staging 
WHERE Attrition = 'Yes'
ORDER BY 5 DESC
LIMIT 10; 


-- Overtime and Burnout
SELECT
OverTime,
COUNT(*) as total_employees,
SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS total_attrition,
ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)* 100 / COUNT(*)),2)  as attrition_rate
FROM hr_attrition_staging
GROUP BY OverTime;


-- Income vs Satisfaction Ranking
WITH salary_ranks AS
(
SELECT
EmployeeNumber,
JobRole,
Department,
MonthlyIncome,
DENSE_RANK () OVER(PARTITION BY Department ORDER BY MonthlyIncome DESC) as salary_ranking
FROM hr_attrition_staging
WHERE JobSatisfaction IN (1,2)  
AND PerformanceRating = 4
)
SELECT
EmployeeNumber,
Department,
MonthlyIncome,
salary_ranking
FROM salary_ranks
ORDER BY salary_ranking ASC, MonthlyIncome DESC; 


-- The "Loyalty" Threshold
WITH role_avg_years AS
(
SELECT 
JobRole,
ROUND(AVG(YearsAtCompany),2) as avg_years
FROM hr_attrition_staging
GROUP BY JobRole
)
SELECT
h.EmployeeNumber,
h.JobLevel,
h.JobRole,
h.YearsAtCompany,
r.avg_years
FROM hr_attrition_staging h 
LEFT JOIN role_avg_years r
ON h.JobRole = r.JobRole
WHERE h.YearsAtCompany > r.avg_years
AND JobLevel <= 2
ORDER BY 3 ASC, 2 ASC, 4 DESC;


-- Distance from Home Analysis
WITH commute_distance AS
(
SELECT
CASE
	WHEN DistanceFromHome BETWEEN 1 and 5 THEN 'Short (0-5)'
    WHEN DistanceFromHome BETWEEN 6 and 15 THEN 'Medium (6-15)'
	ELSE 'Long (15+)' END as commute_distance,
COUNT(*) as total_count,
SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) as attrition_count
FROM hr_attrition_staging
GROUP BY commute_distance
ORDER BY attrition_count DESC
)
SELECT
commute_distance,
total_count,
attrition_count,
ROUND((attrition_count * 100.0 )/ total_count,2) as attrition_rate
FROM commute_distance
ORDER BY attrition_rate DESC;


-- Managerial Impact
WITH relationship_status AS
(
SELECT 
EmployeeNumber,
JobRole,
Attrition
FROM hr_attrition_staging
WHERE YearsWithCurrManager > 5
AND RelationshipSatisfaction = 1
)
SELECT
Attrition,
COUNT(*) as num_of_emp
FROM relationship_status
GROUP BY Attrition; 


-- Training and Retention
WITH att_avg_training AS
(
SELECT
Department,
ROUND(AVG(TrainingTimesLastYear),2) as att_avg_training
FROM hr_attrition_staging
WHERE Attrition = 'Yes'
GROUP BY Department
), noatt_avg_training AS
(
SELECT
Department,
ROUND(AVG(TrainingTimesLastYear),2) as not_att_avg_training
FROM hr_attrition_staging
WHERE Attrition = 'No'
GROUP BY Department
)
SELECT
a1.Department,
a1.att_avg_training, 
a2.not_att_avg_training,
(a2.not_att_avg_training - a1.att_avg_training) AS training_gap
FROM att_avg_training a1
JOIN noatt_avg_training a2
ON a1.Department = a2.Department; 


-- Salary Hike vs Performance
SELECT
Attrition,
SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 1 END) as attrition_count,
ROUND(AVG(PercentSalaryHike),2) as avg_percent_sal_hike,
SUM(CASE WHEN PercentSalaryHike < 15 THEN 1 ELSE 0 END) as insult_hike_count
FROM hr_attrition_staging
WHERE PerformanceRating = 4
GROUP BY 1;

 

