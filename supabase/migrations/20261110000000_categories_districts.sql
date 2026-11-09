-- Reference tables for job categories and districts, plus nullable id columns on
-- jobs. The legacy text columns (category, district, district_name) are kept as is:
-- 1.0.0 / 1.0.1 clients keep reading and writing them. A trigger keeps text and ids
-- in sync in both directions.

-- Text normalisation used for alias / district lookups (handles Turkic dotted I).
CREATE OR REPLACE FUNCTION public.norm_text(t text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
  SELECT lower(btrim(regexp_replace(replace(replace(t, 'İ', 'I'), 'ı', 'i'), '\s+', ' ', 'g')));
$$;

CREATE TABLE public.job_categories (
  id       smallint PRIMARY KEY,
  slug     text NOT NULL UNIQUE,
  name_az  text NOT NULL,
  name_ru  text NOT NULL,
  name_en  text NOT NULL,
  icon     text,
  sort     integer
);

CREATE TABLE public.districts (
  id       smallint PRIMARY KEY,
  slug     text NOT NULL UNIQUE,
  name_az  text NOT NULL,
  name_ru  text NOT NULL,
  name_en  text NOT NULL,
  city     text NOT NULL,
  kind     text NOT NULL CHECK (kind IN ('rayon', 'area', 'city')),
  sort     integer
);

CREATE TABLE public.category_aliases (
  old_value   text PRIMARY KEY,
  category_id smallint NOT NULL REFERENCES public.job_categories (id)
);

-- Default privileges give anon/authenticated full table rights on new tables; keep
-- only SELECT. Writes are possible for service_role / postgres only.
REVOKE ALL ON public.job_categories, public.districts, public.category_aliases FROM anon, authenticated;
GRANT SELECT ON public.job_categories, public.districts, public.category_aliases TO anon, authenticated;

ALTER TABLE public.job_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.category_aliases ENABLE ROW LEVEL SECURITY;

CREATE POLICY job_categories_select_all ON public.job_categories
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY districts_select_all ON public.districts
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY category_aliases_select_all ON public.category_aliases
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.jobs
  ADD COLUMN category_id smallint REFERENCES public.job_categories (id),
  ADD COLUMN district_id smallint REFERENCES public.districts (id);

CREATE INDEX idx_jobs_category_id ON public.jobs (category_id);
CREATE INDEX idx_jobs_district_id ON public.jobs (district_id);

INSERT INTO public.job_categories (id, slug, name_az, name_ru, name_en, icon, sort) VALUES
  (1,  'restoran-kafe',      'Restoran & Kafe (ofisiant, servis)', 'Ресторан и кафе (официант, сервис)', 'Restaurant & Cafe (waiter, service)', 'restaurant', 1),
  (2,  'ashpaz-metbex',      'Aşpaz / Mətbəx', 'Повар / Кухня', 'Cook / Kitchen', 'soup_kitchen', 2),
  (3,  'barista-bar',        'Barista / Bar', 'Бариста / Бар', 'Barista / Bar', 'local_cafe', 3),
  (4,  'satis',              'Satış məsləhətçisi / Satış', 'Продавец / Продажи', 'Sales / Sales Assistant', 'storefront', 4),
  (5,  'kassir',             'Kassir', 'Кассир', 'Cashier', 'point_of_sale', 5),
  (6,  'anbar',              'Anbar işçisi', 'Складской работник', 'Warehouse Worker', 'warehouse', 6),
  (7,  'kuryer',             'Kuryer / Çatdırılma', 'Курьер / Доставка', 'Courier / Delivery', 'delivery_dining', 7),
  (8,  'surucu',             'Sürücü', 'Водитель', 'Driver', 'directions_car', 8),
  (9,  'temizlik',           'Təmizlik / Xadimə', 'Уборка / Уборщица', 'Cleaning', 'cleaning_services', 9),
  (10, 'muhafize',           'Mühafizə', 'Охрана', 'Security', 'security', 10),
  (11, 'musteri-xidmetleri', 'Müştəri xidmətləri / Call center', 'Обслуживание клиентов / Колл-центр', 'Customer Service / Call Center', 'support_agent', 11),
  (12, 'resepsn',            'Resepşn / Qəbul', 'Ресепшн / Администратор', 'Reception', 'badge', 12),
  (13, 'muhasib',            'Mühasib / Maliyyə', 'Бухгалтер / Финансы', 'Accounting / Finance', 'account_balance', 13),
  (14, 'inzibati',           'İnzibati / Ofis meneceri', 'Административный / Офис-менеджер', 'Administrative / Office Manager', 'business_center', 14),
  (15, 'hr',                 'HR / İşə qəbul', 'HR / Подбор персонала', 'HR / Recruiting', 'groups', 15),
  (16, 'marketinq',          'Marketinq / SMM', 'Маркетинг / SMM', 'Marketing / SMM', 'campaign', 16),
  (17, 'dizayn',             'Dizayn', 'Дизайн', 'Design', 'brush', 17),
  (18, 'it',                 'İT / Proqramlaşdırma', 'IT / Программирование', 'IT / Software', 'code', 18),
  (19, 'muhendis',           'Mühəndis / Texniki', 'Инженер / Технический', 'Engineering / Technical', 'engineering', 19),
  (20, 'tikinti',            'Tikinti / Təmir', 'Строительство / Ремонт', 'Construction / Repair', 'construction', 20),
  (21, 'usta',               'Usta (elektrik, santexnik və s.)', 'Мастер (электрик, сантехник и др.)', 'Handyman (electrician, plumber, etc.)', 'handyman', 21),
  (22, 'avtoservis',         'Avtoservis / Mexanik', 'Автосервис / Механик', 'Auto Service / Mechanic', 'car_repair', 22),
  (23, 'istehsalat',         'İstehsalat / Zavod', 'Производство / Завод', 'Manufacturing / Factory', 'factory', 23),
  (24, 'otel-turizm',        'Otel / Turizm', 'Отель / Туризм', 'Hotel / Tourism', 'hotel', 24),
  (25, 'gozellik',           'Gözəllik (bərbər, manikür və s.)', 'Красота (парикмахер, маникюр и др.)', 'Beauty (barber, nails, etc.)', 'content_cut', 25),
  (26, 'tehsil',             'Təhsil / Müəllim', 'Образование / Преподаватель', 'Education / Teacher', 'school', 26),
  (27, 'sehiyye',            'Səhiyyə və Tibb', 'Здравоохранение и медицина', 'Healthcare / Medical', 'medical_services', 27),
  (28, 'huquq',              'Hüquq', 'Юриспруденция', 'Legal', 'gavel', 28),
  (29, 'kend-teserrufati',   'Kənd təsərrüfatı', 'Сельское хозяйство', 'Agriculture', 'agriculture', 29),
  (30, 'logistika',          'Logistika / Ekspedisiya', 'Логистика / Экспедиция', 'Logistics / Freight', 'local_shipping', 30),
  (31, 'idman',              'İdman & Sağlamlıq', 'Спорт и здоровье', 'Sports & Wellness', 'fitness_center', 31),
  (32, 'foto-video',         'Foto / Video / Kontent', 'Фото / Видео / Контент', 'Photo / Video / Content', 'videocam', 32),
  (33, 'tercume',            'Tərcümə', 'Перевод', 'Translation', 'translate', 33),
  (34, 'baxici',             'Baxıcı / Dayə', 'Няня / Сиделка', 'Caregiver / Nanny', 'child_care', 34),
  (35, 'diger',              'Digər', 'Другое', 'Other', 'more_horiz', 35);

INSERT INTO public.districts (id, slug, name_az, name_ru, name_en, city, kind, sort) VALUES
  (1,  'binaqadi',      'Binəqədi',   'Бинагадинский', 'Binagadi',    'Bakı', 'rayon', 1),
  (2,  'qaradag',       'Qaradağ',    'Гарадагский',   'Garadagh',    'Bakı', 'rayon', 2),
  (3,  'narimanov',     'Nərimanov',  'Наримановский', 'Narimanov',   'Bakı', 'rayon', 3),
  (4,  'nesimi',        'Nəsimi',     'Насиминский',   'Nasimi',      'Bakı', 'rayon', 4),
  (5,  'nizami',        'Nizami',     'Низаминский',   'Nizami',      'Bakı', 'rayon', 5),
  (6,  'pirallahi',     'Pirallahı',  'Пираллахинский', 'Pirallahi',  'Bakı', 'rayon', 6),
  (7,  'sabunchu',      'Sabunçu',    'Сабунчинский',  'Sabunchu',    'Bakı', 'rayon', 7),
  (8,  'sebail',        'Səbail',     'Сабаильский',   'Sabail',      'Bakı', 'rayon', 8),
  (9,  'suraxani',      'Suraxanı',   'Сураханский',   'Surakhani',   'Bakı', 'rayon', 9),
  (10, 'xetai',         'Xətai',      'Хатаинский',    'Khatai',      'Bakı', 'rayon', 10),
  (11, 'xezer',         'Xəzər',      'Хазарский',     'Khazar',      'Bakı', 'rayon', 11),
  (12, 'yasamal',       'Yasamal',    'Ясамальский',   'Yasamal',     'Bakı', 'rayon', 12),
  (13, '28-may',        '28 May',     '28 Мая',        '28 May',      'Bakı', 'area', 13),
  (14, 'genclik',       'Gənclik',    'Гянджлик',      'Genclik',     'Bakı', 'area', 14),
  (15, 'koroglu',       'Koroğlu',    'Кероглу',       'Koroglu',     'Bakı', 'area', 15),
  (16, 'icherisheher',  'İçərişəhər', 'Ичеришехер',    'Icherisheher', 'Bakı', 'area', 16),
  (17, 'elmler',        'Elmlər',     'Элмляр',        'Elmler',      'Bakı', 'area', 17),
  (18, 'sumqayit',      'Sumqayıt',   'Сумгайыт',      'Sumgait',     'Sumqayıt', 'city', 18),
  (19, 'xirdalan',      'Xırdalan',   'Хырдалан',      'Khirdalan',   'Abşeron', 'city', 19),
  (20, 'abseron',       'Abşeron',    'Апшерон',       'Absheron',    'Abşeron', 'city', 20);

-- Aliases: every distinct value currently in jobs.category, the labels the apps
-- write (add_job_screen, admin screens) and the az filter labels from app_language.
INSERT INTO public.category_aliases (old_value, category_id)
SELECT public.norm_text(a.old_value), c.id
FROM (VALUES
  ('Restoran & Kafe', 'restoran-kafe'),
  ('Kafe & Restoran', 'restoran-kafe'),
  ('Restoran & Kafeler', 'restoran-kafe'),
  ('İaşə', 'restoran-kafe'),
  ('Satış', 'satis'),
  ('Satış & Retail', 'satis'),
  ('Satış & Marketinq', 'satis'),
  ('Anbar', 'anbar'),
  ('Anbar & Logistika', 'anbar'),
  ('Logistika', 'logistika'),
  ('Logistika & Çatdırılma', 'logistika'),
  ('Dizayn', 'dizayn'),
  ('Müştəri Xidmətləri', 'musteri-xidmetleri'),
  ('Xidmət & Zəng Mərkəzi', 'musteri-xidmetleri'),
  ('Marketinq, Reklam və PR', 'marketinq'),
  ('Marketing / Media', 'marketinq'),
  ('İT', 'it'),
  ('İT & Proqramlaşdırma', 'it'),
  ('Tikinti', 'tikinti'),
  ('Tikinti & Təmir', 'tikinti'),
  ('Təhsil', 'tehsil'),
  ('Təhsil & Tədris', 'tehsil'),
  ('Çatdırılma', 'kuryer'),
  ('Səhiyyə & Tibb', 'sehiyye'),
  ('Səhiyyə və Tibb', 'sehiyye'),
  ('Ofis & İnzibati', 'inzibati'),
  ('İdman & Sağlamlıq', 'idman'),
  ('Avto & Xidmət', 'avtoservis'),
  ('Gözəllik', 'gozellik'),
  ('Gözəllik & Salonda İş', 'gozellik'),
  ('Xidmət', 'diger'),
  ('Xidmət & Dizayn', 'diger')
) AS a(old_value, slug)
JOIN public.job_categories c ON c.slug = a.slug
ON CONFLICT (old_value) DO NOTHING;

-- Keeps legacy text columns and the new ids in sync. Unknown text never raises:
-- the id stays NULL and the text is left untouched.
CREATE OR REPLACE FUNCTION public.jobs_sync_category_district()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  cat_id smallint;
  dist_id smallint;
  orig public.jobs;
BEGIN
  orig := new;
  BEGIN
  -- category
  IF new.category_id IS NOT NULL
     AND (tg_op = 'INSERT' OR new.category_id IS DISTINCT FROM old.category_id
          OR new.category IS NOT DISTINCT FROM old.category) THEN
    NULL; -- id is authoritative, text is synced below
  ELSIF new.category IS NOT NULL AND btrim(new.category) <> '' THEN
    -- legacy client wrote text (or changed it without touching the id)
    SELECT a.category_id INTO cat_id
    FROM public.category_aliases a
    WHERE a.old_value = public.norm_text(new.category);
    IF cat_id IS NULL THEN
      SELECT c.id INTO cat_id
      FROM public.job_categories c
      WHERE public.norm_text(c.name_az) = public.norm_text(new.category);
    END IF;
    new.category_id := cat_id;
  ELSE
    new.category_id := NULL;
  END IF;

  IF new.category_id IS NOT NULL THEN
    SELECT c.name_az INTO new.category
    FROM public.job_categories c
    WHERE c.id = new.category_id;
  END IF;

  -- district
  IF new.district_id IS NOT NULL
     AND (tg_op = 'INSERT' OR new.district_id IS DISTINCT FROM old.district_id
          OR new.district IS NOT DISTINCT FROM old.district) THEN
    NULL;
  ELSIF new.district IS NOT NULL AND btrim(new.district) <> '' THEN
    SELECT d.id INTO dist_id
    FROM public.districts d
    WHERE public.norm_text(d.name_az) = public.norm_text(new.district);
    new.district_id := dist_id;
  ELSE
    new.district_id := NULL;
  END IF;

  IF new.district_id IS NOT NULL THEN
    SELECT d.name_az INTO new.district
    FROM public.districts d
    WHERE d.id = new.district_id;
  END IF;

  RETURN new;
  EXCEPTION WHEN OTHERS THEN
    -- never block a write because of category/district sync
    RETURN orig;
  END;
END;
$$;

-- Runs after jobs_guard_privileged_columns (alphabetical order); it touches
-- different columns, so there is no interaction.
CREATE TRIGGER jobs_sync_category_district
  BEFORE INSERT OR UPDATE OF category, category_id, district, district_id ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.jobs_sync_category_district();

-- Backfill. 'Elml?r' contains a literal 0x3f byte (an already corrupted "Elmlər").
UPDATE public.jobs SET district = 'Elmlər' WHERE district = 'Elml?r';

-- Fill ids only; legacy text is left as written until the row is next edited.
ALTER TABLE public.jobs DISABLE TRIGGER jobs_sync_category_district;

UPDATE public.jobs j
SET category_id = a.category_id
FROM public.category_aliases a
WHERE j.category_id IS NULL
  AND a.old_value = public.norm_text(j.category);

UPDATE public.jobs j
SET district_id = d.id
FROM public.districts d
WHERE j.district_id IS NULL
  AND public.norm_text(d.name_az) = public.norm_text(j.district);

ALTER TABLE public.jobs ENABLE TRIGGER jobs_sync_category_district;
