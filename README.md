# Introduction
Company XYZ are interested to find out any underlying causes of employees leaving their company. This project focuses on analyzing the employee attrition dataset to see any trends and causes on why employees leave the company. 

# Background
As companies of today's age are trying their best to retain their best employees, Company XYZ has decided to further dig deep the Attrition Data they have and analyze what are the underlying causes on why employees leave their company. From this analysis, we'll come up with conclusions and recommendations on how we can retain Company XYZ's employees effectively. 

Company XYZ is only a fictional company and the dataset used for this project came from this [Kaggle Dataset](https://www.kaggle.com/datasets/itssuru/hr-employee-attrition). The data contains a lot of insights that about the employee information that we can use and derive for our Attrition Analysis. 

### The questions I wanted to answer through my SQL queries are the following:

#### 1. The Attrition Heatmap
- Calculate the attrition rate (the percentage of "Yes" vs. total employees) for each Department.

#### 2. The "Promotion Gap"
- Find the average Years Since Last Promotion for employees who left the company versus those who stayed. This would be grouped by **Job Role** to see if there are any specific roles are "stuck" longer than others.
  
#### 3. High-Earner Churn
- Identify the top 10 employees with the highest Monthly Income who have already left the company.

#### 4. Overtime & Burnout
- Does working extra hours show a clear correlation with leaving?

#### 5. Income vs. Satisfaction Rank
- Within each Department, rank employees by their Monthly Income (highest to lowest). Filter the results to only show employees who have a Job Satisfaction score of 1 or 2 and a Performance Rating of 4.

#### 6. Distance from Home Analysis
- Analyze if the commute distance of the employees correlates to attrition and retention of employees

#### 7. Managerial Impact
- Identify if the employee's current manager and relationship satisfaction correlate to Attrition. We'll be identifying employees who are working with their current manager for more than 5 years and a relationship satisfaction with a score of 1.

#### 8. Training & Retention
- Compare the average number of trainings times last year for those employees who have stayed compared to those who left. Does investment in training influence the decision to stay?

#### 9. Salary Hike vs Performance
- Find the average Percent Salary Hike for employees who received a Performance Rating of 3 vs 4. Then, calculate how many of those "High Performers" (Rating 4) left the company despite receiving a salary hike of less than 15%
  
# Tools I Used
For my deep dive into the employee attrition dataset, I have used the following key tools:

- **MySQL**: The main backbone and bulk of my analysis. This tool allows me to query the dataset to derive key insights.
- **Github**: This is to showcase my project analysis and share my SQL scripts that I have used. 

# The Analysis
Each query for this project aims to investigate specific aspects on Employee Attrition Dataset. Here's how I aproached each question:

### 1. The Attrition Heatmap
- To identify the Attrition Heatmap, I began by creating a baseline CTE to calculate the total headcount per department, establishing the necessary denominator for my analysis. Next, I built a second CTE to isolate only those who left the company, giving me a precise numerator of attrition counts per department. I then bridged these two distinct datasets using a "JOIN", which allowed me to align total staff levels with actual losses side-by-side.I applied a descending sort to the results, effectively generating a "Heatmap" that ranks departments by their level of turnover risk.

```SQL
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

```

### 2. The "Promotion Gap"
- I first constructed two separate CTEs to isolate the average years since the last promotion for both employees who left and those who stayed. By calculating these averages independently by job role, I established a clear baseline for career progression speeds across the company. I then joined these two tables on the JobRole column to compare the "stagnation" of former employees directly against their current peers. Using a subtraction formula, I calculated the "Promotion Lag," revealing exactly how many extra years turnover-prone employees were waiting for advancement. Finally, I sorted the results by the largest lag to highlight which roles were suffering from a "promotion bottleneck" that likely triggered resignations.

```SQL
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

```

### 3. High Earner Churn
- I focused my investigation on "High-Value Attrition" by filtering the dataset to isolate only those individuals who had already exited the company. To identify our most significant financial and talent losses, I selected key metrics including their role, department, and total industry experience. I specifically targeted the MonthlyIncome column and applied a descending sort to rank these departures from the highest earners to the lowest. By applying a LIMIT 10 clause, I narrowed the scope to a "Top 10" list of the company’s most expensive talent drains.

```SQL
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

```

### 4. Overtime and Burnout
- I analyzed the correlation between extra hours and turnover by grouping the entire workforce based on their OverTime status. Using conditional aggregation, I calculated the exact number of resignations within the overtime and non-overtime groups. I then divided these losses by the total headcount of each group to establish a comparable attrition rate

```SQL
SELECT
OverTime,
COUNT(*) as total_employees,
SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS total_attrition,
ROUND((SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)* 100 / COUNT(*)),2)  as attrition_rate
FROM hr_attrition_staging
GROUP BY OverTime;

```
### 5. Income vs Satisfaction Ranking
- I isolated a "high-risk" group by filtering for top-performing employees who reported low job satisfaction scores. I then applied a DENSE_RANK window function to rank their salaries relative only to others in their specific department. This allowed me to see where these unhappy high-performers stood on the pay scale compared to their direct peers. By ordering the final list by rank, I identified individuals who were both top of their field and top of the payroll, yet still dissatisfied.

  ```SQL
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
```

# What I Learned

# Conclusions
