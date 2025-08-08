-- Identificar e tratar valores nulos
-- TABELA DEFAULT
SELECT *
FROM riscorelativo.default
WHERE user_id IS NULL
OR default_flag IS NULL
-- Nenhum valor nulo encontrado

-- TABELA LOANS_DETAIL
SELECT *
FROM `riscorelativo.loans_detail` WHERE user_id IS NULL
OR more_90_days_overdue IS NULL
OR using_lines_not_secured_personal_assets IS NULL
OR number_times_delayed_payment_loan_30_59_days IS NULL
OR debt_ratio IS NULL
OR number_times_delayed_payment_loan_60_89_days IS NULL;
-- Nenhum valor nulo encontrado

-- TABELA LOANS_OUTSTANDING
SELECT *
FROM `riscorelativo.loans_outstanding`
WHERE loan_id IS NULL
OR user_id IS NULL
OR loan_type IS NULL;
-- Nenhum valor nulo encontrado

-- TABELA USER_INFO
SELECT *
FROM `riscorelativo.user_info`
WHERE user_id IS NULL
OR age IS NULL
OR sex IS NULL
OR last_month_salary IS NULL
OR number_dependents IS NULL

SELECT *
FROM `riscorelativo.user_info`
WHERE last_month_salary IS NULL -- 7199 nulos encontrados

SELECT *
FROM `riscorelativo.user_info`
WHERE number_dependents IS NULL -- 943 nulos encontrados

 -- União das tabelas para verificar nulos:
SELECT
  CASE
    WHEN t2.default_flag = 1 THEN 'Mau pagador'
    WHEN t2.default_flag = 0 THEN 'Bom pagador'
    ELSE 'Sem informação'
END
  AS inadimplencia,
  COUNT(*) AS total_clientes
FROM
  `riscorelativo.user_info` AS t1
LEFT JOIN
  `riscorelativo.default` AS t2
ON
  t1.user_id = t2.user_id
GROUP BY
  CASE
    WHEN t2.default_flag = 1 THEN 'Mau pagador'
    WHEN t2.default_flag = 0 THEN 'Bom pagador'
    ELSE 'Sem informação'
END;
-- Bom pagador 35317
-- Mau pagador 683

-- Média de last_month_salary:
SELECT
AVG (last_month_salary)
FROM `riscorelativo.user_info`
-- 6675.05

--Substituir os nulos de "number_dependents" e "last_month_salary"
CREATE OR REPLACE TABLE `riscorelativo.user_info_limpa` AS
SELECT
user_id,
age,
sex,
IFNULL(last_month_salary, 0) AS number_dependents_corrigido,
IFNULL(number_dependents, 6675) AS last_month_salary_corrigido,
FROM `riscorelativo.user_info`

-- Identificar e tratar valores duplicados:
-- TABELA LOANS_OUTSTANDING
SELECT 
user_id,
loan_type,
COUNT(*) AS qtde_emprestimo
FROM `riscorelativo.loans_outstanding`
GROUP BY user_id, loan_type

