-- Backfill salary_min / salary_max from the legacy `salary` text and add a
-- range sanity check. salary_amount and the salary text are not modified.

-- Range text: "600-900", "600 - 900 AZN" (min/max swapped if reversed).
UPDATE public.jobs
SET salary_min = LEAST(
      (regexp_match(salary, '^\s*(\d{1,7})\s*[-–—]\s*(\d{1,7})'))[1]::int,
      (regexp_match(salary, '^\s*(\d{1,7})\s*[-–—]\s*(\d{1,7})'))[2]::int),
    salary_max = GREATEST(
      (regexp_match(salary, '^\s*(\d{1,7})\s*[-–—]\s*(\d{1,7})'))[1]::int,
      (regexp_match(salary, '^\s*(\d{1,7})\s*[-–—]\s*(\d{1,7})'))[2]::int)
WHERE salary_min IS NULL
  AND salary_max IS NULL
  AND salary ~ '^\s*\d{1,7}\s*[-–—]\s*\d{1,7}';

-- Single number: "600", "600 AZN". Only salary_min is filled; "0" stays empty.
UPDATE public.jobs
SET salary_min = (regexp_match(salary, '^\s*(\d{1,7})\s*(?:AZN|₼|manat)?\s*$', 'i'))[1]::int
WHERE salary_min IS NULL
  AND salary_max IS NULL
  AND salary ~* '^\s*\d{1,7}\s*(AZN|₼|manat)?\s*$'
  AND (regexp_match(salary, '^\s*(\d{1,7})', ''))[1]::int > 0;

DO $$
DECLARE
  unparsed integer;
  violations integer;
BEGIN
  SELECT count(*) INTO unparsed
  FROM public.jobs
  WHERE salary_min IS NULL AND salary_max IS NULL
    AND salary IS NOT NULL AND btrim(salary) <> ''
    AND salary !~ '^\s*0+\s*(AZN|₼|manat)?\s*$';
  RAISE NOTICE 'salary rows left unparsed: %', unparsed;

  SELECT count(*) INTO violations
  FROM public.jobs
  WHERE salary_min IS NOT NULL AND salary_max IS NOT NULL AND salary_min > salary_max;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'jobs_salary_range_check' AND conrelid = 'public.jobs'::regclass
  ) THEN
    IF violations = 0 THEN
      ALTER TABLE public.jobs
        ADD CONSTRAINT jobs_salary_range_check
        CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max);
    ELSE
      ALTER TABLE public.jobs
        ADD CONSTRAINT jobs_salary_range_check
        CHECK (salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max)
        NOT VALID;
      RAISE NOTICE 'jobs_salary_range_check added NOT VALID, % violating rows', violations;
    END IF;
  END IF;
END $$;
