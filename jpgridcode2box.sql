CREATE OR REPLACE FUNCTION jpgridcode2box(code TEXT) RETURNS NUMERIC[] AS $$
DECLARE
    reg_code1 CONSTANT TEXT := '^\s*([0-9]{2})([0-9]{2})\s*$';
    reg_code2 CONSTANT TEXT := '^\s*([0-9]{2})([0-9]{2})\s*-?\s*([0-9])([0-9])\s*$';
    reg_code3 CONSTANT TEXT := '^\s*([0-9]{2})([0-9]{2})\s*-?\s*([0-9])([0-9])\s*-?\s*([0-9])([0-9])\s*$';
    reg_code9 CONSTANT TEXT := '^\s*([0-9]{2})([0-9]{2})\s*-?\s*([0-9])([0-9])\s*-?\s*([0-9])([0-9])((\s*-?\s*[1-4]\s*)+)$';
    match_result TEXT[];
    frac TEXT := '';
    arr INTEGER[];
    reslen INTEGER;
    latsecmin NUMERIC;
    lngsecmin NUMERIC;
    dlatsec NUMERIC;
    dlngsec NUMERIC;
    frac_len INTEGER;
    frac_n INTEGER;
    div INTEGER;
    frac_one INTEGER;
BEGIN
    IF code IS NULL THEN
        RETURN NULL;
    END IF;

    -- パターンマッチング
    SELECT regexp_matches(code, reg_code9) INTO match_result;
    IF match_result IS NULL THEN
        SELECT regexp_matches(code, reg_code3) INTO match_result;
    END IF;
    IF match_result IS NULL THEN
        SELECT regexp_matches(code, reg_code2) INTO match_result;
    END IF;
    IF match_result IS NULL THEN
        SELECT regexp_matches(code, reg_code1) INTO match_result;
    END IF;
    IF match_result IS NULL THEN
        RETURN NULL;
    END IF;
    -- RAISE NOTICE  'result: %', match_result;

    -- JavaScriptと返り値が違う
    -- match_result := match_result[2:array_length(match_result, 1)];
    -- 4桁目以降の処理
    reslen := array_length(match_result, 1);
    IF reslen >= 7 THEN
        frac := regexp_replace(match_result[7], '-', '', 'g');
        match_result := match_result[1:6];
        reslen := 6;
    END IF;
    -- 配列を整数に変換
    arr := ARRAY(SELECT unnest(match_result)::INTEGER);

    -- 1次の処理
    IF reslen >= 2 THEN
        latsecmin := arr[1] * 2400;
        lngsecmin := (arr[2] + 100) * 3600;
        dlatsec := 2400;
        dlngsec := 3600;
    END IF;
    -- 2次の処理
    IF reslen >= 4 THEN
        latsecmin := latsecmin + arr[3] * 300;
        lngsecmin := lngsecmin + arr[4] * 450;
        dlatsec := 300;
        dlngsec := 450;
    END IF;
    -- 3次の処理
    IF reslen >= 6 THEN
        latsecmin := latsecmin + arr[5] * 30;
        lngsecmin := lngsecmin + arr[6] * 45;
        dlatsec := 30;
        dlngsec := 45;
    END IF;
    -- 3次より細かい場合
    frac_len := length(frac);
    -- RAISE NOTICE 'frac % frac_len %', frac, frac_len;
    FOR frac_n IN 1..frac_len LOOP
        div := (1 << frac_n)::DOUBLE PRECISION;
        -- RAISE NOTICE 'div %', div;
        dlatsec := 30.0 / div;
        dlngsec := 45.0 / div;
        frac_one := substr(frac, frac_n, 1)::INTEGER;
        -- 2,4 -> east (1,3 -> west)
        IF mod(frac_one, 2) = 0 THEN
            lngsecmin := lngsecmin + dlngsec;
        END IF;
        -- 3,4 -> north (1,2 -> south)
        IF frac_one >= 3 THEN
            latsecmin := latsecmin + dlatsec;
        END IF;
    END LOOP;

    RETURN ARRAY[
        latsecmin / 3600,
        lngsecmin / 3600,
        (latsecmin + dlatsec) / 3600,
        (lngsecmin + dlngsec) / 3600
    ];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION jpgridcode2polygon(code TEXT, srid INTEGER DEFAULT 4326) RETURNS GEOMETRY(POLYGON) AS $$
DECLARE
    arr NUMERIC[];
BEGIN
    arr := jpgridcode2box(code);
    IF arr IS NULL THEN
        RETURN NULL;
    END IF;
    -- minx = arr[2]
    -- miny = arr[1]
    -- maxx = arr[4]
    -- maxy = arr[3]
    RETURN ST_SetSRID(
        ST_MakePolygon(
            ST_MakeLine(ARRAY[
                ST_MakePoint(arr[2],arr[1]),
                ST_MakePoint(arr[4],arr[1]),
                ST_MakePoint(arr[4],arr[3]),
                ST_MakePoint(arr[2],arr[3]),
                ST_MakePoint(arr[2],arr[1])
            ])
        ),
        4326
    );
END;
$$ LANGUAGE plpgsql;
