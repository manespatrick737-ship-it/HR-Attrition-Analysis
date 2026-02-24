# Introduction
Company XYZ is interested to find out any underlying causes of employees leaving their company. This project focuses on analyzing the employee attrition dataset to see any trends and causes on why employees leave the company. 

# Background
As companies of today's age are trying their best to retain their best employees, Company XYZ has decided to further dig deep the Attrition Data they have and analyze what are the underlying causes on why employees leave their company. From this analysis, we'll come up with key insights, conclusions and recommendations on how we can retain Company XYZ's employees effectively. 

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
JobLevel,
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
### 6. Distance from Home Analysis
- I categorized the raw commute data into three distinct buckets—Short, Medium, and Long—using a CASE statement to make the distance metrics more actionable. Within these groups, I used conditional aggregation to count total employees and specific attrition count simultaneously. I then calculated the attrition rate for each bucket to determine if longer commutes significantly increased the likelihood of an employee leaving. By joining these metrics in a CTE, I was able to transform thousands of individual distances into a clear trend report.

```SQL
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

```

### 7. Managerial Impact
- I isolated a high-risk group of long-tenured employees who have worked under the same manager for over five years. I further refined this list by filtering for those reporting the lowest possible relationship satisfaction score to identify "unhappy veterans." Using a CTE, I extracted their specific roles and attrition status to see if these broken relationships were leading to actual departures. I then aggregated the final count by attrition status to quantify exactly how many of these individuals had already left versus those still at risk.

```SQL
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

```

### 8. Training and Retention
- I investigated the impact of professional development by creating two separate CTEs to calculate the average training frequency for employees who left versus those who stayed. By grouping these averages by department, I was able to observe how learning opportunities vary across different business units. I then joined these datasets to compare the two groups side-by-side, revealing whether a lack of training correlated with higher turnover. To make the data actionable, I calculated a "Training Gap" column to quantify the specific investment difference between retained and lost talent.

```SQL
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

```

# What I Learned
Here is a quick breakdown of the Employee Attrition Analysis:

**Promotion Gap** - the length on how long it takes for an employee to be promoted affects their retention as seen from the Promotion Gap Analysis we have done. Research Director, Healthcare Representative, Sales Executive, and Research Scientist are the Job Roles to look out for. 

**Mid to Senior Level Attrition** - As seen on the High Earner Churn Analysis. The Top 10 Highest earners who left the company came from Mid to Senior Level (Job Level's 3 to 5). 

**Overtime and Burnout** - Overtime and Burnout is a strong indicator of attrition amongst employees showing a 30% attrition rate to those who have reported they do overtime compared to a 10% attrition rate to those who have not. 

**Income vs Satisfaction** - We have ranked employees based on their monthly income with the highest performance rating (4) but the lowest Job Satisfaction (1 and 2). Most employees came from the Research and Development Department with a count of 63 employees followed by Sales with 23 employees and lastly Human Resources with 3 employees. 

**Commute Distance contributes to Attrition Increase** - From our Distance from Home Analysis, we have seen that the longer the commute distance, attrition rate increases as well. 

**Managerial Impact** - On our Managerial Impact Analysis, we only had a total of 16 employees who had left the company due to a 
low relationship satisfaction with their Manager. Although the number is low, we still need to keep an eye on this as this may be a trend in the future. 

**Training Gap** - We have seen from our analysis that there is small correlation on how much training an employee receives last year to attrition. The less training they receive, they are more likely to leave the company. 


# Recommendations 

**Employee Sucession Plan** - To resolve the Promotion Gap issue, each manager should introduce a career progression/succession plan to each of their employees they have. This give transparency, timeline, and a clear direction to those employees what's next or what steps they need to achieve, giving them the motivation to step up in the career ladder. 

**Workplace Audit**  - To further deep dive the Overtime and Burnout issue, we must do an audit on how our current workplace operates. We must recognize the bottlenecks first that causes employees to do overtime on their work (i.e. manual tasks, endless meetings, workload distribution etc.). From there, we can do a separate analysis what these bottlenecks are and how we can resolve this. 

**Remote Work Implementation** -  As seen from our analysis, most employees who have long commute distance tends to leave the company. We can implement a remote work setup depending on the distance of where the employee lives and the office location. 

**Company Competitiveness Benchmarking** - We might need to do Company Competitiveness benchmarking based from industry and competitor standard to make sure what we offer is on par and possibly better on industry standards. 

**Invest on quality Training** - Make sure that the training we provide our amongst the best in industry standards as this not only helps the employee and company's growth but the attrition rate as well. 

**Manager Training** - Invest on mangerial training especially on interpersonal and soft skills a manager must have. This combats a future trend of employee attrition due to poor manager relationship satisfaction. 

# Closing Thoughts

The project really challenged my competency in my SQL skills. The dataset provided contains a lot of valuable key information regarding key indicators and insights why an employee may left the company and a common theme on why employees leave the company based from my analysis stem from employee satisfaction. As a company, we must prioritize as well an employee's wellbeing and satisfaction since they are one of the pillars that makes the company successful. 