--Identificar e gerenciar dados fora do escopo da análise
SELECT 
CORR(default_flag, more_90_days_overdue) AS corr_default_more_90_days_overdue,-- 0.3075
CORR(default_flag, number_times_delayed_payment_loan_30_59_days) AS corr_default_30_59_days, -- 0.2992
CORR(default_flag, number_times_delayed_payment_loan_60_89_days) AS corr_default_60_89_days,-- 0.2783
CORR(default_flag, using_lines_not_secured_corrigida) AS corr_default_using_lines_not_secured,-- 0.2385
CORR(default_flag, debt_ratio_corrigida) AS corr_default_debt_ratio,-- 0.0118
CORR(default_flag, last_month_salary_corrigido) AS corr_default_last_month_salary,-- -0.0197 
CORR(default_flag, number_dependents_corrigido) AS corr_default_number_dependents,-- 0.0326 
CORR(default_flag, age) AS corr_default_age,-- -0.0782
CORR(more_90_days_overdue, number_times_delayed_payment_loan_60_89_days) AS corr_more_90_days_overdue_60_89_days,-- 0.9922
CORR(debt_ratio_corrigida, using_lines_not_secured_corrigida) AS corr_debt_ratio_using_lines_not_secured,-- 0.0263
CORR(last_month_salary_corrigido, debt_ratio_corrigida) AS corr_last_month_salary_debt_ratio, -- -0.0647 
CORR(number_dependents_corrigido, last_month_salary_corrigido) AS corr_number_dependents_last_month_salary, -- 0.0724 
CORR(default_flag, qtde_real_estate) AS corr_default_real_estate, -- -0,0328
CORR(default_flag, qtde_loans) AS corr_default_qtde_loans,-- -0,0581
CORR(default_flag, qtde_other) AS corr_default_other,-- -0,0551
CORR (qtde_loans,debt_ratio_corrigida) AS corr_loans_debt_ratio,-- 0,1436
CORR (qtde_loans, using_lines_not_secured_corrigida) AS corr_loans_lines_not_secured,-- -0,1529
CORR (qtde_other, debt_ratio_corrigida) AS corr_other_debt_ratio,-- 0,0934
CORR (qtde_real_estate, debt_ratio_corrigida) AS corr_real_debt_ratio,-- 0,2647
CORR (age, qtde_loans) AS corr_age_loans,-- 0,1450
CORR (number_dependents_corrigido, qtde_loans) AS corr_dependents_loans,-- 0,0739
CORR (number_dependents_corrigido, debt_ratio_corrigida) AS corr_dependents_debt_ratio,-- -0,0958
FROM `riscorelativo.base_unificada`

--Identificar e tratar dados inconsistentes em variáveis ​​categóricas
--TABELA LOAN_OUTSTANDING
SELECT 
*,
INITCAP(REPLACE(REPLACE(loan_type, '_', ' '), 'others', 'Other')) AS loan_type_formatado
FROM `riscorelativo.loans_outstanding`

-- Identificar e tratar dados discrepantes em variáveis ​​numéricas
-- Consulta outliers 
WITH estatisticas AS (
  SELECT
    APPROX_QUANTILES(using_lines_not_secured_personal_assets, 4) AS quartis
  FROM `riscorelativo.loans_detail`
),
limites AS (
  SELECT
    quartis[OFFSET(1)] AS Q1,
    quartis[OFFSET(3)] AS Q3
  FROM estatisticas
),
outliers AS (
  SELECT
    *,
    Q1,
    Q3,
    (Q3 - Q1) AS IQR,
    (Q1 - 1.5 * (Q3 - Q1)) AS limite_inferior,
    (Q3 + 1.5 * (Q3 - Q1)) AS limite_superior
  FROM `riscorelativo.loans_detail`, limites
)
SELECT *
FROM outliers
WHERE using_lines_not_secured_personal_assets < limite_inferior
   OR using_lines_not_secured_personal_assets > limite_superior;


-- Using_lines_not_secured_personal_assets
WITH estatisticas AS (
  SELECT
    APPROX_QUANTILES(debt_ratio, 4) AS quartis
  FROM `riscorelativo.loans_detail`
),
limites AS (
  SELECT
    quartis[OFFSET(1)] AS Q1,
    quartis[OFFSET(3)] AS Q3
  FROM estatisticas
),
outliers AS (
  SELECT
    ld.*,
    l.Q1,
    l.Q3,
    (l.Q3 - l.Q1) AS IQR,
    (l.Q1 - 1.5 * (l.Q3 - l.Q1)) AS limite_inferior,
    (l.Q3 + 1.5 * (l.Q3 - l.Q1)) AS limite_superior
  FROM `riscorelativo.loans_detail` ld
  CROSS JOIN limites l
)
SELECT *
FROM outliers
WHERE debt_ratio < limite_inferior
   OR debt_ratio > limite_superior

-- Criar novas variáveis 
SELECT
  CASE
    WHEN t2.default_flag = 1 THEN 'Mau pagador'
    WHEN t2.default_flag = 0 THEN 'Bom pagador'
    ELSE 'Sem informação'
