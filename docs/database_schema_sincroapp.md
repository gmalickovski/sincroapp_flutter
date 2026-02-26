--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: sincroapp; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sincroapp;


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: contact_status; Type: TYPE; Schema: sincroapp; Owner: -
--

CREATE TYPE sincroapp.contact_status AS ENUM (
    'active',
    'blocked',
    'pending'
);


--
-- Name: notification_type; Type: TYPE; Schema: sincroapp; Owner: -
--

CREATE TYPE sincroapp.notification_type AS ENUM (
    'system',
    'mention',
    'share',
    'sincro_alert',
    'reminder',
    'contact_request',
    'task_invite',
    'task_update',
    'contact_accepted',
    'strategy'
);


--
-- Name: permission_level; Type: TYPE; Schema: sincroapp; Owner: -
--

CREATE TYPE sincroapp.permission_level AS ENUM (
    'view',
    'edit',
    'owner'
);


--
-- Name: shared_item_type; Type: TYPE; Schema: sincroapp; Owner: -
--

CREATE TYPE sincroapp.shared_item_type AS ENUM (
    'goal',
    'task',
    'event',
    'milestone'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: calculate_personal_day(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.calculate_personal_day(user_birth_date timestamp without time zone, target_date timestamp without time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    u_day INT;
    u_month INT;
    t_year INT;
    t_month INT;
    t_day INT;
    
    aniversario_no_ano TIMESTAMP;
    ano_calculo INT;
    
    ano_pessoal INT;
    mes_pessoal INT;
    dia_pessoal_reduced INT;
    dia_pessoal INT;
BEGIN
    IF user_birth_date IS NULL THEN RETURN NULL; END IF;
    
    u_day := EXTRACT(DAY FROM user_birth_date)::INT;
    u_month := EXTRACT(MONTH FROM user_birth_date)::INT;
    
    t_year := EXTRACT(YEAR FROM target_date)::INT;
    t_month := EXTRACT(MONTH FROM target_date)::INT;
    t_day := EXTRACT(DAY FROM target_date)::INT;
    
    -- Lógica do aniversário: 
    -- Se a data alvo é antes do aniversário neste ano, usa ano anterior.
    -- Tratamento simples de erro para 29/02: Postgres lida bem com construct date, mas cuidado.
    BEGIN
        aniversario_no_ano := make_timestamp(t_year, u_month, u_day, 0, 0, 0);
    EXCEPTION WHEN OTHERS THEN
        -- Fallback para 28/02 se nasceu em 29/02 e estamos em ano não bissexto
        aniversario_no_ano := make_timestamp(t_year, 2, 28, 0, 0, 0);
    END;
    IF target_date < aniversario_no_ano THEN
        ano_calculo := t_year - 1;
    ELSE
        ano_calculo := t_year;
    END IF;
    
    -- Ano Pessoal (mestre=false)
    ano_pessoal := sincroapp.reduce_number(u_day + u_month + ano_calculo, FALSE);
    
    -- Mês Pessoal (mestre=false)
    mes_pessoal := sincroapp.reduce_number(ano_pessoal + t_month, FALSE);
    
    -- Dia do alvo reduzido (mestre=true)
    dia_pessoal_reduced := sincroapp.reduce_number(t_day, TRUE);
    
    -- Dia Pessoal Final (mestre=true)
    dia_pessoal := sincroapp.reduce_number(mes_pessoal + dia_pessoal_reduced, TRUE);
    
    RETURN dia_pessoal;
END;
$$;


--
-- Name: estimate_recurrence_count(timestamp without time zone, timestamp without time zone, text, integer[]); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.estimate_recurrence_count(start_date timestamp without time zone, end_date timestamp without time zone, rec_type text, days_of_week integer[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    d_diff INT;
BEGIN
    IF end_date <= start_date THEN RETURN 0; END IF;
    
    -- Usa diferença de dias inteiros (Date - Date) para evitar problemas de intervalo
    d_diff := (end_date::DATE - start_date::DATE);
    
    IF d_diff <= 0 THEN RETURN 0; END IF;
    IF rec_type = 'RecurrenceType.daily' THEN
        RETURN d_diff;
    ELSIF rec_type = 'RecurrenceType.weekly' THEN
        IF days_of_week IS NULL OR array_length(days_of_week, 1) IS NULL THEN
            RETURN floor(d_diff / 7);
        ELSE
            -- Ex: 100 dias / 7 = 14 semanas. * 3 dias/sem = 42 tarefas.
            RETURN floor(d_diff / 7) * array_length(days_of_week, 1);
        END IF;
    ELSIF rec_type = 'RecurrenceType.monthly' THEN
        RETURN floor(d_diff / 30);
    END IF;
    
    RETURN 0;
END;
$$;


--
-- Name: handle_goal_task_sync(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.handle_goal_task_sync() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_goal_deadline TIMESTAMP;
BEGIN
    IF NEW.goal_id IS NOT NULL THEN
        -- Sincroniza data se for recorrente
        SELECT target_date INTO v_goal_deadline FROM sincroapp.goals WHERE id = NEW.goal_id;
        
        IF v_goal_deadline IS NOT NULL AND NEW.recurrence_type != 'RecurrenceType.none' THEN
             NEW.recurrence_end_date := v_goal_deadline;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO sincroapp.users (uid, email, primeiro_nome, subscription)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name', -- Tenta pegar o nome dos metadados
    '{"plan": "free", "status": "active"}'::jsonb -- Plano padrão
  );
  RETURN new;
END;
$$;


--
-- Name: handle_task_recurrence(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.handle_task_recurrence() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    next_due_date TIMESTAMP WITH TIME ZONE;
    base_date TIMESTAMP WITH TIME ZONE;
    day_diff INT;
    next_week_day INT;
    found_next_day BOOLEAN := FALSE;
    sorted_days INT[];
    d INT;
    current_dow INT;
    
    -- Variáveis para Numerologia
    v_user_birth TIMESTAMP;
    v_personal_day INT;
BEGIN
    IF NEW.completed = TRUE AND OLD.completed = FALSE THEN
        
        IF NEW.recurrence_type IS NOT NULL AND NEW.recurrence_type != 'RecurrenceType.none' THEN
            
            -- Bloqueio 1: Se o usuário completar a tarefa MUITO depois do prazo (ex: meta acabou mês passado)
            -- Evita reviver mortos.
            IF NEW.recurrence_end_date IS NOT NULL AND NOW() > (NEW.recurrence_end_date + INTERVAL '1 day') THEN
                RETURN NEW;
            END IF;
            base_date := COALESCE(NEW.due_date, NOW());
            -- Lógica de cálculo da próxima data
            IF NEW.recurrence_type = 'RecurrenceType.daily' THEN
                next_due_date := base_date + INTERVAL '1 day';
            ELSIF NEW.recurrence_type = 'RecurrenceType.monthly' THEN
                next_due_date := base_date + INTERVAL '1 month';
            ELSIF NEW.recurrence_type = 'RecurrenceType.weekly' THEN
                IF NEW.recurrence_days_of_week IS NULL OR array_length(NEW.recurrence_days_of_week, 1) IS NULL THEN
                    next_due_date := base_date + INTERVAL '1 week';
                ELSE
                    current_dow := EXTRACT(ISODOW FROM base_date)::INT;
                    SELECT ARRAY(SELECT unnest(NEW.recurrence_days_of_week) ORDER BY 1) INTO sorted_days;
                    found_next_day := FALSE;
                    FOREACH d IN ARRAY sorted_days LOOP
                        IF d > current_dow THEN
                            day_diff := d - current_dow;
                            next_due_date := base_date + (day_diff || ' days')::INTERVAL;
                            found_next_day := TRUE;
                            EXIT; 
                        END IF;
                    END LOOP;
                    IF NOT found_next_day THEN
                        d := sorted_days[1];
                        day_diff := (7 - current_dow) + d;
                        next_due_date := base_date + (day_diff || ' days')::INTERVAL;
                    END IF;
                END IF;
            END IF;
            IF next_due_date IS NOT NULL THEN
                
                -- =====================================================
                -- CORREÇÃO PRINCIPAL (V5)
                -- Verifica se a data CALCULADA excede o limite.
                -- =====================================================
                IF NEW.recurrence_end_date IS NOT NULL THEN
                    -- Se a próxima data for ESTRITAMENTE MAIOR que o fim, PARE.
                    -- Ex: Fim 31/01. Próxima 01/02. 01/02 > 31/01 -> True. Pare.
                    -- Permite criar NA data final (<=).
                    IF next_due_date > NEW.recurrence_end_date THEN
                        RETURN NEW; -- Não cria nada, apenas encerra.
                    END IF;
                END IF;
                -- ===============================================
                -- CÁLCULO DO DIA PESSOAL
                -- ===============================================
                BEGIN
                    SELECT to_date(birth_date, 'DD/MM/YYYY')::TIMESTAMP 
                    INTO v_user_birth 
                    FROM sincroapp.users 
                    WHERE uid = NEW.user_id;
                EXCEPTION WHEN OTHERS THEN
                    v_user_birth := NULL;
                END;
                
                IF v_user_birth IS NOT NULL THEN
                    v_personal_day := sincroapp.calculate_personal_day(v_user_birth, next_due_date::TIMESTAMP);
                ELSE
                    v_personal_day := NULL;
                END IF;
                INSERT INTO sincroapp.tasks (
                    text, completed, created_at, due_date, tags, 
                    journey_id, journey_title, personal_day, 
                    recurrence_type, recurrence_days_of_week, recurrence_end_date, 
                    recurrence_id, goal_id, user_id, 
                    completed_at, reminder_at
                ) VALUES (
                    NEW.text,
                    FALSE,
                    NOW(),
                    next_due_date,
                    NEW.tags,
                    NEW.journey_id,
                    NEW.journey_title,
                    v_personal_day,
                    NEW.recurrence_type,
                    NEW.recurrence_days_of_week,
                    NEW.recurrence_end_date,
                    NEW.recurrence_id,
                    NEW.goal_id,
                    NEW.user_id,
                    NULL,
                    NULL
                );
            END IF;
            
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: propagate_goal_changes(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.propagate_goal_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se mudou a data final da meta, atualiza a recorrência das tarefas filhas
    IF NEW.target_date IS DISTINCT FROM OLD.target_date THEN
        UPDATE sincroapp.tasks
        SET recurrence_end_date = NEW.target_date
        WHERE goal_id = NEW.id AND recurrence_type != 'RecurrenceType.none';
        
        -- O Update acima em 'tasks' vai disparar o 'trg_goal_progress_recalc' lá nas tasks,
        -- que por sua vez vai recalcular o progresso. Ciclo perfeito.
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: prune_chat_history(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.prune_chat_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    max_messages INTEGER := 50; -- Strategy: Keep last 50 messages (Context + Scroll History)
    messages_count INTEGER;
BEGIN
    -- Check how many messages this user has
    SELECT COUNT(*) INTO messages_count 
    FROM sincroapp.assistant_messages 
    WHERE user_id = NEW.user_id;

    -- If count exceeds limit, delete oldest
    IF messages_count > max_messages THEN
        DELETE FROM sincroapp.assistant_messages
        WHERE id IN (
            SELECT id FROM sincroapp.assistant_messages
            WHERE user_id = NEW.user_id
            ORDER BY created_at ASC -- Oldest first
            LIMIT (messages_count - max_messages) -- Delete excess
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION prune_chat_history(); Type: COMMENT; Schema: sincroapp; Owner: -
--

COMMENT ON FUNCTION sincroapp.prune_chat_history() IS 'Automated strategy to keep only the last 50 messages per user, preventing database bloat.';


--
-- Name: reduce_number(integer, boolean); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.reduce_number(num integer, mestre boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    sum_digits INT;
    n_str TEXT;
    i INT;
BEGIN
    -- Se for nulo ou 0, retorna 0
    IF num IS NULL THEN RETURN 0; END IF;
    
    LOOP
        -- Se for dígito único, retorna
        IF num <= 9 THEN
            RETURN num;
        END IF;
        
        -- Se for Mestre (11 ou 22) e a flag estiver ativa, retorna
        IF mestre IS TRUE AND (num = 11 OR num = 22) THEN
            RETURN num;
        END IF;
        
        -- Soma os dígitos
        n_str := num::TEXT;
        sum_digits := 0;
        
        FOR i IN 1..length(n_str) LOOP
            sum_digits := sum_digits + SUBSTRING(n_str FROM i FOR 1)::INT;
        END LOOP;
        
        num := sum_digits;
    END LOOP;
END;
$$;


--
-- Name: respond_to_contact_request(uuid, uuid, boolean); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.respond_to_contact_request(p_responder_uid uuid, p_requester_uid uuid, p_accept boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF p_accept THEN
    -- Ativar contato para o respondente (quem aceita)
    INSERT INTO sincroapp.user_contacts (user_id, contact_user_id, status)
    VALUES (p_responder_uid, p_requester_uid, 'active')
    ON CONFLICT (user_id, contact_user_id) 
    DO UPDATE SET status = 'active';
    
    -- Ativar contato para o solicitante (quem enviou)
    INSERT INTO sincroapp.user_contacts (user_id, contact_user_id, status)
    VALUES (p_requester_uid, p_responder_uid, 'active')
    ON CONFLICT (user_id, contact_user_id) 
    DO UPDATE SET status = 'active';
  ELSE
    -- Recusar: remover ambos os registros
    DELETE FROM sincroapp.user_contacts 
    WHERE (user_id = p_responder_uid AND contact_user_id = p_requester_uid)
       OR (user_id = p_requester_uid AND contact_user_id = p_responder_uid);
  END IF;
END;
$$;


--
-- Name: update_goal_progress_logic(); Type: FUNCTION; Schema: sincroapp; Owner: -
--

CREATE FUNCTION sincroapp.update_goal_progress_logic() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    g_id uuid;
    v_deadline TIMESTAMP;
    v_total_tasks INT := 0;
    v_completed_tasks INT := 0;
    v_proj_count INT;
    t_row record;
BEGIN
    IF TG_OP = 'DELETE' THEN g_id := OLD.goal_id; ELSE g_id := NEW.goal_id; END IF;
    IF g_id IS NULL THEN RETURN NULL; END IF;
    SELECT target_date INTO v_deadline FROM sincroapp.goals WHERE id = g_id;
    
    -- Conta existentes
    SELECT COUNT(*), COUNT(*) FILTER (WHERE completed = true)
    INTO v_total_tasks, v_completed_tasks
    FROM sincroapp.tasks
    WHERE goal_id = g_id;
    
    -- Soma Projeção de Futuras
    IF v_deadline IS NOT NULL AND v_deadline > NOW() THEN
        FOR t_row IN SELECT * FROM sincroapp.tasks WHERE goal_id = g_id AND recurrence_type != 'RecurrenceType.none' LOOP
            -- Só projeta se a tarefa NÃO estiver concluída (tarefas vivas projetam o futuro)
            IF t_row.completed = FALSE THEN
                v_proj_count := sincroapp.estimate_recurrence_count(
                    COALESCE(t_row.due_date, t_row.created_at), 
                    v_deadline, 
                    t_row.recurrence_type, 
                    t_row.recurrence_days_of_week
                );
                v_total_tasks := v_total_tasks + v_proj_count;
            END IF;
        END LOOP;
    END IF;
    IF v_total_tasks = 0 THEN v_total_tasks := 1; END IF;
    
    UPDATE sincroapp.goals 
    SET progress = (v_completed_tasks::FLOAT / v_total_tasks::FLOAT * 100)::INT
    WHERE id = g_id;
    RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text NOT NULL,
    code_challenge_method auth.code_challenge_method NOT NULL,
    code_challenge text NOT NULL,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'stores metadata for pkce logins';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: app_versions; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.app_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version text NOT NULL,
    label text NOT NULL,
    description text,
    details text[],
    release_date timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: assistant_messages; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.assistant_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    content text,
    actions jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    conversation_id uuid
);


--
-- Name: goals; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.goals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    target_date timestamp with time zone,
    progress integer DEFAULT 0,
    category text,
    image_url text,
    sub_tasks jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: journal_entries; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.journal_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    content text,
    mood text,
    entry_date timestamp with time zone DEFAULT now(),
    tags text[],
    created_at timestamp with time zone DEFAULT now(),
    personal_day integer,
    updated_at timestamp with time zone DEFAULT now(),
    title text
);


--
-- Name: knowledge_base; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.knowledge_base (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding public.vector(1536),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: notifications; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.notifications (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    type sincroapp.notification_type NOT NULL,
    title character varying(100) NOT NULL,
    body text NOT NULL,
    related_item_id uuid,
    related_item_type character varying(50),
    is_read boolean DEFAULT false,
    read_at timestamp without time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: password_resets; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.password_resets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    token text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: shared_items; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.shared_items (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    item_type sincroapp.shared_item_type NOT NULL,
    item_id uuid NOT NULL,
    owner_id uuid NOT NULL,
    shared_with_user_id uuid NOT NULL,
    permission sincroapp.permission_level DEFAULT 'view'::sincroapp.permission_level,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: site_settings; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.site_settings (
    key text NOT NULL,
    value jsonb,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: tasks; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    text text NOT NULL,
    completed boolean DEFAULT false,
    due_date timestamp with time zone,
    completed_at timestamp with time zone,
    journey_id text,
    journey_title text,
    goal_id text,
    tags text[],
    recurrence_type text,
    recurrence_days_of_week integer[],
    personal_day integer,
    created_at timestamp with time zone DEFAULT now(),
    recurrence_end_date timestamp with time zone,
    recurrence_id text,
    reminder_hour integer,
    reminder_minute integer,
    reminder_at timestamp with time zone,
    shared_with text[] DEFAULT '{}'::text[],
    original_task_id uuid,
    shared_from_user_id uuid,
    reminder_sent boolean DEFAULT false,
    task_type text DEFAULT 'task'::text,
    duration_minutes integer,
    source_journal_id uuid
);


--
-- Name: COLUMN tasks.original_task_id; Type: COMMENT; Schema: sincroapp; Owner: -
--

COMMENT ON COLUMN sincroapp.tasks.original_task_id IS 'UUID da tarefa original quando esta é uma cópia aceita de compartilhamento';


--
-- Name: COLUMN tasks.shared_from_user_id; Type: COMMENT; Schema: sincroapp; Owner: -
--

COMMENT ON COLUMN sincroapp.tasks.shared_from_user_id IS 'UUID do usuário que compartilhou a tarefa original';


--
-- Name: usage_logs; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.usage_logs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    request_type text NOT NULL,
    tokens_input integer DEFAULT 0,
    tokens_output integer DEFAULT 0,
    tokens_total integer DEFAULT 0,
    model_name text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_contacts; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.user_contacts (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    contact_user_id uuid NOT NULL,
    status sincroapp.contact_status DEFAULT 'active'::sincroapp.contact_status,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT no_self_contact CHECK ((user_id <> contact_user_id))
);


--
-- Name: username_history; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.username_history (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    old_username character varying(30),
    new_username character varying(30),
    changed_at timestamp without time zone DEFAULT now(),
    changed_reason text
);


--
-- Name: users; Type: TABLE; Schema: sincroapp; Owner: -
--

CREATE TABLE sincroapp.users (
    uid uuid NOT NULL,
    email text,
    photo_url text,
    is_admin boolean DEFAULT false,
    dashboard_card_order jsonb,
    dashboard_hidden_cards jsonb,
    subscription jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    analysis_name text,
    birth_date text,
    subscription_data jsonb,
    first_name text,
    last_name text,
    stripe_id text,
    username character varying(30),
    gender text,
    CONSTRAINT username_format CHECK (((username IS NULL) OR ((username)::text ~ '^[a-z0-9_.]{3,30}$'::text)))
);


--
-- Name: COLUMN users.username; Type: COMMENT; Schema: sincroapp; Owner: -
--

COMMENT ON COLUMN sincroapp.users.username IS 'Username único do usuário, usado para compartilhamento. Formato: 3-30 caracteres, apenas [a-z0-9_.]';


--
-- Name: view_conversations; Type: VIEW; Schema: sincroapp; Owner: -
--

CREATE VIEW sincroapp.view_conversations AS
 SELECT DISTINCT ON (assistant_messages.conversation_id) assistant_messages.conversation_id AS id,
    assistant_messages.user_id,
    assistant_messages.content AS title,
    assistant_messages.created_at
   FROM sincroapp.assistant_messages
  WHERE (assistant_messages.conversation_id IS NOT NULL)
  ORDER BY assistant_messages.conversation_id, assistant_messages.created_at;


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: app_versions app_versions_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.app_versions
    ADD CONSTRAINT app_versions_pkey PRIMARY KEY (id);


--
-- Name: app_versions app_versions_version_key; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.app_versions
    ADD CONSTRAINT app_versions_version_key UNIQUE (version);


--
-- Name: assistant_messages assistant_messages_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.assistant_messages
    ADD CONSTRAINT assistant_messages_pkey PRIMARY KEY (id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: journal_entries journal_entries_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.journal_entries
    ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);


--
-- Name: knowledge_base knowledge_base_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.knowledge_base
    ADD CONSTRAINT knowledge_base_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: shared_items shared_items_item_type_item_id_shared_with_user_id_key; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.shared_items
    ADD CONSTRAINT shared_items_item_type_item_id_shared_with_user_id_key UNIQUE (item_type, item_id, shared_with_user_id);


--
-- Name: shared_items shared_items_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.shared_items
    ADD CONSTRAINT shared_items_pkey PRIMARY KEY (id);


--
-- Name: site_settings site_settings_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (key);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: usage_logs usage_logs_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.usage_logs
    ADD CONSTRAINT usage_logs_pkey PRIMARY KEY (id);


--
-- Name: user_contacts user_contacts_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.user_contacts
    ADD CONSTRAINT user_contacts_pkey PRIMARY KEY (id);


--
-- Name: user_contacts user_contacts_user_id_contact_user_id_key; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.user_contacts
    ADD CONSTRAINT user_contacts_user_id_contact_user_id_key UNIQUE (user_id, contact_user_id);


--
-- Name: username_history username_history_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.username_history
    ADD CONSTRAINT username_history_pkey PRIMARY KEY (id);


--
-- Name: users username_unique; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.users
    ADD CONSTRAINT username_unique UNIQUE (username);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (uid);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: assistant_messages_user_id_idx; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX assistant_messages_user_id_idx ON sincroapp.assistant_messages USING btree (user_id);


--
-- Name: idx_assistant_messages_conversation_id; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_assistant_messages_conversation_id ON sincroapp.assistant_messages USING btree (conversation_id);


--
-- Name: idx_knowledge_metadata; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_knowledge_metadata ON sincroapp.knowledge_base USING gin (metadata);


--
-- Name: idx_notifications_unread; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_notifications_unread ON sincroapp.notifications USING btree (user_id) WHERE (is_read = false);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_notifications_user ON sincroapp.notifications USING btree (user_id);


--
-- Name: idx_tasks_original_task; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_tasks_original_task ON sincroapp.tasks USING btree (original_task_id) WHERE (original_task_id IS NOT NULL);


--
-- Name: idx_tasks_shared_from; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_tasks_shared_from ON sincroapp.tasks USING btree (shared_from_user_id) WHERE (shared_from_user_id IS NOT NULL);


--
-- Name: idx_usage_logs_created_at; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_usage_logs_created_at ON sincroapp.usage_logs USING btree (created_at);


--
-- Name: idx_usage_logs_user_id; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_usage_logs_user_id ON sincroapp.usage_logs USING btree (user_id);


--
-- Name: idx_username_history_user; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_username_history_user ON sincroapp.username_history USING btree (user_id);


--
-- Name: idx_users_stripe_id; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_users_stripe_id ON sincroapp.users USING btree (stripe_id);


--
-- Name: idx_users_username; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX idx_users_username ON sincroapp.users USING btree (username);


--
-- Name: knowledge_base_embedding_idx; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX knowledge_base_embedding_idx ON sincroapp.knowledge_base USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='64');


--
-- Name: knowledge_base_embedding_idx1; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX knowledge_base_embedding_idx1 ON sincroapp.knowledge_base USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: knowledge_base_metadata_idx; Type: INDEX; Schema: sincroapp; Owner: -
--

CREATE INDEX knowledge_base_metadata_idx ON sincroapp.knowledge_base USING gin (metadata);


--
-- Name: users on_auth_user_created; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION sincroapp.handle_new_user();


--
-- Name: notifications n8n-notification-trigger; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER "n8n-notification-trigger" AFTER INSERT ON sincroapp.notifications FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://n8n.studiomlk.com.br/webhook/sincroapp-notification', 'POST', '{"Content-type":"application/json"}', '{}', '5000');


--
-- Name: tasks trg_goal_date_sync; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER trg_goal_date_sync BEFORE INSERT OR UPDATE ON sincroapp.tasks FOR EACH ROW EXECUTE FUNCTION sincroapp.handle_goal_task_sync();


--
-- Name: goals trg_goal_parameter_change; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER trg_goal_parameter_change AFTER UPDATE OF target_date ON sincroapp.goals FOR EACH ROW EXECUTE FUNCTION sincroapp.propagate_goal_changes();


--
-- Name: tasks trg_goal_progress_recalc; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER trg_goal_progress_recalc AFTER INSERT OR DELETE OR UPDATE OF completed, goal_id ON sincroapp.tasks FOR EACH ROW EXECUTE FUNCTION sincroapp.update_goal_progress_logic();


--
-- Name: tasks trigger_check_recurrence; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER trigger_check_recurrence AFTER UPDATE OF completed ON sincroapp.tasks FOR EACH ROW EXECUTE FUNCTION sincroapp.handle_task_recurrence();


--
-- Name: assistant_messages trigger_prune_chat_history; Type: TRIGGER; Schema: sincroapp; Owner: -
--

CREATE TRIGGER trigger_prune_chat_history AFTER INSERT ON sincroapp.assistant_messages FOR EACH ROW EXECUTE FUNCTION sincroapp.prune_chat_history();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: assistant_messages assistant_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.assistant_messages
    ADD CONSTRAINT assistant_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: goals goals_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.goals
    ADD CONSTRAINT goals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: journal_entries journal_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.journal_entries
    ADD CONSTRAINT journal_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: shared_items shared_items_owner_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.shared_items
    ADD CONSTRAINT shared_items_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: shared_items shared_items_shared_with_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.shared_items
    ADD CONSTRAINT shared_items_shared_with_user_id_fkey FOREIGN KEY (shared_with_user_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: tasks tasks_shared_from_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.tasks
    ADD CONSTRAINT tasks_shared_from_user_id_fkey FOREIGN KEY (shared_from_user_id) REFERENCES sincroapp.users(uid);


--
-- Name: tasks tasks_source_journal_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.tasks
    ADD CONSTRAINT tasks_source_journal_id_fkey FOREIGN KEY (source_journal_id) REFERENCES sincroapp.journal_entries(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.tasks
    ADD CONSTRAINT tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usage_logs usage_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.usage_logs
    ADD CONSTRAINT usage_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_contacts user_contacts_contact_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.user_contacts
    ADD CONSTRAINT user_contacts_contact_user_id_fkey FOREIGN KEY (contact_user_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: user_contacts user_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.user_contacts
    ADD CONSTRAINT user_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: username_history username_history_user_id_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.username_history
    ADD CONSTRAINT username_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES sincroapp.users(uid) ON DELETE CASCADE;


--
-- Name: users users_uid_fkey; Type: FK CONSTRAINT; Schema: sincroapp; Owner: -
--

ALTER TABLE ONLY sincroapp.users
    ADD CONSTRAINT users_uid_fkey FOREIGN KEY (uid) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users Admins can update users; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Admins can update users" ON sincroapp.users FOR UPDATE TO authenticated USING ((( SELECT users_1.is_admin
   FROM sincroapp.users users_1
  WHERE (users_1.uid = auth.uid())) = true)) WITH CHECK ((( SELECT users_1.is_admin
   FROM sincroapp.users users_1
  WHERE (users_1.uid = auth.uid())) = true));


--
-- Name: usage_logs Admins can view all usage logs; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Admins can view all usage logs" ON sincroapp.usage_logs FOR SELECT USING ((EXISTS ( SELECT 1
   FROM sincroapp.users
  WHERE ((users.uid = auth.uid()) AND (users.is_admin = true)))));


--
-- Name: app_versions Allow read access for all users; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Allow read access for all users" ON sincroapp.app_versions FOR SELECT TO authenticated, anon USING (true);


--
-- Name: site_settings Authenticated insert access to site_settings; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Authenticated insert access to site_settings" ON sincroapp.site_settings FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: site_settings Authenticated update access to site_settings; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Authenticated update access to site_settings" ON sincroapp.site_settings FOR UPDATE USING ((auth.role() = 'authenticated'::text));


--
-- Name: usage_logs Enable insert for authenticated users only; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Enable insert for authenticated users only" ON sincroapp.usage_logs FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: usage_logs Enable read for users based on user_id; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Enable read for users based on user_id" ON sincroapp.usage_logs FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: app_versions Everyone can read app versions; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Everyone can read app versions" ON sincroapp.app_versions FOR SELECT USING (true);


--
-- Name: site_settings Public read access to site_settings; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Public read access to site_settings" ON sincroapp.site_settings FOR SELECT USING (true);


--
-- Name: password_resets Service Role Full Access; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Service Role Full Access" ON sincroapp.password_resets TO service_role USING (true) WITH CHECK (true);


--
-- Name: password_resets Service Role full access; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Service Role full access" ON sincroapp.password_resets TO service_role USING (true) WITH CHECK (true);


--
-- Name: app_versions Service role can manage app versions; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Service role can manage app versions" ON sincroapp.app_versions USING ((auth.uid() IS NULL));


--
-- Name: assistant_messages Users can CRUD their own chat history; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can CRUD their own chat history" ON sincroapp.assistant_messages USING ((auth.uid() = user_id));


--
-- Name: goals Users can CRUD their own goals; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can CRUD their own goals" ON sincroapp.goals USING ((auth.uid() = user_id));


--
-- Name: journal_entries Users can CRUD their own journal entries; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can CRUD their own journal entries" ON sincroapp.journal_entries USING ((auth.uid() = user_id));


--
-- Name: tasks Users can CRUD their own tasks; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can CRUD their own tasks" ON sincroapp.tasks USING ((auth.uid() = user_id));


--
-- Name: usage_logs Users can insert own usage logs; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can insert own usage logs" ON sincroapp.usage_logs FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: users Users can insert their own profile; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can insert their own profile" ON sincroapp.users FOR INSERT WITH CHECK ((auth.uid() = uid));


--
-- Name: users Users can update their own profile; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can update their own profile" ON sincroapp.users FOR UPDATE USING ((auth.uid() = uid));


--
-- Name: usage_logs Users can view own usage logs; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can view own usage logs" ON sincroapp.usage_logs FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: users Users can view their own profile; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Users can view their own profile" ON sincroapp.users FOR SELECT USING ((auth.uid() = uid));


--
-- Name: assistant_messages Usuários podem deletar suas próprias mensagens; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Usuários podem deletar suas próprias mensagens" ON sincroapp.assistant_messages FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: assistant_messages Usuários podem inserir suas próprias mensagens; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Usuários podem inserir suas próprias mensagens" ON sincroapp.assistant_messages FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: assistant_messages Usuários podem ver suas próprias mensagens; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY "Usuários podem ver suas próprias mensagens" ON sincroapp.assistant_messages FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: app_versions; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.app_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: assistant_messages; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.assistant_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: goals; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.goals ENABLE ROW LEVEL SECURITY;

--
-- Name: journal_entries; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.journal_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_delete_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY notifications_delete_policy ON sincroapp.notifications FOR DELETE USING ((user_id = auth.uid()));


--
-- Name: notifications notifications_insert_generic; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY notifications_insert_generic ON sincroapp.notifications FOR INSERT WITH CHECK (true);


--
-- Name: notifications notifications_insert_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY notifications_insert_policy ON sincroapp.notifications FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: notifications notifications_select_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY notifications_select_policy ON sincroapp.notifications FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: notifications notifications_update_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY notifications_update_policy ON sincroapp.notifications FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: password_resets; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.password_resets ENABLE ROW LEVEL SECURITY;

--
-- Name: shared_items; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.shared_items ENABLE ROW LEVEL SECURITY;

--
-- Name: shared_items shared_items_delete_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY shared_items_delete_policy ON sincroapp.shared_items FOR DELETE USING ((owner_id = auth.uid()));


--
-- Name: shared_items shared_items_insert_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY shared_items_insert_policy ON sincroapp.shared_items FOR INSERT WITH CHECK ((owner_id = auth.uid()));


--
-- Name: shared_items shared_items_select_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY shared_items_select_policy ON sincroapp.shared_items FOR SELECT USING (((owner_id = auth.uid()) OR (shared_with_user_id = auth.uid())));


--
-- Name: shared_items shared_items_update_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY shared_items_update_policy ON sincroapp.shared_items FOR UPDATE USING ((owner_id = auth.uid()));


--
-- Name: site_settings; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.site_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: usage_logs; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.usage_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: user_contacts; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.user_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: user_contacts user_contacts_delete_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY user_contacts_delete_policy ON sincroapp.user_contacts FOR DELETE USING ((user_id = auth.uid()));


--
-- Name: user_contacts user_contacts_insert_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY user_contacts_insert_policy ON sincroapp.user_contacts FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: user_contacts user_contacts_modify_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY user_contacts_modify_policy ON sincroapp.user_contacts USING ((user_id = auth.uid()));


--
-- Name: user_contacts user_contacts_select_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY user_contacts_select_policy ON sincroapp.user_contacts FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: user_contacts user_contacts_update_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY user_contacts_update_policy ON sincroapp.user_contacts FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: users; Type: ROW SECURITY; Schema: sincroapp; Owner: -
--

ALTER TABLE sincroapp.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_read_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY users_read_policy ON sincroapp.users FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: users users_update_policy; Type: POLICY; Schema: sincroapp; Owner: -
--

CREATE POLICY users_update_policy ON sincroapp.users FOR UPDATE USING ((uid = auth.uid()));


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA auth TO anon;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT USAGE ON SCHEMA auth TO service_role;
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON SCHEMA auth TO dashboard_user;
GRANT USAGE ON SCHEMA auth TO postgres;


--
-- Name: SCHEMA sincroapp; Type: ACL; Schema: -; Owner: -
--

GRANT ALL ON SCHEMA sincroapp TO postgres;
GRANT USAGE ON SCHEMA sincroapp TO anon;
GRANT USAGE ON SCHEMA sincroapp TO authenticated;
GRANT USAGE ON SCHEMA sincroapp TO service_role;


--
-- Name: FUNCTION email(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.email() TO dashboard_user;


--
-- Name: FUNCTION jwt(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.jwt() TO postgres;
GRANT ALL ON FUNCTION auth.jwt() TO dashboard_user;


--
-- Name: FUNCTION role(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.role() TO dashboard_user;


--
-- Name: FUNCTION uid(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.uid() TO dashboard_user;


--
-- Name: FUNCTION respond_to_contact_request(p_responder_uid uuid, p_requester_uid uuid, p_accept boolean); Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON FUNCTION sincroapp.respond_to_contact_request(p_responder_uid uuid, p_requester_uid uuid, p_accept boolean) TO authenticated;


--
-- Name: TABLE audit_log_entries; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.audit_log_entries TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.audit_log_entries TO postgres;
GRANT SELECT ON TABLE auth.audit_log_entries TO postgres WITH GRANT OPTION;


--
-- Name: TABLE flow_state; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.flow_state TO postgres;
GRANT SELECT ON TABLE auth.flow_state TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.flow_state TO dashboard_user;


--
-- Name: TABLE identities; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.identities TO postgres;
GRANT SELECT ON TABLE auth.identities TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.identities TO dashboard_user;


--
-- Name: TABLE instances; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.instances TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.instances TO postgres;
GRANT SELECT ON TABLE auth.instances TO postgres WITH GRANT OPTION;


--
-- Name: TABLE mfa_amr_claims; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.mfa_amr_claims TO postgres;
GRANT SELECT ON TABLE auth.mfa_amr_claims TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_amr_claims TO dashboard_user;


--
-- Name: TABLE mfa_challenges; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.mfa_challenges TO postgres;
GRANT SELECT ON TABLE auth.mfa_challenges TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_challenges TO dashboard_user;


--
-- Name: TABLE mfa_factors; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.mfa_factors TO postgres;
GRANT SELECT ON TABLE auth.mfa_factors TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_factors TO dashboard_user;


--
-- Name: TABLE oauth_authorizations; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_authorizations TO postgres;
GRANT ALL ON TABLE auth.oauth_authorizations TO dashboard_user;


--
-- Name: TABLE oauth_client_states; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_client_states TO postgres;
GRANT ALL ON TABLE auth.oauth_client_states TO dashboard_user;


--
-- Name: TABLE oauth_clients; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_clients TO postgres;
GRANT ALL ON TABLE auth.oauth_clients TO dashboard_user;


--
-- Name: TABLE oauth_consents; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_consents TO postgres;
GRANT ALL ON TABLE auth.oauth_consents TO dashboard_user;


--
-- Name: TABLE one_time_tokens; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.one_time_tokens TO postgres;
GRANT SELECT ON TABLE auth.one_time_tokens TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.one_time_tokens TO dashboard_user;


--
-- Name: TABLE refresh_tokens; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.refresh_tokens TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.refresh_tokens TO postgres;
GRANT SELECT ON TABLE auth.refresh_tokens TO postgres WITH GRANT OPTION;


--
-- Name: SEQUENCE refresh_tokens_id_seq; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO dashboard_user;
GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO postgres;


--
-- Name: TABLE saml_providers; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.saml_providers TO postgres;
GRANT SELECT ON TABLE auth.saml_providers TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.saml_providers TO dashboard_user;


--
-- Name: TABLE saml_relay_states; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.saml_relay_states TO postgres;
GRANT SELECT ON TABLE auth.saml_relay_states TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.saml_relay_states TO dashboard_user;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: auth; Owner: -
--

GRANT SELECT ON TABLE auth.schema_migrations TO postgres WITH GRANT OPTION;


--
-- Name: TABLE sessions; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.sessions TO postgres;
GRANT SELECT ON TABLE auth.sessions TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sessions TO dashboard_user;


--
-- Name: TABLE sso_domains; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.sso_domains TO postgres;
GRANT SELECT ON TABLE auth.sso_domains TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sso_domains TO dashboard_user;


--
-- Name: TABLE sso_providers; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.sso_providers TO postgres;
GRANT SELECT ON TABLE auth.sso_providers TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sso_providers TO dashboard_user;


--
-- Name: TABLE users; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.users TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE auth.users TO postgres;
GRANT SELECT ON TABLE auth.users TO postgres WITH GRANT OPTION;


--
-- Name: TABLE app_versions; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.app_versions TO service_role;
GRANT ALL ON TABLE sincroapp.app_versions TO postgres;
GRANT SELECT ON TABLE sincroapp.app_versions TO anon;
GRANT SELECT ON TABLE sincroapp.app_versions TO authenticated;


--
-- Name: TABLE assistant_messages; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.assistant_messages TO postgres;
GRANT ALL ON TABLE sincroapp.assistant_messages TO anon;
GRANT ALL ON TABLE sincroapp.assistant_messages TO authenticated;
GRANT ALL ON TABLE sincroapp.assistant_messages TO service_role;


--
-- Name: TABLE goals; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.goals TO postgres;
GRANT ALL ON TABLE sincroapp.goals TO anon;
GRANT ALL ON TABLE sincroapp.goals TO authenticated;
GRANT ALL ON TABLE sincroapp.goals TO service_role;


--
-- Name: TABLE journal_entries; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.journal_entries TO postgres;
GRANT ALL ON TABLE sincroapp.journal_entries TO anon;
GRANT ALL ON TABLE sincroapp.journal_entries TO authenticated;
GRANT ALL ON TABLE sincroapp.journal_entries TO service_role;


--
-- Name: TABLE knowledge_base; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.knowledge_base TO service_role;
GRANT ALL ON TABLE sincroapp.knowledge_base TO postgres;


--
-- Name: TABLE notifications; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.notifications TO postgres;
GRANT ALL ON TABLE sincroapp.notifications TO anon;
GRANT ALL ON TABLE sincroapp.notifications TO authenticated;
GRANT ALL ON TABLE sincroapp.notifications TO service_role;


--
-- Name: TABLE password_resets; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.password_resets TO service_role;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sincroapp.password_resets TO authenticated;
GRANT ALL ON TABLE sincroapp.password_resets TO postgres;


--
-- Name: TABLE shared_items; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.shared_items TO service_role;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sincroapp.shared_items TO authenticated;
GRANT ALL ON TABLE sincroapp.shared_items TO postgres;


--
-- Name: TABLE site_settings; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.site_settings TO postgres;
GRANT ALL ON TABLE sincroapp.site_settings TO anon;
GRANT ALL ON TABLE sincroapp.site_settings TO authenticated;
GRANT ALL ON TABLE sincroapp.site_settings TO service_role;


--
-- Name: TABLE tasks; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.tasks TO postgres;
GRANT ALL ON TABLE sincroapp.tasks TO anon;
GRANT ALL ON TABLE sincroapp.tasks TO authenticated;
GRANT ALL ON TABLE sincroapp.tasks TO service_role;


--
-- Name: TABLE usage_logs; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.usage_logs TO service_role;
GRANT ALL ON TABLE sincroapp.usage_logs TO authenticated;
GRANT ALL ON TABLE sincroapp.usage_logs TO postgres;


--
-- Name: TABLE user_contacts; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.user_contacts TO postgres;
GRANT ALL ON TABLE sincroapp.user_contacts TO anon;
GRANT ALL ON TABLE sincroapp.user_contacts TO authenticated;
GRANT ALL ON TABLE sincroapp.user_contacts TO service_role;


--
-- Name: TABLE username_history; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.username_history TO service_role;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sincroapp.username_history TO authenticated;
GRANT ALL ON TABLE sincroapp.username_history TO postgres;


--
-- Name: TABLE users; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.users TO postgres;
GRANT ALL ON TABLE sincroapp.users TO anon;
GRANT ALL ON TABLE sincroapp.users TO authenticated;
GRANT ALL ON TABLE sincroapp.users TO service_role;


--
-- Name: TABLE view_conversations; Type: ACL; Schema: sincroapp; Owner: -
--

GRANT ALL ON TABLE sincroapp.view_conversations TO service_role;
GRANT SELECT ON TABLE sincroapp.view_conversations TO authenticated;
GRANT ALL ON TABLE sincroapp.view_conversations TO postgres;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON SEQUENCES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON SEQUENCES  TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON FUNCTIONS  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON FUNCTIONS  TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON TABLES  TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: sincroapp; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA sincroapp GRANT SELECT,USAGE ON SEQUENCES  TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: sincroapp; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA sincroapp GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA sincroapp GRANT ALL ON TABLES  TO service_role;


--
-- PostgreSQL database dump complete
--