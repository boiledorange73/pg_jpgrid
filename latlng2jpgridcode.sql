CREATE OR REPLACE FUNCTION latlng2jpgridcode(lat DOUBLE PRECISION, lng DOUBLE PRECISION, level INTEGER) RETURNS TEXT AS $$
DECLARE
    lats INTEGER;
    lngs INTEGER;
    ret TEXT;
    dlatsh DOUBLE PRECISION;
    dlngsh DOUBLE PRECISION;
    c INTEGER;
    n INTEGER;
BEGIN
    IF lat < 20 OR lat > 46 OR lng < 122 OR lng > 155 THEN
        RETURN NULL;
    END IF;
    -- 1st
    lats := 3600 * lat;
    lngs := 3600 * lng - 360000;
    ret := LPAD((lats / 2400)::TEXT, 2, '0') || LPAD((lngs / 3600)::TEXT, 2, '0');
    lats := lats % 2400;
    lngs := lngs % 3600;
    -- 2nd
    IF level >= 2 THEN
        ret := ret || '-' || LPAD((lats / 300)::TEXT, 1, '0') || LPAD((lngs / 450)::TEXT, 1, '0');
        lats := lats % 300;
        lngs := lngs % 450;
    END IF;
    -- 3rd
    IF level >= 3 THEN
        ret := ret || '-' || LPAD((lats / 30)::TEXT, 1, '0') || LPAD((lngs / 45)::TEXT, 1, '0');
        lats := lats % 30;
        lngs := lngs % 45;
    END IF;
    -- 4th and beyond
    dlatsh := 30;
    dlngsh := 45;
    FOR n IN 4..level LOOP
        dlatsh := 0.5 * dlatsh;
        dlngsh := 0.5 * dlngsh;
        c := 1;
        IF lats > dlatsh THEN
            c := 3;
            lats := lats - dlatsh;
        END IF;
        IF lngs > dlngsh THEN
            c := c + 1;
            lngs := lngs - dlngsh;
        END IF;
        ret := ret || '-' || c::TEXT;
    END LOOP;
    -- fin
    RETURN ret;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION point2jpgridcode(p GEOMETRY(POINT), level INTEGER) RETURNS TEXT AS $$
DECLARE
    lat DOUBLE PRECISION;
    lng DOUBLE PRECISION;
BEGIN
    IF p IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN latlng2jpgridcode(ST_Y(p), ST_X(p), level);
END;
$$ LANGUAGE plpgsql;
