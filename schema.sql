-- Table to store roles
    CREATE TABLE roles (
      id SERIAL PRIMARY KEY,
      name VARCHAR(50) UNIQUE NOT NULL,
      level INTEGER UNIQUE NOT NULL, -- Hierarchical level (1 = Super Admin, 5 = Staff)
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Insert predefined roles
    INSERT INTO roles (name, level) VALUES
      ('Super Admin', 1),
      ('Admin', 2),
      ('Head of Division', 3),
      ('Manager', 4),
      ('Staff', 5);

    -- Table to store companies
    CREATE TABLE companies (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      code VARCHAR(50) UNIQUE NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Table to store user profiles
    CREATE TABLE user_profiles (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
      company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
      role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
      supervisor_code VARCHAR(50),
      onboarded BOOLEAN DEFAULT FALSE,
      legal_agreement BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_id)
    );

    -- Table to store team data
    CREATE TABLE teams (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      company_id UUID REFERENCES companies(id) ON DELETE CASCADE NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Table to store team memberships
    CREATE TABLE team_members (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_profile_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
      team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(user_profile_id, team_id)
    );

    -- Table to store client data
    CREATE TABLE clients (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Function to check if a user has a specific role
    CREATE OR REPLACE FUNCTION has_role(user_id UUID, role_name VARCHAR)
    RETURNS BOOLEAN AS $$
    DECLARE
      role_level INTEGER;
      user_role_level INTEGER;
    BEGIN
      SELECT level INTO role_level FROM roles WHERE name = role_name;
      SELECT r.level INTO user_role_level
      FROM user_profiles up
      JOIN roles r ON up.role_id = r.id
      WHERE up.user_id = user_id;

      IF user_role_level IS NULL THEN
        RETURN FALSE;
      END IF;

      RETURN user_role_level <= role_level;
    END;
    $$ LANGUAGE plpgsql;

    -- Function to get user's role level
    CREATE OR REPLACE FUNCTION get_user_role_level(user_id UUID)
    RETURNS INTEGER AS $$
    DECLARE
      user_role_level INTEGER;
    BEGIN
      SELECT r.level INTO user_role_level
      FROM user_profiles up
      JOIN roles r ON up.role_id = r.id
      WHERE up.user_id = user_id;

      RETURN user_role_level;
    END;
    $$ LANGUAGE plpgsql;

    -- Function to get user's company ID
    CREATE OR REPLACE FUNCTION get_user_company_id(user_id UUID)
    RETURNS UUID AS $$
    DECLARE
      company_id UUID;
    BEGIN
      SELECT company_id INTO company_id
      FROM user_profiles
      WHERE user_id = user_id;

      RETURN company_id;
    END;
    $$ LANGUAGE plpgsql;

    -- Function to get user's team ID
    CREATE OR REPLACE FUNCTION get_user_team_id(user_id UUID)
    RETURNS UUID AS $$
    DECLARE
      team_id UUID;
    BEGIN
      SELECT tm.team_id INTO team_id
      FROM user_profiles up
      JOIN team_members tm ON up.id = tm.user_profile_id
      WHERE up.user_id = user_id;

      RETURN team_id;
    END;
    $$ LANGUAGE plpgsql;

    -- Trigger to set Super Admin role for new companies
    CREATE OR REPLACE FUNCTION set_super_admin_role()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.company_id IS NOT NULL AND NEW.role_id IS NULL THEN
        -- Get the Super Admin role ID
        SELECT id INTO NEW.role_id FROM roles WHERE name = 'Super Admin';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER set_super_admin_trigger
    BEFORE INSERT ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION set_super_admin_role();

    -- Trigger to prevent data modification above user's role level
    CREATE OR REPLACE FUNCTION check_rbac_on_update()
    RETURNS TRIGGER AS $$
    DECLARE
      user_role_level INTEGER;
      target_user_role_level INTEGER;
      target_user_id UUID;
    BEGIN
      -- Get the user's role level
      SELECT get_user_role_level(auth.uid()) INTO user_role_level;

      -- Get the target user's role level if updating user_profiles
      IF TG_TABLE_NAME = 'user_profiles' THEN
        target_user_id := NEW.user_id;
        SELECT get_user_role_level(target_user_id) INTO target_user_role_level;
        IF target_user_role_level IS NOT NULL AND user_role_level > target_user_role_level THEN
          RAISE EXCEPTION 'Cannot modify data above your role level.';
        END IF;
      END IF;

      -- Get the target team's company ID if updating teams
      IF TG_TABLE_NAME = 'teams' THEN
        IF NEW.company_id IS NOT NULL THEN
          IF get_user_company_id(auth.uid()) != NEW.company_id THEN
            RAISE EXCEPTION 'Cannot modify data outside your company.';
          END IF;
        END IF;
      END IF;

      -- Get the target client's team ID if updating clients
      IF TG_TABLE_NAME = 'clients' THEN
        IF NEW.team_id IS NOT NULL THEN
          IF get_user_team_id(auth.uid()) != NEW.team_id THEN
            RAISE EXCEPTION 'Cannot modify data outside your team.';
          END IF;
        END IF;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER check_rbac_on_update_trigger
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_update();

    CREATE TRIGGER check_rbac_on_update_teams_trigger
    BEFORE UPDATE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_update();

    CREATE TRIGGER check_rbac_on_update_clients_trigger
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_update();

    -- Trigger to prevent data deletion above user's role level
    CREATE OR REPLACE FUNCTION check_rbac_on_delete()
    RETURNS TRIGGER AS $$
    DECLARE
      user_role_level INTEGER;
      target_user_role_level INTEGER;
      target_user_id UUID;
    BEGIN
      -- Get the user's role level
      SELECT get_user_role_level(auth.uid()) INTO user_role_level;

      -- Get the target user's role level if deleting from user_profiles
      IF TG_TABLE_NAME = 'user_profiles' THEN
        target_user_id := OLD.user_id;
        SELECT get_user_role_level(target_user_id) INTO target_user_role_level;
        IF target_user_role_level IS NOT NULL AND user_role_level > target_user_role_level THEN
          RAISE EXCEPTION 'Cannot delete data above your role level.';
        END IF;
      END IF;

      -- Get the target team's company ID if deleting from teams
      IF TG_TABLE_NAME = 'teams' THEN
        IF OLD.company_id IS NOT NULL THEN
          IF get_user_company_id(auth.uid()) != OLD.company_id THEN
            RAISE EXCEPTION 'Cannot delete data outside your company.';
          END IF;
        END IF;
      END IF;

      -- Get the target client's team ID if deleting from clients
      IF TG_TABLE_NAME = 'clients' THEN
        IF OLD.team_id IS NOT NULL THEN
          IF get_user_team_id(auth.uid()) != OLD.team_id THEN
            RAISE EXCEPTION 'Cannot delete data outside your team.';
          END IF;
        END IF;
      END IF;

      RETURN OLD;
    END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER check_rbac_on_delete_trigger
    BEFORE DELETE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_delete();

    CREATE TRIGGER check_rbac_on_delete_teams_trigger
    BEFORE DELETE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_delete();

    CREATE TRIGGER check_rbac_on_delete_clients_trigger
    BEFORE DELETE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION check_rbac_on_delete();

    -- Enable RLS on tables
    ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
    ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

    -- Policies for user_profiles
    CREATE POLICY "Users can view their own profile" ON user_profiles
    FOR SELECT USING (user_id = auth.uid());

    CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (user_id = auth.uid());

    -- Policies for teams
    CREATE POLICY "Users can view teams in their company" ON teams
    FOR SELECT USING (company_id = get_user_company_id(auth.uid()));

    CREATE POLICY "Users can update teams in their company" ON teams
    FOR UPDATE USING (company_id = get_user_company_id(auth.uid()));

    -- Policies for clients
    CREATE POLICY "Users can view clients in their team" ON clients
    FOR SELECT USING (team_id = get_user_team_id(auth.uid()));

    CREATE POLICY "Users can update clients in their team" ON clients
    FOR UPDATE USING (team_id = get_user_team_id(auth.uid()));