END
  AS inadimplencia,
  COUNT(*) AS total_clientes
FROM
  `riscorelativo.user_info` AS t1
LEFT JOIN
  `riscorelativo.default` AS t2
ON
  t1.user_id = t2.user_id
GROUP BY
  CASE
    WHEN t2.default_flag = 1 THEN 'Mau pagador'
    WHEN t2.default_flag = 0 THEN 'Bom pagador'
    ELSE 'Sem informação'
END;
-- Bom pagador 35317
-- Mau pagador 683

SELECT
  age,
  CASE 
    WHEN age BETWEEN 18 AND 29 THEN '18-29 anos'
    WHEN age BETWEEN 30 AND 45 THEN '30-45 anos'
    WHEN age BETWEEN 46 AND 64 THEN '46-64 anos'
    WHEN age BETWEEN 65 AND 79 THEN '65-79 anos'
    WHEN age >= 80 THEN '80+ anos'
    ELSE 'Fora da faixa'
  END AS faixa_etaria
FROM `riscorelativo.user_info``

--Tabela default nova
CREATE OR REPLACE TABLE riscorelativo.default_tratada AS (
SELECT
  user_id,
  default_flag,
  CASE 
    WHEN default_flag = 1 THEN 'Mau pagador'
    WHEN default_flag = 0 THEN 'Bom pagador'
    ELSE 'Sem informação'
  END AS classificacao_inadimplencia
FROM `riscorelativo.default`
)

--Tabela loans_detail nova
CREATE OR REPLACE TABLE riscorelativo.loans_detail_tratada AS
WITH loans_detail_corrigido AS (
  SELECT
    user_id,
    more_90_days_overdue,
    number_times_delayed_payment_loan_30_59_days,
    number_times_delayed_payment_loan_60_89_days,
    CASE 
      WHEN using_lines_not_secured_personal_assets > 1 THEN 1
      ELSE using_lines_not_secured_personal_assets
    END AS using_lines_not_secured_corrigida,
    CASE 
      WHEN debt_ratio > 1 THEN 1
      ELSE debt_ratio
    END AS debt_ratio_corrigida
  FROM riscorelativo.loans_detail
)
SELECT *
FROM loans_detail_corrigido

--Tabela loans_outstanding nova
CREATE OR REPLACE TABLE riscorelativo.loans_outstanding_tratada AS
WITH loan_formatado AS (
  SELECT
    user_id,
    loan_id,
    INITCAP(REPLACE(REPLACE(loan_type, '_', ' '), 'others', 'Other')) AS loan_type_formatado
  FROM `riscorelativo.loans_outstanding`
),
contagem_por_tipo AS (
  SELECT
    user_id,
    loan_type_formatado,
    COUNT(*) AS qtde
  FROM loan_formatado
  GROUP BY user_id, loan_type_formatado
),
unificado AS (
  SELECT
    user_id,
    SUM(CASE WHEN loan_type_formatado = 'Real Estate' THEN qtde ELSE 0 END) AS qtde_real_estate,
    SUM(CASE WHEN loan_type_formatado = 'Other' THEN qtde ELSE 0 END) AS qtde_other
  FROM contagem_por_tipo
  GROUP BY user_id
),
ids_concatenados AS (
  SELECT
    user_id,
    COUNT(*) AS qtde_loans
  FROM `riscorelativo.loans_outstanding`
  GROUP BY user_id
)

SELECT
  c.user_id,
  COALESCE(p.qtde_real_estate, 0) AS qtde_real_estate,
  COALESCE(p.qtde_other, 0) AS qtde_other,
  COALESCE(i.qtde_loans, 0) AS qtde_loans
FROM `riscorelativo.user_info` c
LEFT JOIN unificado p ON c.user_id = p.user_id
LEFT JOIN ids_concatenados i ON c.user_id = i.user_id
ORDER BY c.user_id;

--Tabela user_info nova
CREATE OR REPLACE TABLE `riscorelativo.user_info_tratada` AS
SELECT
user_id,
age,
  CASE 
    WHEN age BETWEEN 18 AND 29 THEN '18-29 anos'
    WHEN age BETWEEN 30 AND 45 THEN '30-45 anos'
    WHEN age BETWEEN 46 AND 64 THEN '46-64 anos'
    WHEN age BETWEEN 65 AND 79 THEN '65-79 anos'
    WHEN age >= 80 THEN '80+ anos'
    ELSE 'Fora da faixa'
  END AS faixa_etaria,
sex,
IFNULL(last_month_salary, 6675) AS last_month_salary_corrigido,
IFNULL(number_dependents, 0) AS number_dependents_corrigido,
FROM `riscorelativo.user_info`

--Calculo quartis
CREATE OR REPLACE TABLE riscorelativo.quartis AS (
  WITH base_quartis AS (
    SELECT 
      *,
      
      -- Quartis de faixa salarial
      NTILE(4) OVER (ORDER BY last_month_salary_corrigido) AS quartil_salario,
    
      -- Quartis de uso de crédito sem garantia
      NTILE(4) OVER (ORDER BY using_lines_not_secured_corrigida) AS quartil_credito_sem_garantia,

      -- Quartis de índice de endividamento
      NTILE(4) OVER (ORDER BY debt_ratio_corrigida) AS quartil_endividamento,

      -- Quartis de quantidade de empréstimos
      NTILE(4) OVER (ORDER BY qtde_loans) AS quartil_emprestimos,

      -- Quartis de idade
      NTILE(4) OVER (ORDER BY age) AS quartil_idade,

      -- Quartis de atrasos entre 30 e 59 dias
      NTILE(4) OVER (ORDER BY number_times_delayed_payment_loan_30_59_days) AS quartil_atraso_30_59,

      -- Quartis de atrasos entre 60 e 89 dias
      NTILE(4) OVER (ORDER BY number_times_delayed_payment_loan_60_89_days) AS quartil_atraso_60_89,

      -- Quartis de atrasos acima de 90 dias
      NTILE(4) OVER (ORDER BY more_90_days_overdue) AS quartil_atraso_90

    FROM `riscorelativo.base_unificada`
  )
  SELECT *
  FROM base_quartis
);

--Cálculo relativo
WITH
  inadimplencia AS (
  SELECT
    COUNTIF(default_flag = 1) AS default_1,
    COUNTIF(default_flag = 0) AS default_0
  FROM
    `riscorelativo.quartis` ),


  divisao_quartis AS (
  SELECT
    quartil_salario AS quartil,
    'last_month_salary_corrigido' AS variavel,
    MIN(last_month_salary_corrigido) AS min_valor,
    MAX(last_month_salary_corrigido) AS max_valor
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_salario

  UNION ALL

  SELECT
    quartil_idade,
    'age',
    MIN(age),
    MAX(age)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_idade

  UNION ALL

  SELECT
    quartil_atraso_90,
    'more_90_days_overdue',
    MIN(more_90_days_overdue),
    MAX(more_90_days_overdue)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_atraso_90

  UNION ALL

  SELECT
    quartil_atraso_30_59,
    'number_times_delayed_payment_loan_30_59_days',
    MIN(number_times_delayed_payment_loan_30_59_days),
    MAX(number_times_delayed_payment_loan_30_59_days)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_atraso_30_59

  UNION ALL

  SELECT
    quartil_atraso_60_89,
    'number_times_delayed_payment_loan_60_89_days',
    MIN(number_times_delayed_payment_loan_60_89_days),
    MAX(number_times_delayed_payment_loan_60_89_days)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_atraso_60_89

  UNION ALL

  SELECT
    quartil_endividamento,
    'debt_ratio_corrigida',
    MIN(debt_ratio_corrigida),
    MAX(debt_ratio_corrigida)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_endividamento

  UNION ALL

  SELECT
    quartil_credito_sem_garantia,
    'using_lines_not_secured_corrigida',
    MIN(using_lines_not_secured_corrigida),
    MAX(using_lines_not_secured_corrigida)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_credito_sem_garantia

  UNION ALL

  SELECT
    quartil_emprestimos,
    'qtde_loans',
    MIN(qtde_loans),
    MAX(qtde_loans)
  FROM
    `riscorelativo.quartis`
  GROUP BY
    quartil_emprestimos ),

    
  analise AS (
  SELECT
    CASE s.variavel
      WHEN 'last_month_salary_corrigido' THEN q.quartil_salario
      WHEN 'age' THEN q.quartil_idade
      WHEN 'more_90_days_overdue' THEN q.quartil_atraso_90
      WHEN 'number_times_delayed_payment_loan_30_59_days' THEN q.quartil_atraso_30_59
      WHEN 'number_times_delayed_payment_loan_60_89_days' THEN q.quartil_atraso_60_89
      WHEN 'debt_ratio_corrigida' THEN q.quartil_endividamento
      WHEN 'using_lines_not_secured_corrigida' THEN q.quartil_credito_sem_garantia
      WHEN 'qtde_loans' THEN q.quartil_emprestimos
  END
    AS quartil,
    s.variavel,
    COUNTIF(q.default_flag = 1) / t.default_1 AS mau_pagador,
    COUNTIF(q.default_flag = 0) / t.default_0 AS bom_pagador,
    SAFE_DIVIDE(COUNTIF(q.default_flag = 1) / t.default_1, COUNTIF(q.default_flag = 0) / t.default_0) AS risco,
    CASE
      WHEN SAFE_DIVIDE(COUNTIF(q.default_flag = 1) / t.default_1, COUNTIF(q.default_flag = 0) / t.default_0) > 1 THEN 'Mau pagador'
      WHEN SAFE_DIVIDE(COUNTIF(q.default_flag = 1) / t.default_1, COUNTIF(q.default_flag = 0) / t.default_0) < 1 THEN 'Bom pagador'
      ELSE 'Risco indefinido'
  END
    AS categoria,
    s.min_valor,
    s.max_valor
  FROM
    `riscorelativo.quartis` q
  CROSS JOIN
    inadimplencia t
  JOIN
    divisao_quartis s
  ON
    ( (s.variavel = 'last_month_salary_corrigido'
        AND q.quartil_salario = s.quartil)
      OR (s.variavel = 'age'
        AND q.quartil_idade = s.quartil)
      OR (s.variavel = 'more_90_days_overdue'
        AND q.quartil_atraso_90 = s.quartil)
      OR (s.variavel = 'number_times_delayed_payment_loan_30_59_days'
        AND q.quartil_atraso_30_59 = s.quartil)
      OR (s.variavel = 'number_times_delayed_payment_loan_60_89_days'
        AND q.quartil_atraso_60_89 = s.quartil)
      OR (s.variavel = 'debt_ratio_corrigida'
        AND q.quartil_endividamento = s.quartil)
      OR (s.variavel = 'using_lines_not_secured_corrigida'
        AND q.quartil_credito_sem_garantia = s.quartil)
      OR (s.variavel = 'qtde_loans'
        AND q.quartil_emprestimos = s.quartil) )
  GROUP BY
    quartil,
    s.variavel,
    t.default_1,
    t.default_0,
    s.min_valor,
    s.max_valor )
SELECT
  *
FROM
  analise
ORDER BY
  variavel,
  quartil;

-- Segmentação score (dummies)
CREATE OR REPLACE TABLE `riscorelativo.score_cortes` AS
WITH dummy AS (
  SELECT
    user_id,
    default_flag,
    CASE WHEN quartil_idade              IN (1, 2) THEN 1 ELSE 0 END AS age_dummy,
    CASE WHEN quartil_salario            IN (1, 2) THEN 1 ELSE 0 END AS salary_dummy,
    CASE WHEN quartil_emprestimos        IN (1, 2) THEN 1 ELSE 0 END AS total_loans_dummy,
    CASE WHEN quartil_atraso_90               = 4  THEN 1 ELSE 0 END AS more_90_days_dummy,
    CASE WHEN quartil_credito_sem_garantia    = 4  THEN 1 ELSE 0 END AS using_lines_dummy,
    CASE WHEN quartil_endividamento      IN (3, 4) THEN 1 ELSE 0 END AS debt_ratio_dummy
  FROM `riscorelativo.quartis`
),

score_calculo AS (
  SELECT
    *,
    age_dummy + salary_dummy + total_loans_dummy + more_90_days_dummy + using_lines_dummy + debt_ratio_dummy AS score
  FROM dummy
),

resultado AS (
  SELECT
    *,
    CASE WHEN score >= 1 THEN 1 ELSE 0 END AS risco_cut_1,
    CASE WHEN score >= 2 THEN 1 ELSE 0 END AS risco_cut_2,
    CASE WHEN score >= 3 THEN 1 ELSE 0 END AS risco_cut_3,
    CASE WHEN score >= 4 THEN 1 ELSE 0 END AS risco_cut_4,
    CASE WHEN score >= 5 THEN 1 ELSE 0 END AS risco_cut_5,
    CASE WHEN score >= 6 THEN 1 ELSE 0 END AS risco_cut_6
  FROM score_calculo
)

SELECT * FROM resultado;

-- Matriz de confusão
WITH metricas AS (
  SELECT
    'cut_1' AS corte,
    SUM(CASE WHEN risco_cut_1 = 1 AND default_flag = 1 THEN 1 ELSE 0 END) AS VP,
    SUM(CASE WHEN risco_cut_1 = 0 AND default_flag = 0 THEN 1 ELSE 0 END) AS VN,
    SUM(CASE WHEN risco_cut_1 = 1 AND default_flag = 0 THEN 1 ELSE 0 END) AS FP,
    SUM(CASE WHEN risco_cut_1 = 0 AND default_flag = 1 THEN 1 ELSE 0 END) AS FN
  FROM `riscorelativo.score_cortes`

  UNION ALL

  SELECT
    'cut_2',
    SUM(CASE WHEN risco_cut_2 = 1 AND default_flag = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_2 = 0 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_2 = 1 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_2 = 0 AND default_flag = 1 THEN 1 ELSE 0 END)
  FROM `riscorelativo.score_cortes`

  UNION ALL

  SELECT
    'cut_3',
    SUM(CASE WHEN risco_cut_3 = 1 AND default_flag = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_3 = 0 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_3 = 1 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_3 = 0 AND default_flag = 1 THEN 1 ELSE 0 END)
  FROM `riscorelativo.score_cortes`

  UNION ALL

  SELECT
    'cut_4',
    SUM(CASE WHEN risco_cut_4 = 1 AND default_flag = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_4 = 0 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_4 = 1 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_4 = 0 AND default_flag = 1 THEN 1 ELSE 0 END)
   FROM `riscorelativo.score_cortes`

  UNION ALL

  SELECT
    'cut_5',
    SUM(CASE WHEN risco_cut_5 = 1 AND default_flag = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_5 = 0 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_5 = 1 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_5 = 0 AND default_flag = 1 THEN 1 ELSE 0 END)
 FROM `riscorelativo.score_cortes`

  UNION ALL

  SELECT
    'cut_6',
    SUM(CASE WHEN risco_cut_6 = 1 AND default_flag = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_6 = 0 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_6 = 1 AND default_flag = 0 THEN 1 ELSE 0 END),
    SUM(CASE WHEN risco_cut_6 = 0 AND default_flag = 1 THEN 1 ELSE 0 END)
 FROM `riscorelativo.score_cortes`
)

SELECT
  corte,
  VP,
  VN,
  FP,
  FN,
  ROUND((VP + VN) / (VP + VN + FP + FN), 4) AS acuracia,
  ROUND(VP / NULLIF(VP + FP, 0), 4) AS precisao,
  ROUND(VP / NULLIF(VP + FN, 0), 4) AS recall
FROM metricas
ORDER BY corte;


-- Tabela score
CREATE OR REPLACE TABLE `riscorelativo.score_final02` AS
WITH dummy AS (
  SELECT
    user_id,
    default_flag,
    CASE WHEN quartil_idade            IN (1, 2) THEN 1 ELSE 0 END AS age_dummy,
    CASE WHEN quartil_salario          IN (1, 2) THEN 1 ELSE 0 END AS salary_dummy,
    CASE WHEN quartil_emprestimos      IN (1, 2) THEN 1 ELSE 0 END AS total_loans_dummy,
    CASE WHEN quartil_atraso_90        = 4       THEN 1 ELSE 0 END AS more_90_days_dummy,
    CASE WHEN quartil_credito_sem_garantia = 4   THEN 1 ELSE 0 END AS using_lines_dummy,
    CASE WHEN quartil_endividamento    IN (3, 4) THEN 1 ELSE 0 END AS debt_ratio_dummy
  FROM `riscorelativo.quartis`
),

score_calculo AS (
  SELECT
    *,
    age_dummy + salary_dummy + total_loans_dummy + more_90_days_dummy + using_lines_dummy + debt_ratio_dummy AS score
  FROM dummy
),

resultado AS (
  SELECT
    *,
    CASE WHEN score >= 5 THEN 1 ELSE 0 END AS tipo_score,
    CASE 
      WHEN score >= 5 THEN 'Risco de ser mau pagador'
      ELSE 'Possível bom pagador'
    END AS descricao_risco,
    CASE 
      WHEN score = 0 THEN 1000
      WHEN score = 1 THEN 900
      WHEN score = 2 THEN 800
      WHEN score = 3 THEN 700
      WHEN score = 4 THEN 600
      WHEN score = 5 THEN 400
      WHEN score = 6 THEN 200
      ELSE 0
    END AS pontuacao
  FROM score_calculo
)

SELECT * FROM resultado;

-- União tabelas
CREATE OR REPLACE TABLE `riscorelativo.base_final` AS
SELECT
  t1.user_id,
  t1.default_flag,
  t1.classificacao_inadimplencia,
  t2.more_90_days_overdue,
  t2.number_times_delayed_payment_loan_30_59_days,
  t2.number_times_delayed_payment_loan_60_89_days,
  t2.using_lines_not_secured_corrigida,
  t2.debt_ratio_corrigida,
  t3.qtde_real_estate,
  t3.qtde_other,
  t3.qtde_loans,
  t4.age,
  CASE 
    WHEN t4.age BETWEEN 18 AND 29 THEN '18-29 anos'
    WHEN t4.age BETWEEN 30 AND 45 THEN '30-45 anos'
    WHEN t4.age BETWEEN 46 AND 64 THEN '46-64 anos'
    WHEN t4.age BETWEEN 65 AND 79 THEN '65-79 anos'
    WHEN t4.age >= 80 THEN '+80 anos'
    ELSE 'Fora da faixa'
  END AS faixa_etaria,
  t4.sex,
  t4.last_month_salary_corrigido,
  t4.number_dependents_corrigido,
  t5.quartil_salario,
  t5.quartil_credito_sem_garantia,
  t5.quartil_endividamento,
  t5.quartil_emprestimos,
  t5.quartil_idade,
  t5.quartil_atraso_30_59,
  t5.quartil_atraso_60_89,
  t5.quartil_atraso_90,
  t6.age_dummy,
  t6.salary_dummy,
  t6.total_loans_dummy,
  t6.more_90_days_dummy,
  t6.using_lines_dummy,
  t6.debt_ratio_dummy,
  t6.score,
  t6.descricao_risco,
  t6.pontuacao
FROM `riscorelativo.default_tratada` AS t1
LEFT JOIN `riscorelativo.loans_detail_tratada` AS t2 ON t1.user_id = t2.user_id
LEFT JOIN `riscorelativo.loans_outstanding_tratada` AS t3 ON t2.user_id = t3.user_id
LEFT JOIN `riscorelativo.user_info_tratada` AS t4 ON t3.user_id = t4.user_id
LEFT JOIN `riscorelativo.quartis` AS t5 ON t4.user_id = t5.user_id
LEFT JOIN `riscorelativo.score_final02` AS t6 ON t5.user_id = t6.user_id;
