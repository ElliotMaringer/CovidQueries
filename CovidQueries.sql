/*
--------------------------------------------------------------------------------
Project: COVID-19 Exploration — SQL Queries for Tableau Dashboard
Author: Elliot Maringer
Notes:
- This file contains all exploratory queries I wrote while building my Tableau
  dashboard. Only the FIRST FOUR queries were ultimately used to create visuals
  in Tableau; the rest are kept here for reference and future exploration.
- Data sources are the tables:
    PortfolioProject..CovidDeaths
    PortfolioProject..CovidVaccinations
- General conventions:
    • I exclude aggregate “roll-up” rows (e.g., World, EU, income groups) when
      I want true country/continent comparisons.
    • I sometimes leave alternative versions commented out for quick checks.
    • Be mindful of INT overflow when summing large columns (see tips below).
*/


/* 
   1) Global totals and death percentage (used in Tableau)
   Purpose:
   - Get overall new cases and new deaths across all reporting entities
     excluding non-country aggregates (continent IS NOT NULL approximates this).
   - Compute crude death percentage = total_deaths / total_cases.
   Notes:
   - Order by 1,2 is harmless here; no GROUP BY means a single row result.
   - Consider BIGINT/TRY_CONVERT if you hit overflow on very large sums.
 */
SELECT
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'            -- quick filter example I used
WHERE continent IS NOT NULL                 -- exclude aggregate rows
--GROUP BY date                             -- not needed for grand totals
ORDER BY 1, 2;


/*
Quick reasonableness check (left here for reference):
- The variant below includes "International" and other roll-ups via location='World'.
- I verified values were very close; I kept the first approach for consistency.

--SELECT
--    SUM(new_cases) AS total_cases,
--    SUM(CAST(new_deaths AS INT)) AS total_deaths,
--    SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage
--FROM PortfolioProject..CovidDeaths
--WHERE location = 'World'
--ORDER BY 1, 2;
*/


/* 
   2) Death counts by non-continent aggregates (reference)
   Purpose:
   - Surface death counts for locations where continent IS NULL, excluding
     'World', 'European Union', 'International', and income groupings.
   Why:
   - Helpful diagnostic to see what non-country/aggregate rows contribute.
   - Not used in Tableau visuals; kept for data understanding.
 */
SELECT
    location,
    SUM(CAST(new_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'             -- quick filter during testing
WHERE continent IS NULL
  AND location NOT IN ('World', 'European Union', 'International')
  AND location NOT LIKE ('%income%')        -- exclude income buckets
GROUP BY location
ORDER BY TotalDeathCount DESC;


/* 
   3) Highest infection count and % infected by location (used in Tableau)
   Purpose:
   - For each location, find the peak total_cases and compute
     (max total_cases / population) * 100 to estimate % of population infected.
   Notes:
   - Using MAX(total_cases) assumes cumulative total_cases increases over time.
 */
SELECT
    Location,
    Population,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC;


/* 
   4) Date-level view of highest infection % (used in Tableau)
   Purpose:
   - Same idea as #3 but keep date in the grouping for a more granular, time-
     aware perspective. Useful when building time-series visuals.
 */
SELECT
    Location,
    Population,
    date,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
GROUP BY Location, Population, date
ORDER BY PercentPopulationInfected DESC;


/* 
   The following queries were part of my initial exploration but excluded
   from the final video to keep it tighter. I’m keeping them here for future
   iterations and sanity checks.
*/


/*
   (Extra) Vaccination progress joined to deaths table
   Purpose:
   - Join deaths and vaccinations on (location, date) and track rolling totals
     of total_vaccinations per location.
   Notes:
   - Depending on the data version, total_vaccinations can be NULL on some days.
   - RollingPeopleVaccinated shown via MAX(total_vaccinations) by date here.
 */
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    MAX(vac.total_vaccinations) AS RollingPeopleVaccinated
    --,(RollingPeopleVaccinated / population) * 100  -- optional share metric
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
    ON dea.location = vac.location
   AND dea.date     = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.continent, dea.location, dea.date, dea.population
ORDER BY 1, 2, 3;


/* 
   (Extra) Global totals (same as #1, kept near the extras for quick reuse)
*/
SELECT
    SUM(new_cases) AS total_cases,
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
WHERE continent IS NOT NULL
--GROUP BY date
ORDER BY 1, 2;

/*
Reasonableness check variant (includes aggregates via 'World'):

--SELECT
--    SUM(new_cases) AS total_cases,
--    SUM(CAST(new_deaths AS INT)) AS total_deaths,
--    SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100 AS DeathPercentage
--FROM PortfolioProject..CovidDeaths
--WHERE location = 'World'
--ORDER BY 1, 2;
*/


/* 
   (Extra) Death counts for non-continent aggregates (like #2, without incomes)
 */
SELECT
    location,
    SUM(CAST(new_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
WHERE continent IS NULL
  AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
ORDER BY TotalDeathCount DESC;


/* ============================================================================
   (Extra) Highest infection % by location (same as #3)
============================================================================ */
SELECT
    Location,
    Population,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC;


/* ============================================================================
   (Extra) Daily cases/deaths with population (detail table)
   Purpose:
   - A wide table useful for ad-hoc checks and basic line charts.
   - I added population so per-capita views are easy to compute downstream.
============================================================================ */
--SELECT
--    Location,
--    date,
--    total_cases,
--    total_deaths,
--    (total_deaths / NULLIF(total_cases, 0)) * 100 AS DeathPercentage
--FROM PortfolioProject..CovidDeaths
--WHERE continent IS NOT NULL
--ORDER BY 1, 2;

-- Final kept version with population included (no derived % to keep it simple):
SELECT
    Location,
    date,
    population,
    total_cases,
    total_deaths
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
WHERE continent IS NOT NULL
ORDER BY 1, 2;


/* ============================================================================
   (Extra) Rolling sum of new vaccinations via window function (CTE)
   Purpose:
   - Compute a running total of new_vaccinations per location over time.
   - Useful for % of population vaccinated calculations.
   Tips:
   - Use BIGINT/TRY_CONVERT below if INT overflow occurs.
============================================================================ */
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated) AS
(
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(CONVERT(INT, vac.new_vaccinations))
            OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date)
            AS RollingPeopleVaccinated
        -- If overflow: SUM(TRY_CONVERT(BIGINT, vac.new_vaccinations)) OVER (...)
    FROM PortfolioProject..CovidDeaths AS dea
    JOIN PortfolioProject..CovidVaccinations AS vac
        ON dea.location = vac.location
       AND dea.date     = vac.date
    WHERE dea.continent IS NOT NULL
    --ORDER BY 2, 3   -- avoid ORDER BY in CTE body for portability
)
SELECT
    *,
    (RollingPeopleVaccinated / NULLIF(Population, 0)) * 100 AS PercentPeopleVaccinated
FROM PopvsVac;


/* ============================================================================
   (Extra) Date-level infection % (same as #4)
============================================================================ */
SELECT
    Location,
    Population,
    date,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / population)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
GROUP BY Location, Population, date
ORDER BY PercentPopulationInfected DESC;
