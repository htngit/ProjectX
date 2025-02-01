import React, { useState, useEffect } from 'react';
    import { createClient } from '@supabase/supabase-js';
    import { Auth } from '@supabase/auth-ui-react';
    import { ThemeSupa } from '@supabase/auth-ui-shared';
    import GetStartedPage from './components/GetStartedPage';

    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    function App() {
      const [session, setSession] = useState(null);

      useEffect(() => {
        supabase.auth.getSession().then(({ data: { session } }) => {
          setSession(session);
        });

        supabase.auth.onAuthStateChange((_event, session) => {
          setSession(session);
        });
      }, []);

      return (
        <div className="container mx-auto p-4">
          {!session ? (
            <Auth
              supabaseClient={supabase}
              appearance={{ theme: ThemeSupa }}
              providers={['google']}
            />
          ) : (
            <GetStartedPage supabase={supabase} session={session} />
          )}
        </div>
      );
    }

    export default App;
